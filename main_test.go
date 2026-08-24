package main

import (
	"encoding/json"
	"io"
	"io/fs"
	"log"
	"net/http"
	"net/http/httptest"
	"net/url"
	"os"
	"strings"
	"testing"

	"github.com/google/go-cmp/cmp"
)

func TestTokensFromEnv(t *testing.T) {
	tests := []struct {
		name string
		env  []string
		want map[string]string
	}{
		{
			name: "empty environment",
			env:  nil,
			want: map[string]string{},
		},
		{
			name: "ignores unrelated variables",
			env:  []string{"PATH=/bin", "HOME=/home/x", "HUGIN_HOSTNAME=hugin"},
			want: map[string]string{},
		},
		{
			name: "lowercases the name",
			env:  []string{"HUGIN_TOKEN_MAPBOX=pk.abc"},
			want: map[string]string{"mapbox": "pk.abc"},
		},
		{
			// The frontend reads body.mapbox, so this exact key is a contract
			// with src/map.ts.
			name: "collects several tokens",
			env:  []string{"HUGIN_TOKEN_MAPBOX=pk.abc", "HUGIN_TOKEN_OTHER=xyz"},
			want: map[string]string{"mapbox": "pk.abc", "other": "xyz"},
		},
		{
			// Regression: Split(rest, "=") + parts[1] truncated the value at
			// the first separator, mangling any base64-padded token.
			name: "keeps separators inside the value",
			env:  []string{"HUGIN_TOKEN_PADDED=YWJjZA==", "HUGIN_TOKEN_PAIR=a=b=c"},
			want: map[string]string{"padded": "YWJjZA==", "pair": "a=b=c"},
		},
		{
			name: "keeps empty values",
			env:  []string{"HUGIN_TOKEN_BLANK="},
			want: map[string]string{"blank": ""},
		},
		{
			name: "skips entries with no separator",
			env:  []string{"HUGIN_TOKEN_BROKEN"},
			want: map[string]string{},
		},
		{
			name: "skips a bare prefix with no name",
			env:  []string{"HUGIN_TOKEN_=value"},
			want: map[string]string{},
		},
		{
			name: "last occurrence wins",
			env:  []string{"HUGIN_TOKEN_MAPBOX=first", "HUGIN_TOKEN_MAPBOX=second"},
			want: map[string]string{"mapbox": "second"},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := tokensFromEnv(tt.env)
			if diff := cmp.Diff(tt.want, got); diff != "" {
				t.Errorf("tokensFromEnv() mismatch (-want +got):\n%s", diff)
			}
		})
	}
}

func TestTokenHandlerServesJSONObject(t *testing.T) {
	t.Setenv("HUGIN_TOKEN_MAPBOX", "pk.test")

	rec := httptest.NewRecorder()
	tokenHandler().ServeHTTP(rec, httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/tokens", nil))

	if rec.Code != http.StatusOK {
		t.Fatalf("status = %d, want %d", rec.Code, http.StatusOK)
	}

	var got map[string]string

	err := json.Unmarshal(rec.Body.Bytes(), &got)
	if err != nil {
		t.Fatalf("decoding response %q: %s", rec.Body.String(), err)
	}

	if got["mapbox"] != "pk.test" {
		t.Errorf("tokens[mapbox] = %q, want %q", got["mapbox"], "pk.test")
	}
}

// distHandler serves whatever the //go:embed dist/* directive captured. The
// test walks that filesystem rather than naming files, so it is meaningful
// both against a full Parcel build and against the bare placeholder the
// golangci-lint hook creates.
func TestDistHandlerServesEveryEmbeddedFile(t *testing.T) {
	sub, err := fs.Sub(distFS, "dist")
	if err != nil {
		t.Fatalf("fs.Sub(distFS, \"dist\"): %s", err)
	}

	handler := distHandler()
	served := 0

	err = fs.WalkDir(sub, ".", func(path string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return err
		}

		request := &url.URL{Path: "/" + path}

		rec := httptest.NewRecorder()
		handler.ServeHTTP(rec, httptest.NewRequestWithContext(t.Context(), http.MethodGet, request.String(), nil))

		// http.FileServer canonicalises ".../index.html" to ".../", so a
		// redirect there is correct behaviour rather than a miss. Location is
		// relative ("./"), so resolve it against the request before retrying.
		if rec.Code == http.StatusMovedPermanently {
			location, parseErr := url.Parse(rec.Header().Get("Location"))
			if parseErr != nil {
				t.Errorf("GET /%s: unparseable redirect %q: %s", path, rec.Header().Get("Location"), parseErr)

				return nil
			}

			target := request.ResolveReference(location)

			rec = httptest.NewRecorder()
			handler.ServeHTTP(rec, httptest.NewRequestWithContext(t.Context(), http.MethodGet, target.String(), nil))

			if rec.Code != http.StatusOK {
				t.Errorf("GET /%s redirected to %s = %d, want %d", path, target, rec.Code, http.StatusOK)
			}

			served++

			return nil
		}

		if rec.Code != http.StatusOK {
			t.Errorf("GET /%s = %d, want %d", path, rec.Code, http.StatusOK)
		}

		served++

		return nil
	})
	if err != nil {
		t.Fatalf("walking embedded dist: %s", err)
	}

	if served == 0 {
		t.Fatal("no files embedded from dist/; the embed directive matched nothing")
	}
}

func TestDistHandlerMissingFileIsNotFound(t *testing.T) {
	rec := httptest.NewRecorder()
	distHandler().ServeHTTP(rec, httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/no-such-asset.png", nil))

	if rec.Code != http.StatusNotFound {
		t.Errorf("status = %d, want %d", rec.Code, http.StatusNotFound)
	}
}

func TestLoggingHandlerDelegatesUnchanged(t *testing.T) {
	var gotPath string

	inner := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		gotPath = r.URL.Path

		w.WriteHeader(http.StatusTeapot)
	})

	rec := httptest.NewRecorder()
	loggingHandler(inner, "/srv/content").
		ServeHTTP(rec, httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/root/index.json", nil))

	if gotPath != "/root/index.json" {
		t.Errorf("inner handler saw path %q, want %q", gotPath, "/root/index.json")
	}

	if rec.Code != http.StatusTeapot {
		t.Errorf("status = %d, want %d passed through", rec.Code, http.StatusTeapot)
	}
}

// The status is the only thing separating a dangling original symlink (404)
// from an unreadable one (403); FileServer discards the error.
func TestLoggingHandlerLogsTheStatus(t *testing.T) {
	tests := []struct {
		name    string
		handler http.Handler
		want    string
	}{
		{
			name: "explicit status",
			handler: http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
				http.Error(w, "403 Forbidden", http.StatusForbidden)
			}),
			want: "GET 403 -",
		},
		{
			name: "body without WriteHeader is a 200",
			handler: http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
				_, _ = w.Write([]byte("{}"))
			}),
			want: "GET 200 -",
		},
		{
			name: "handler that writes nothing at all is a 200",
			handler: http.HandlerFunc(func(_ http.ResponseWriter, _ *http.Request) {
			}),
			want: "GET 200 -",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			var logged strings.Builder

			log.SetOutput(&logged)
			log.SetFlags(0)

			t.Cleanup(func() {
				log.SetOutput(os.Stderr)
				log.SetFlags(log.LstdFlags)
			})

			loggingHandler(tt.handler, "/srv/content").ServeHTTP(
				httptest.NewRecorder(),
				httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/root/x_original.jpeg", nil),
			)

			if !strings.Contains(logged.String(), tt.want) {
				t.Errorf("log line %q does not contain %q", logged.String(), tt.want)
			}

			// The resolved path is what makes a denial actionable.
			if !strings.Contains(logged.String(), "/srv/content/root/x_original.jpeg") {
				t.Errorf("log line %q lost the resolved path", logged.String())
			}
		})
	}
}

// Recording the status must not hide io.ReaderFrom, or every full-size
// original silently starts round-tripping through userspace.
func TestLoggingHandlerPreservesReaderFrom(t *testing.T) {
	var wrapped io.ReaderFrom

	inner := http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		rf, ok := w.(io.ReaderFrom)
		if !ok {
			t.Error("handler received a writer that is not an io.ReaderFrom")

			return
		}

		wrapped = rf
	})

	loggingHandler(inner, "/srv/content").ServeHTTP(
		readerFromRecorder{httptest.NewRecorder()},
		httptest.NewRequestWithContext(t.Context(), http.MethodGet, "/root/index.json", nil),
	)

	if wrapped == nil {
		t.Fatal("no io.ReaderFrom reached the inner handler")
	}

	n, err := wrapped.ReadFrom(strings.NewReader("hello"))
	if err != nil {
		t.Fatalf("ReadFrom: %s", err)
	}

	if n != 5 {
		t.Errorf("ReadFrom wrote %d bytes, want 5", n)
	}
}

// ResponseRecorder is not an io.ReaderFrom.
type readerFromRecorder struct {
	*httptest.ResponseRecorder
}

func (r readerFromRecorder) ReadFrom(src io.Reader) (int64, error) {
	return io.Copy(r.Body, src)
}

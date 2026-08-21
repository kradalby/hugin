package main

import (
	"encoding/json"
	"io/fs"
	"net/http"
	"net/http/httptest"
	"os"
	"path"
	"strings"
	"testing"
)

// The contract with Munin in one property: every URL Munin publishes has to
// resolve when hugin serves the gallery.
//
// Neither repo's unit tests can catch a break here. Munin asserts its URLs are
// relative and self-consistent; hugin asserts it decodes them. Both suites were
// green while every thumbnail 404'd in production, because the URLs were
// resolved against the wrong base. That is a property of the pair, so it needs
// a test that owns both halves.
//
// testdata/gallery is real Munin output, not hand-written: `munin` run over the
// two-photo album beside it. Regenerate both together — see testdata/README.md.

const galleryRoot = "testdata/gallery/content"

// publishedURLs pulls every URL-bearing value out of a decoded gallery JSON
// document. Recursive rather than typed, so a field Munin adds later is caught
// without teaching this test the schema.
func publishedURLs(node any, out *[]string) {
	switch value := node.(type) {
	case map[string]any:
		for key, child := range value {
			switch key {
			case "url", "originalImageURL", "previous", "next":
				if s, ok := child.(string); ok {
					*out = append(*out, s)

					continue
				}
			}

			publishedURLs(child, out)
		}
	case []any:
		for _, child := range value {
			publishedURLs(child, out)
		}
	}
}

// get keeps the call sites readable while carrying the test's context, which
// the linter requires over the http.Get convenience wrapper.
func get(t *testing.T, url string) *http.Response {
	t.Helper()

	req, err := http.NewRequestWithContext(t.Context(), http.MethodGet, url, nil)
	if err != nil {
		t.Fatalf("building request for %s: %s", url, err)
	}

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		t.Fatalf("GET %s: %s", url, err)
	}

	return resp
}

func galleryURLs(t *testing.T) []string {
	t.Helper()

	seen := map[string]bool{}
	urls := []string{}

	root, err := os.OpenRoot(galleryRoot)
	if err != nil {
		t.Fatalf("opening %s: %s", galleryRoot, err)
	}
	defer root.Close()

	err = fs.WalkDir(root.FS(), ".", func(p string, d fs.DirEntry, err error) error {
		if err != nil || d.IsDir() || !strings.HasSuffix(p, ".json") {
			return err
		}

		raw, err := fs.ReadFile(root.FS(), p)
		if err != nil {
			return err
		}

		var document any

		err = json.Unmarshal(raw, &document)
		if err != nil {
			return err
		}

		found := []string{}
		publishedURLs(document, &found)

		for _, u := range found {
			if !seen[u] {
				seen[u] = true
				urls = append(urls, u)
			}
		}

		return nil
	})
	if err != nil {
		t.Fatalf("walking %s: %s", galleryRoot, err)
	}

	if len(urls) == 0 {
		t.Fatalf("no published URLs found under %s; the fixture is empty or not Munin output", galleryRoot)
	}

	return urls
}

// The frontend prefixes /content (Data.Url.contentBase) and nothing else, so a
// published URL that is absolute or carries its own prefix cannot resolve no
// matter what the server does.
func TestPublishedURLsAreGalleryRelative(t *testing.T) {
	for _, u := range galleryURLs(t) {
		if strings.HasPrefix(u, "/") {
			t.Errorf("published URL is absolute, so /content would not be applied: %q", u)
		}

		if strings.HasPrefix(u, "content/") {
			t.Errorf("published URL carries its own content/ prefix, which would double up: %q", u)
		}
	}
}

// The regression that shipped: URLs that resolved against the current SPA route
// rather than the content mount, so every thumbnail 404'd.
func TestEveryPublishedURLResolvesThroughTheContentMount(t *testing.T) {
	server := httptest.NewServer(routes(galleryRoot, ""))
	defer server.Close()

	for _, u := range galleryURLs(t) {
		t.Run(u, func(t *testing.T) {
			resp := get(t, server.URL+"/content/"+u)
			defer resp.Body.Close()

			if resp.StatusCode != http.StatusOK {
				t.Errorf("GET /content/%s = %d, want %d", u, resp.StatusCode, http.StatusOK)
			}
		})
	}
}

// rootUrl in Request/Helpers.elm. If Munin's gallery name or hugin's mount
// moves, this is the request that breaks first and takes the whole app with it.
func TestFrontendEntryPointResolves(t *testing.T) {
	server := httptest.NewServer(routes(galleryRoot, ""))
	defer server.Close()

	resp := get(t, server.URL+"/content/root/index.json")
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		t.Fatalf("GET /content/root/index.json = %d, want %d", resp.StatusCode, http.StatusOK)
	}

	var album struct {
		Name   string `json:"name"`
		Albums []struct {
			URL string `json:"url"`
		} `json:"albums"`
	}

	err := json.NewDecoder(resp.Body).Decode(&album)
	if err != nil {
		t.Fatalf("decoding the album index: %s", err)
	}

	if album.Name == "" {
		t.Error("album index decoded with an empty name")
	}

	// Following a link out of the index is what the frontend does next, and it
	// is where a prefix mismatch shows up as a 404 rather than a decode error.
	for _, sub := range album.Albums {
		resp := get(t, server.URL+"/content/"+sub.URL)
		resp.Body.Close()

		if resp.StatusCode != http.StatusOK {
			t.Errorf("sub-album %s = %d, want %d", sub.URL, resp.StatusCode, http.StatusOK)
		}
	}
}

// --root-dir defaults to --content-dir, and /album/ is kept for anything still
// linking to it. Nothing covered either before.
func TestAlbumMountFallsBackToContentDir(t *testing.T) {
	server := httptest.NewServer(routes(galleryRoot, ""))
	defer server.Close()

	for _, prefix := range []string{"/content", "/album"} {
		resp := get(t, server.URL+path.Join(prefix, "root/index.json"))
		resp.Body.Close()

		if resp.StatusCode != http.StatusOK {
			t.Errorf("GET %s/root/index.json = %d, want %d", prefix, resp.StatusCode, http.StatusOK)
		}
	}
}

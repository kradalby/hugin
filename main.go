package main

import (
	"cmp"
	"embed"
	"encoding/json"
	"errors"
	"flag"
	"io"
	"io/fs"
	"log"
	"net/http"
	"os"
	"strings"

	"github.com/kradalby/kraweb"
	"golang.org/x/text/unicode/norm"
)

const defaultHostname = "hugin"

var errHostnameEmpty = errors.New("--hostname, if specified, cannot be empty")

var (
	verbose = flag.Bool("verbose", false, "be verbose")

	tailscaleKeyPath = flag.String(
		"tailscale-auth-key-path",
		"",
		"path to tailscale auth key, can be passed as TS_AUTH_KEY",
	)

	hostname = flag.String("hostname", defaultHostname, "service name")

	contentDir = flag.String(
		"content-dir",
		"",
		"directory containing a Munin-generated gallery (its targetFolder), served at /content/",
	)

	rootDir = flag.String(
		"root-dir",
		"",
		"directory served at /album/ (defaults to --content-dir if unset)",
	)

	controlURL = flag.String("controlurl", "", "Tailscale Control server, if empty, upstream")

	localAddr = flag.String("addr", "localhost:56664", "Local address to listen to")
)

func main() {
	err := Run()
	if err != nil {
		log.Fatalf("failed to start hugin: %s", err)
	}
}

// tokensFromEnv collects HUGIN_TOKEN_<NAME> variables into a lowercased
// name -> value map, which is what the frontend fetches from /tokens.
//
// Takes the environment rather than reading it, so the mapping can be tested
// without the ambient environment leaking into the result.
func tokensFromEnv(env []string) map[string]string {
	tokens := make(map[string]string)

	for _, kv := range env {
		rest, ok := strings.CutPrefix(kv, "HUGIN_TOKEN_")
		if !ok {
			continue
		}

		// Cut, not Split: a token value may itself contain "=" — base64
		// padding is the common case — and splitting on every separator
		// silently truncates the value at the first one.
		name, value, ok := strings.Cut(rest, "=")
		if !ok || name == "" {
			continue
		}

		tokens[strings.ToLower(name)] = value
	}

	return tokens
}

func tokenHandler() http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		err := json.NewEncoder(w).Encode(tokensFromEnv(os.Environ()))
		if err != nil {
			log.Printf("encoding tokens: %s", err)
		}
	})
}

//go:embed dist/*
var distFS embed.FS

func distHandler() http.Handler {
	sub, err := fs.Sub(distFS, "dist")
	if err != nil {
		log.Fatal(err)
	}

	return http.FileServer(http.FS(sub))
}

// Munin names keyword files after the IPTC keyword, which arrives in whichever
// Unicode normalisation the app that wrote the photo used. The same word
// reaches the gallery as both "Nytt_\u00e5r" and "Nytt_a\u030ar"; Munin
// publishes both spellings as URLs but writes only one file. On the gallery
// this was written against, 5 of 3,275 referenced keyword URLs name a file
// that is not on disk, and every one of them has its counterpart form sitting
// in the same directory.
//
// Gallery data outlives any Munin release — the fix upstream cannot reach a
// directory generated years ago — so hugin resolves the mismatch itself.
// Returns the other canonical form, or name unchanged when there isn't one
// (which is every pure-ASCII path).
func altNormalization(name string) string {
	if composed := norm.NFC.String(name); composed != name {
		return composed
	}

	return norm.NFD.String(name)
}

// A gallery directory that answers for either normalisation of a name.
//
// The exact name always wins, so a gallery holding both spellings still serves
// each on its own name and nothing that works today changes. Only a miss falls
// back, and only to the one other canonical form, so a request can never be
// answered by a file it did not ask for. The fallback is logged: it means the
// gallery is inconsistent, which is worth knowing rather than papering over.
type normalizingDir string

func (d normalizingDir) Open(name string) (http.File, error) {
	f, err := http.Dir(d).Open(name)
	if !errors.Is(err, fs.ErrNotExist) {
		return f, err
	}

	alt := altNormalization(name)
	if alt == name {
		return f, err
	}

	altFile, altErr := http.Dir(d).Open(alt)
	if altErr != nil {
		// The original miss is the honest answer; the fallback was a guess.
		return f, err
	}

	log.Printf("%q served as %q: gallery holds the other Unicode form", name, alt) //nolint:gosec

	return altFile, nil
}

// http.FileServer swallows the os.Open error, so the status is all that
// separates "missing" from "unreadable".
type statusRecorder struct {
	http.ResponseWriter

	status int
}

func (s *statusRecorder) WriteHeader(status int) {
	s.status = status
	s.ResponseWriter.WriteHeader(status)
}

// Embedding alone would hide io.ReaderFrom from ServeContent's sendfile path;
// io.Copy re-asserts on the wrapped writer. Only reachable on --addr — neither
// crypto/tls.Conn nor tsnet's connections implement it.
func (s *statusRecorder) ReadFrom(src io.Reader) (int64, error) {
	return io.Copy(s.ResponseWriter, src)
}

// So http.ResponseController can still reach the Flusher/Hijacker this wrapper
// hides.
func (s *statusRecorder) Unwrap() http.ResponseWriter {
	return s.ResponseWriter
}

func loggingHandler(h http.Handler, dir string) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// A handler that writes a body without WriteHeader has served a 200.
		recorder := &statusRecorder{ResponseWriter: w, status: http.StatusOK}

		h.ServeHTTP(recorder, r)

		// gosec flags any http.Request-derived value reaching a log sink as
		// log injection (G706), regardless of transformation. This is
		// operator-facing debug logging of the requested path, not a
		// security/audit log, and %q already escapes newlines/control
		// characters so a request can't forge extra log lines.
		log.Printf("%s %d - %q: %q", r.Method, recorder.status, r.URL.Path, dir+r.URL.Path) //nolint:gosec
	})
}

// routes builds everything hugin serves.
//
// Separate from Run so the served surface can be exercised without standing up
// a tailnet: kraweb owns a real tsnet node, which a test has no way to reach.
// Whatever a test drives through this mux is what production serves.
func routes(contentDir, rootDir string) *http.ServeMux {
	mux := http.NewServeMux()

	mux.Handle("/", distHandler())
	mux.Handle("/tokens", tokenHandler())

	serveDir := func(prefix, dir string) {
		handler := loggingHandler(http.FileServer(normalizingDir(dir)), dir)
		mux.Handle(prefix+"/", http.StripPrefix(prefix, handler))
	}

	if contentDir == "" {
		log.Printf("--content-dir is required to serve a gallery; /content/ and /zip/ are unmounted")
	} else {
		log.Printf("Serving content from %s", contentDir)
		serveDir("/content", contentDir)

		// Only mounted with a real gallery, so the frontend's probe 404s when
		// there is nothing to zip. Logged like the other mounts — otherwise a
		// download leaves no trace at all.
		mux.Handle("/zip/", http.StripPrefix("/zip",
			loggingHandler(zipHandler(contentDir), contentDir)))
	}

	// /album/ predates /content/ and is kept for anything still linking to it;
	// hugin's own frontend only uses /album as a client-side route.
	root := cmp.Or(rootDir, contentDir)
	if root != "" {
		serveDir("/album", root)
	}

	return mux
}

func Run() error {
	flag.Parse()

	if *hostname == "" {
		return errHostnameEmpty
	}

	logger := log.New(os.Stdout, "hugin: ", log.LstdFlags)

	k := kraweb.NewKraWeb(
		*hostname,
		*tailscaleKeyPath,
		*controlURL,
		*verbose,
		*localAddr,
		logger,
		true,
	)

	k.Handle("/", routes(*contentDir, *rootDir))

	return k.ListenAndServe()
}

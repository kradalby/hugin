package main

import (
	"cmp"
	"embed"
	"encoding/json"
	"errors"
	"flag"
	"io/fs"
	"log"
	"net/http"
	"os"
	"strings"

	"github.com/kradalby/kraweb"
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

func loggingHandler(h http.Handler, dir string) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// gosec flags any http.Request-derived value reaching a log sink as
		// log injection (G706), regardless of transformation. This is
		// operator-facing debug logging of the requested path, not a
		// security/audit log, and %q already escapes newlines/control
		// characters so a request can't forge extra log lines.
		log.Printf("%s - %q: %q", r.Method, r.URL.Path, dir+r.URL.Path) //nolint:gosec
		h.ServeHTTP(w, r)
	})
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

	k.Handle("/", distHandler())
	k.Handle("/tokens", tokenHandler())

	serveDir := func(prefix, dir string) {
		handler := loggingHandler(http.FileServer(http.Dir(dir)), dir)
		k.Handle(prefix+"/", http.StripPrefix(prefix, handler))
	}

	if *contentDir == "" {
		log.Printf("--content-dir is required to serve a gallery")
	} else {
		log.Printf("Serving content from %s", *contentDir)
		serveDir("/content", *contentDir)
	}

	// /album/ predates /content/ and is kept for anything still linking to it;
	// hugin's own frontend only uses /album as a client-side route.
	root := cmp.Or(*rootDir, *contentDir)
	if root != "" {
		serveDir("/album", root)
	}

	return k.ListenAndServe()
}

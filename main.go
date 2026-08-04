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
	if err := Run(); err != nil {
		log.Fatalf("failed to start hugin: %s", err)
	}
}

func tokenHandler() http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		tokens := make(map[string]string)
		env := os.Environ()

		for _, kv := range env {
			if rest, ok := strings.CutPrefix(kv, "HUGIN_TOKEN_"); ok {
				parts := strings.Split(rest, "=")

				tokens[strings.ToLower(parts[0])] = parts[1]
			}
		}

		if err := json.NewEncoder(w).Encode(tokens); err != nil {
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
		log.Printf("%s - %s: %s", r.Method, r.URL.Path, dir+r.URL.Path)
		h.ServeHTTP(w, r)
	})
}

func Run() error {
	flag.Parse()

	if *hostname == "" {
		return errors.New("--hostname, if specified, cannot be empty")
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

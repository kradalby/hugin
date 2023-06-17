package main

import (
	"embed"
	"errors"
	"flag"
	"io/fs"
	"log"
	"net/http"
	"os"

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

	albumDir = flag.String("album", "", "directory containing a Munin album")

	controlURL = flag.String("controlurl", "", "Tailscale Control server, if empty, upstream")

	localAddr = flag.String("addr", "localhost:56664", "Local address to listen to")
)

func main() {
	if err := Run(); err != nil {
		log.Fatalf("failed to start hugin: %s", err)
	}
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

func Run() error {
	flag.Parse()

	logger := log.New(os.Stdout, "hugin: ", log.LstdFlags)

	handlers := map[string]http.Handler{}

	handlers["/"] = distHandler()

	if *albumDir == "" {
		log.Printf("--album is required to serve an album")
	} else {
		log.Printf("Serving content from %s", *albumDir)
		handlers["/album/"] = http.StripPrefix("/album", http.FileServer(http.Dir(*albumDir)))
		handlers["/content/"] = http.StripPrefix("/content", http.FileServer(http.Dir(*albumDir)))
	}

	if *hostname == "" {
		return errors.New("--hostname, if specified, cannot be empty")
	}

	srv := kraweb.NewKraWeb(
		handlers,
		nil,
		*hostname,
		*tailscaleKeyPath,
		*controlURL,
		*verbose,
		*localAddr,
		logger,
	)

	return srv.ListenAndServe()
}

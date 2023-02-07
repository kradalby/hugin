package main

import (
	"crypto/tls"
	"embed"
	"errors"
	"flag"
	"fmt"
	"io/fs"
	"log"
	"net"
	"net/http"
	"os"
	"strings"

	"tailscale.com/client/tailscale"
	"tailscale.com/tsnet"
	"tailscale.com/tsweb"
)

const defaultHostname = "hugin"

var (
	verbose = flag.Bool("verbose", false, "be verbose")
	dev     = flag.String(
		"dev-listen",
		"",
		"if non-empty, listen on this addr and run in dev mode; don't use tsnet",
	)

	tailscaleKeyPath = flag.String(
		"tailscale-auth-key-path",
		"",
		"path to tailscale auth key, can be passed as TS_AUTH_KEY",
	)

	hostname = flag.String("hostname", defaultHostname, "service name")

	albumDir = flag.String("album", "", "directory containing a Munin album")

	controlURL = flag.String("controlurl", "", "Tailscale Control server, if empty, upstream")
)

func main() {
	err := Run()
	if err != nil {
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

var localClient *tailscale.LocalClient

func Run() error {
	flag.Parse()

	mux := http.NewServeMux()
	tsweb.Debugger(mux)

	logger := log.New(os.Stdout, "http: ", log.LstdFlags)

	httpSrv := &http.Server{
		Handler:  mux,
		ErrorLog: logger,
	}

	mux.Handle("/", distHandler())

	if *albumDir == "" {
		log.Printf("-album is required to serve an album in production")
	} else {
		log.Printf("Serving content from %s", *albumDir)
		mux.Handle("/album/", http.StripPrefix("/album", http.FileServer(http.Dir(*albumDir))))
		mux.Handle("/content/", http.StripPrefix("/content", http.FileServer(http.Dir(*albumDir))))
	}

	if *dev != "" {
		// override default hostname for dev mode
		if *hostname == defaultHostname {
			if h, p, err := net.SplitHostPort(*dev); err == nil {
				if h == "" {
					h = "localhost"
				}
				*hostname = fmt.Sprintf("%s:%s", h, p)
			}
		}

		httpSrv.Addr = *dev

		log.Printf("Running in dev mode on %s ...", *dev)
		log.Fatal(httpSrv.ListenAndServe())
	}

	if *hostname == "" {
		return errors.New("--hostname, if specified, cannot be empty")
	}

	srv := &tsnet.Server{
		Hostname:   *hostname,
		Logf:       func(format string, args ...any) {},
		ControlURL: *controlURL,
	}

	if *tailscaleKeyPath != "" {
		key, err := os.ReadFile(*tailscaleKeyPath)
		if err != nil {
			log.Fatal("failed to load tailscale auth key")
		}

		srv.AuthKey = strings.TrimSuffix(string(key), "\n")
	}

	if *verbose {
		srv.Logf = log.Printf
	}

	if err := srv.Start(); err != nil {
		return err
	}
	localClient, _ = srv.LocalClient()

	l80, err := srv.Listen("tcp", ":80")
	if err != nil {
		return err
	}

	// Starting HTTPS server
	go func() {
		l443, err := srv.Listen("tcp", ":443")
		if err != nil {
			log.Printf("failed to start https server: %s", err)
		}
		l443 = tls.NewListener(l443, &tls.Config{
			GetCertificate: localClient.GetCertificate,
		})

		log.Printf("Serving http://%s/ ...", *hostname)
		if err := httpSrv.Serve(l443); err != nil {
			log.Printf("failed to start https server: %s", err)
		}
	}()

	// TODO: Add support for magic auto HTTPS
	log.Printf("Serving http://%s/ ...", *hostname)
	if err := httpSrv.Serve(l80); err != nil {
		return err
	}
	return nil
}

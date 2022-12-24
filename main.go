package main

import (
	"embed"
	"errors"
	"flag"
	"fmt"
	"io/fs"
	"log"
	"net"
	"net/http"

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
	hostname = flag.String("hostname", defaultHostname, "service name")

	certMode = flag.String(
		"certmode",
		"letsencrypt",
		"mode for getting a cert. possible options: manual, letsencrypt",
	)
	certDir = flag.String(
		"certdir",
		tsweb.DefaultCertDir("derper-certs"),
		"directory to store LetsEncrypt certs, if addr's port is :443",
	)

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

	mux.Handle("/", distHandler())

	httpsrv := &http.Server{
		Handler: mux,
	}

	if *albumDir == "" {
		log.Printf("-album is required to serve an album in production")
	} else {
		mux.Handle("/content/", http.FileServer(http.Dir(*albumDir)))
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

		httpsrv.Addr = *dev

		log.Printf("Running in dev mode on %s ...", *dev)
		log.Fatal(httpsrv.ListenAndServe())
	}

	if *hostname == "" {
		return errors.New("--hostname, if specified, cannot be empty")
	}

	srv := &tsnet.Server{
		Hostname:   *hostname,
		Logf:       func(format string, args ...any) {},
		ControlURL: *controlURL,
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

	// TODO: Add support for magic auto HTTPS
	log.Printf("Serving http://%s/ ...", *hostname)
	if err := httpsrv.Serve(l80); err != nil {
		return err
	}
	return nil
}

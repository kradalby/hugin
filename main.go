package main

import (
	"crypto/tls"
	"embed"
	"errors"
	"flag"
	"fmt"
	"html"
	"io/fs"
	"log"
	"net"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/prometheus/client_golang/prometheus/promhttp"
	"tailscale.com/tsnet"
	"tailscale.com/tsweb"
)

type KraWeb struct {
	// pubHandlers contains endpoints that should be available over both localhost and Tailscale
	pubHandlers map[string]http.Handler

	// tsHandlers contains endpoints that should only be available over Tailscale
	tsHandlers map[string]http.Handler

	// hostname is the name that will be used when joining Tailscale
	hostname string

	tsKeyPath  string
	controlURL string
	verbose    bool
	dev        string
	localPort  int
	logger     *log.Logger
}

func NewKraWeb(
	pubHandlers map[string]http.Handler,
	tsHandlers map[string]http.Handler,
	hostname string,
	tsKeyPath string,
	controlURL string,
	verbose bool,
	dev string,
	localPort int,
	logger *log.Logger,
) KraWeb {
	return KraWeb{
		pubHandlers: pubHandlers,
		tsHandlers:  tsHandlers,
		hostname:    hostname,
		tsKeyPath:   tsKeyPath,
		controlURL:  controlURL,
		verbose:     verbose,
		dev:         dev,
		localPort:   localPort,
		logger:      logger,
	}
}

func (k *KraWeb) ListenAndServe() error {
	mux := http.NewServeMux()
	tsmux := http.NewServeMux()

	tsweb.Debugger(tsmux)

	k.logger.SetPrefix("kraweb: ")
	log := k.logger

	tsSrv := &tsnet.Server{
		Hostname:   k.hostname,
		Logf:       func(format string, args ...any) {},
		ControlURL: k.controlURL,
	}

	if k.tsKeyPath != "" {
		key, err := os.ReadFile(k.tsKeyPath)
		if err != nil {
			return err
		}

		tsSrv.AuthKey = strings.TrimSuffix(string(key), "\n")
	}

	if k.verbose {
		tsSrv.Logf = log.Printf
	}

	if err := tsSrv.Start(); err != nil {
		return err
	}

	localClient, _ := tsSrv.LocalClient()

	tsmux.Handle("/metrics", promhttp.Handler())
	tsmux.Handle("/who", http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		who, err := localClient.WhoIs(r.Context(), r.RemoteAddr)
		if err != nil {
			http.Error(w, err.Error(), 500)

			return
		}
		fmt.Fprintf(w, "<html><body><h1>Hello, world!</h1>\n")
		fmt.Fprintf(w, "<p>You are <b>%s</b> from <b>%s</b> (%s)</p>",
			html.EscapeString(who.UserProfile.LoginName),
			html.EscapeString(firstLabel(who.Node.ComputedName)),
			r.RemoteAddr)
	}))

	for pattern, handler := range k.pubHandlers {
		mux.Handle(pattern, handler)
		tsmux.Handle(pattern, handler)
	}

	for pattern, handler := range k.tsHandlers {
		tsmux.Handle(pattern, handler)
	}

	httpSrv := &http.Server{
		Handler:     mux,
		ErrorLog:    k.logger,
		ReadTimeout: 5 * time.Minute,
	}

	tshttpSrv := &http.Server{
		Handler:     tsmux,
		ErrorLog:    k.logger,
		ReadTimeout: 5 * time.Minute,
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

		tshttpSrv.Addr = *dev

		log.Printf("Running in dev mode on %s ...", *dev)
		log.Fatal(tshttpSrv.ListenAndServe())
	}

	// Starting HTTPS server
	go func() {
		ts443, err := tsSrv.Listen("tcp", ":443")
		if err != nil {
			log.Printf("failed to start https server: %s", err)
		}
		ts443 = tls.NewListener(ts443, &tls.Config{
			GetCertificate: localClient.GetCertificate,
		})

		log.Printf("Serving http://%s/ ...", k.hostname)
		if err := tshttpSrv.Serve(ts443); err != nil {
			log.Fatalf("failed to start https server in Tailscale: %s", err)
		}
	}()

	go func() {
		ts80, err := tsSrv.Listen("tcp", ":80")
		if err != nil {
			log.Printf("failed to start http server: %s", err)
		}

		log.Printf("Serving http://%s/ ...", k.hostname)
		if err := tshttpSrv.Serve(ts80); err != nil {
			log.Fatalf("failed to start http server in Tailscale: %s", err)
		}
	}()

	localListen, err := net.Listen("tcp", fmt.Sprintf(":%d", k.localPort))
	if err != nil {
		return err
	}

	log.Printf("Serving http://%s:%d/ ...", "localhost", k.localPort)
	if err := httpSrv.Serve(localListen); err != nil {
		return err
	}

	return nil
}

func firstLabel(s string) string {
	s, _, _ = strings.Cut(s, ".")
	return s
}

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

	localPort = flag.Int("port", 56664, "Port to listen to locally")
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

	kraweb := NewKraWeb(
		handlers,
		nil,
		*hostname,
		*tailscaleKeyPath,
		*controlURL,
		*verbose,
		*dev,
		*localPort,
		logger,
	)

	return kraweb.ListenAndServe()
}

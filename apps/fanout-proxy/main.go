package main

import (
	"bytes"
	"context"
	"io"
	"log"
	"net/http"
	"net/http/httputil"
	"net/url"
	"os"
	"strings"
	"time"
)

func main() {
	primary := mustURL(env("PRIMARY_URL", "http://primary-service.default.svc.cluster.local"))
	mirrorTo := mustURL(env("MIRROR_URL", "http://mirror-service.default.svc.cluster.local"))
	addr := env("LISTEN_ADDR", ":8080")

	// The primary path uses the battle-tested stdlib reverse proxy.
	proxy := httputil.NewSingleHostReverseProxy(primary)

	mirrorClient := &http.Client{Timeout: 5 * time.Second}

	// Cap in-flight mirror requests so a slow/broken second service
	// can't pile up unbounded goroutines and exhaust memory.
	slots := make(chan struct{}, 256)

	fanout := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// A body can only be read once, and we need it twice.
		var body []byte
		if r.Body != nil {
			b, err := io.ReadAll(r.Body)
			r.Body.Close()
			if err != nil {
				http.Error(w, "cannot read body", http.StatusBadRequest)
				return
			}
			body = b
		}

		fireAndForget(mirrorClient, mirrorTo, r, body, slots)

		// Hand a fresh, fixed-length body to the primary proxy and
		// recompute framing from it — drop any stale Content-Length or
		// Transfer-Encoding carried in from the client.
		r.Header.Del("Content-Length")
		r.TransferEncoding = nil
		r.Body = io.NopCloser(bytes.NewReader(body))
		r.ContentLength = int64(len(body))
		proxy.ServeHTTP(w, r)
	})

	mux := http.NewServeMux()
	// Answered locally — never forwarded to primary or mirrored.
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
		io.WriteString(w, "ok\n")
	})
	mux.Handle("/", fanout)

	log.Printf("fanout listening on %s (primary=%s mirror=%s)", addr, primary, mirrorTo)
	log.Fatal(http.ListenAndServe(addr, mux))
}

// fireAndForget sends a copy of the request to the mirror and discards
// the response. It never blocks the caller or touches the primary flow.
func fireAndForget(client *http.Client, target *url.URL, orig *http.Request, body []byte, slots chan struct{}) {
	select {
	case slots <- struct{}{}: // got a slot
	default: // saturated — drop rather than block the client
		log.Printf("mirror saturated, dropping %s %s", orig.Method, orig.URL.Path)
		return
	}

	// DETACHED context: the mirror must not be cancelled when the
	// client's original request finishes.
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)

	dst := *target
	dst.Path = joinPaths(target.Path, orig.URL.Path)
	dst.RawQuery = orig.URL.RawQuery

	req, err := http.NewRequestWithContext(ctx, orig.Method, dst.String(), bytes.NewReader(body))
	if err != nil {
		cancel()
		<-slots
		log.Printf("mirror: build request: %v", err)
		return
	}
	// Copy only end-to-end headers; let the client frame the body from
	// the bytes.Reader we handed it (don't carry over Content-Length /
	// Transfer-Encoding from the original request).
	copyEndToEndHeaders(req.Header, orig.Header)
	req.Header.Del("Content-Length") // req.ContentLength is already set from the reader
	req.Header.Set("X-Mirrored-From", "fanout-proxy")
	req.Host = target.Host

	go func() {
		defer func() {
			cancel()
			<-slots
			if p := recover(); p != nil {
				log.Printf("mirror: recovered panic: %v", p)
			}
		}()
		resp, err := client.Do(req)
		if err != nil {
			log.Printf("mirror: %v", err)
			return
		}
		io.Copy(io.Discard, resp.Body) // fire-and-forget: drain + discard
		resp.Body.Close()
	}()
}

// RFC 7230 hop-by-hop headers — never forwarded.
var hopHeaders = []string{
	"Connection", "Proxy-Connection", "Keep-Alive",
	"Proxy-Authenticate", "Proxy-Authorization",
	"Te", "Trailer", "Transfer-Encoding", "Upgrade",
}

// copyEndToEndHeaders copies src into dst, skipping hop-by-hop headers
// (both the well-known set and anything named in the Connection header).
func copyEndToEndHeaders(dst, src http.Header) {
	drop := map[string]bool{}
	for _, h := range hopHeaders {
		drop[http.CanonicalHeaderKey(h)] = true
	}
	if c := src.Get("Connection"); c != "" {
		for _, f := range strings.Split(c, ",") {
			if n := strings.TrimSpace(f); n != "" {
				drop[http.CanonicalHeaderKey(n)] = true
			}
		}
	}
	for k, vv := range src {
		if drop[http.CanonicalHeaderKey(k)] {
			continue
		}
		for _, v := range vv {
			dst.Add(k, v)
		}
	}
}

func joinPaths(a, b string) string {
	if a == "" {
		return b
	}
	return strings.TrimSuffix(a, "/") + "/" + strings.TrimPrefix(b, "/")
}

func mustURL(raw string) *url.URL {
	u, err := url.Parse(raw)
	if err != nil {
		log.Fatalf("bad URL %q: %v", raw, err)
	}
	return u
}

func env(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

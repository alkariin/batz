package web

import (
	"context"
	"crypto/tls"
	"errors"
	"fmt"
	"net"
	"net/http"
	"time"
)

// NewServer returns an HTTPS-only server for handler.
func NewServer(handler http.Handler, cert tls.Certificate) *http.Server {
	return &http.Server{
		Handler: handler,
		TLSConfig: &tls.Config{
			Certificates: []tls.Certificate{cert},
			MinVersion:   tls.VersionTLS12,
		},
		ReadHeaderTimeout: 10 * time.Second,
		ReadTimeout:       2 * time.Minute,
		WriteTimeout:      2 * time.Minute,
		IdleTimeout:       2 * time.Minute,
	}
}

// Serve serves TLS on ln until ctx is done, then shuts down gracefully.
func Serve(ctx context.Context, srv *http.Server, ln net.Listener) error {
	errc := make(chan error, 1)
	go func() { errc <- srv.ServeTLS(ln, "", "") }()
	select {
	case err := <-errc:
		return fmt.Errorf("serve: %w", err)
	case <-ctx.Done():
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		if err := srv.Shutdown(shutdownCtx); err != nil {
			return fmt.Errorf("shutdown: %w", err)
		}
		if err := <-errc; err != nil && !errors.Is(err, http.ErrServerClosed) {
			return err
		}
		return nil
	}
}

// Command batz-web is the batz server.
//
//	batz-web [serve]           serve the API over HTTPS
//	batz-web pairing-code      print a one-time code to pair a device
//	batz-web healthcheck       exit 0 if the local server answers /healthz
//
// Configuration comes from the environment, see internal/infrastructure/config.
package main

import (
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log/slog"
	"net"
	"net/http"
	"os"
	"os/signal"
	"path/filepath"
	"syscall"
	"time"

	"github.com/alkariin/batz/batz-web/internal/application"
	"github.com/alkariin/batz/batz-web/internal/domain/device"
	"github.com/alkariin/batz/batz-web/internal/infrastructure/config"
	"github.com/alkariin/batz/batz-web/internal/infrastructure/persistence"
	"github.com/alkariin/batz/batz-web/internal/infrastructure/tlscert"
	"github.com/alkariin/batz/batz-web/internal/infrastructure/web"
	"github.com/alkariin/batz/batz-web/internal/version"
)

const dbFile = "batz.db"

func main() {
	slog.SetDefault(slog.New(slog.NewTextHandler(os.Stderr, nil)))
	if err := run(os.Args[1:], os.Stdout); err != nil {
		fmt.Fprintln(os.Stderr, "batz-web:", err)
		os.Exit(1)
	}
}

func run(args []string, out io.Writer) error {
	cfg, err := config.Load(os.Getenv)
	if err != nil {
		return err
	}
	cmd := "serve"
	if len(args) > 0 {
		cmd, args = args[0], args[1:]
	}
	switch cmd {
	case "serve":
		return serve(cfg)
	case "pairing-code":
		return pairingCode(cfg, args, out)
	case "healthcheck":
		return healthcheck(cfg)
	case "version":
		fmt.Fprintln(out, version.Version)
		return nil
	default:
		return fmt.Errorf("unknown command %q (serve, pairing-code, healthcheck, version)", cmd)
	}
}

func openDevices(cfg config.Config) (*application.Devices, func(), error) {
	if err := os.MkdirAll(cfg.DataDir, 0o700); err != nil {
		return nil, nil, fmt.Errorf("create data directory: %w", err)
	}
	db, err := persistence.Open(filepath.Join(cfg.DataDir, dbFile))
	if err != nil {
		return nil, nil, err
	}
	return application.NewDevices(persistence.NewDeviceStore(db), time.Now), func() { db.Close() }, nil
}

func serve(cfg config.Config) error {
	devices, closeDB, err := openDevices(cfg)
	if err != nil {
		return err
	}
	defer closeDB()
	cert, err := tlscert.LoadOrCreate(cfg.DataDir, time.Now())
	if err != nil {
		return err
	}
	ln, err := net.Listen("tcp", fmt.Sprintf(":%d", cfg.Port))
	if err != nil {
		return fmt.Errorf("listen: %w", err)
	}
	slog.Info("batz-web started",
		"version", version.Version, "port", cfg.Port, "dataDir", cfg.DataDir,
		"certificateFingerprint", tlscert.Fingerprint(cert))

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()
	router := web.NewRouter(devices, web.Health{Version: version.Version, MinAppVersion: version.MinAppVersion})
	err = web.Serve(ctx, web.NewServer(router, cert), ln)
	slog.Info("batz-web stopped")
	return err
}

func pairingCode(cfg config.Config, args []string, out io.Writer) error {
	fs := flag.NewFlagSet("pairing-code", flag.ContinueOnError)
	ttl := fs.Duration("ttl", device.PairingCodeTTL, "validity of the code, at most 10m")
	if err := fs.Parse(args); err != nil {
		return err
	}
	devices, closeDB, err := openDevices(cfg)
	if err != nil {
		return err
	}
	defer closeDB()
	// The certificate is created here too if the server never started, so
	// the fingerprint printed is the one the app will see.
	cert, err := tlscert.LoadOrCreate(cfg.DataDir, time.Now())
	if err != nil {
		return err
	}
	code, err := devices.CreatePairingCode(context.Background(), *ttl)
	if err != nil {
		return err
	}
	fmt.Fprintf(out, "Pairing code: %s\n", code.Code)
	fmt.Fprintf(out, "Valid until:  %s\n", code.ExpiresAt.Local().Format("2006-01-02 15:04:05 MST"))
	fmt.Fprintf(out, "Server certificate fingerprint (SHA-256):\n  %s\n", tlscert.Fingerprint(cert))
	return nil
}

func healthcheck(cfg config.Config) error {
	cert, err := tlscert.Load(cfg.DataDir)
	if err != nil {
		return err
	}
	client := &http.Client{
		Timeout:   3 * time.Second,
		Transport: &http.Transport{TLSClientConfig: tlscert.PinnedConfig(tlscert.Fingerprint(cert))},
	}
	resp, err := client.Get(fmt.Sprintf("https://127.0.0.1:%d/healthz", cfg.Port))
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	var body struct{ Status string }
	if err := json.NewDecoder(resp.Body).Decode(&body); err != nil || resp.StatusCode != http.StatusOK || body.Status != "ok" {
		return fmt.Errorf("unhealthy: HTTP %d", resp.StatusCode)
	}
	return nil
}

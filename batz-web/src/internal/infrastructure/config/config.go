// Package config reads the server configuration from the environment, once,
// at start-up.
package config

import (
	"fmt"
	"strconv"
)

// Config is the whole server configuration.
type Config struct {
	// DataDir holds the database, the TLS certificate and, later, the
	// original statements. It is the only directory to back up.
	DataDir string
	// Port is the HTTPS port.
	Port int
}

const (
	defaultDataDir = "data"
	defaultPort    = 8443
)

// Load reads BATZ_DATA_DIR and BATZ_PORT through getenv (os.Getenv in
// production).
func Load(getenv func(string) string) (Config, error) {
	cfg := Config{DataDir: defaultDataDir, Port: defaultPort}
	if v := getenv("BATZ_DATA_DIR"); v != "" {
		cfg.DataDir = v
	}
	if v := getenv("BATZ_PORT"); v != "" {
		port, err := strconv.Atoi(v)
		if err != nil || port < 1 || port > 65535 {
			return Config{}, fmt.Errorf("BATZ_PORT must be a port number, got %q", v)
		}
		cfg.Port = port
	}
	return cfg, nil
}

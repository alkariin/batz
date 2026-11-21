// Package config reads the server configuration from the environment, once,
// at start-up.
package config

import (
	"fmt"
	"strconv"
)

// Config is the whole server configuration.
type Config struct {
	// DataDir holds the database, the TLS certificate, the original
	// statements and the dated copies of the database. It is the only
	// directory to back up.
	DataDir string
	// Port is the HTTPS port.
	Port int
	// Backups is how many dated copies of the database are kept.
	Backups int
}

const (
	defaultDataDir = "data"
	defaultPort    = 8443
	defaultBackups = 12
)

// Load reads BATZ_DATA_DIR, BATZ_PORT and BATZ_BACKUPS through getenv
// (os.Getenv in production).
func Load(getenv func(string) string) (Config, error) {
	cfg := Config{DataDir: defaultDataDir, Port: defaultPort, Backups: defaultBackups}
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
	if v := getenv("BATZ_BACKUPS"); v != "" {
		n, err := strconv.Atoi(v)
		if err != nil || n < 1 || n > 1000 {
			return Config{}, fmt.Errorf("BATZ_BACKUPS must be a number from 1 to 1000, got %q", v)
		}
		cfg.Backups = n
	}
	return cfg, nil
}

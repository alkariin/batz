package config

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func env(m map[string]string) func(string) string { return func(k string) string { return m[k] } }

func TestDefaults(t *testing.T) {
	cfg, err := Load(env(nil))
	require.NoError(t, err)
	assert.Equal(t, Config{DataDir: "data", Port: 8443}, cfg)
}

func TestFromEnvironment(t *testing.T) {
	cfg, err := Load(env(map[string]string{"BATZ_DATA_DIR": "/data", "BATZ_PORT": "9443"}))
	require.NoError(t, err)
	assert.Equal(t, Config{DataDir: "/data", Port: 9443}, cfg)
}

func TestInvalidPort(t *testing.T) {
	for _, v := range []string{"abc", "0", "70000", "-1"} {
		_, err := Load(env(map[string]string{"BATZ_PORT": v}))
		assert.Error(t, err, v)
	}
}

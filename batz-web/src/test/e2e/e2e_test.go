// Package e2e runs the real batz-web binary over HTTPS, the way an app and
// the server administrator use it.
package e2e

import (
	"bytes"
	"crypto/tls"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sync"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/alkariin/batz/batz-web/internal/infrastructure/tlscert"
	"github.com/alkariin/batz/batz-web/internal/version"
)

var (
	binary    string
	buildOnce sync.Once
	buildErr  error
)

func TestMain(m *testing.M) {
	dir, err := os.MkdirTemp("", "batz-e2e")
	if err != nil {
		panic(err)
	}
	binary = filepath.Join(dir, "batz-web")
	code := m.Run()
	os.RemoveAll(dir)
	os.Exit(code)
}

// build compiles the server once. It runs inside a test, not in TestMain, so
// that the source files it opens are recorded by the test cache.
func build(t *testing.T) {
	t.Helper()
	buildOnce.Do(func() {
		if buildErr = touchSources("../.."); buildErr != nil {
			return
		}
		cmd := exec.Command("go", "build", "-ldflags", "-X github.com/alkariin/batz/batz-web/internal/version.Version=v0.0.0-e2e", "-o", binary, "../..")
		out, err := cmd.CombinedOutput()
		if err != nil {
			buildErr = fmt.Errorf("build server: %w\n%s", err, out)
		}
	})
	require.NoError(t, buildErr)
}

// touchSources opens every source file of the module. `go test` caches a
// result together with the files the test opened, so a change to the server
// code reruns these tests instead of replaying a stale success: the binary
// is built by a subprocess the cache cannot see.
func touchSources(root string) error {
	return filepath.WalkDir(root, func(path string, d os.DirEntry, err error) error {
		if err != nil || d.IsDir() {
			return err
		}
		if ext := filepath.Ext(path); ext == ".go" || ext == ".sql" || ext == ".mod" || ext == ".sum" {
			f, err := os.Open(path)
			if err != nil {
				return err
			}
			return f.Close()
		}
		return nil
	})
}

type server struct {
	t           *testing.T
	dataDir     string
	port        int
	fingerprint string
}

func freePort(t *testing.T) int {
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	require.NoError(t, err)
	defer ln.Close()
	return ln.Addr().(*net.TCPAddr).Port
}

func (s *server) env() []string {
	return append(os.Environ(), "BATZ_DATA_DIR="+s.dataDir, fmt.Sprintf("BATZ_PORT=%d", s.port))
}

// start launches `batz-web serve` and waits until it answers.
func start(t *testing.T, dataDir string) *server {
	t.Helper()
	build(t)
	s := &server{t: t, dataDir: dataDir, port: freePort(t)}
	cmd := exec.Command(binary, "serve")
	cmd.Env = s.env()
	var logs bytes.Buffer
	cmd.Stdout, cmd.Stderr = &logs, &logs
	require.NoError(t, cmd.Start())
	t.Cleanup(func() {
		cmd.Process.Signal(os.Interrupt)
		cmd.Wait()
		if t.Failed() {
			t.Logf("server logs:\n%s", logs.String())
		}
	})

	require.Eventually(t, func() bool {
		cert, err := tlscert.Load(dataDir)
		if err != nil {
			return false
		}
		s.fingerprint = tlscert.Fingerprint(cert)
		resp, err := s.client(s.fingerprint).Get(s.url("/healthz"))
		if err != nil {
			return false
		}
		resp.Body.Close()
		return resp.StatusCode == http.StatusOK
	}, 10*time.Second, 50*time.Millisecond, "server did not start")
	return s
}

func (s *server) url(path string) string { return fmt.Sprintf("https://127.0.0.1:%d%s", s.port, path) }

func (s *server) client(fingerprint string) *http.Client {
	return &http.Client{Timeout: 5 * time.Second, Transport: &http.Transport{TLSClientConfig: tlscert.PinnedConfig(fingerprint)}}
}

var codeLine = regexp.MustCompile(`Pairing code: (\S+)`)

// pairingCode runs `batz-web pairing-code` next to the running server.
func (s *server) pairingCode(args ...string) string {
	s.t.Helper()
	cmd := exec.Command(binary, append([]string{"pairing-code"}, args...)...)
	cmd.Env = s.env()
	out, err := cmd.CombinedOutput()
	require.NoError(s.t, err, string(out))
	assert.Contains(s.t, string(out), s.fingerprint, "the command prints the fingerprint the app will see")
	m := codeLine.FindStringSubmatch(string(out))
	require.NotNil(s.t, m, string(out))
	return m[1]
}

func (s *server) call(method, path, key string, body any) (int, map[string]any) {
	s.t.Helper()
	var buf bytes.Buffer
	if body != nil {
		require.NoError(s.t, json.NewEncoder(&buf).Encode(body))
	}
	req, err := http.NewRequest(method, s.url(path), &buf)
	require.NoError(s.t, err)
	req.Header.Set("Content-Type", "application/json")
	if key != "" {
		req.Header.Set("Authorization", "Bearer "+key)
	}
	resp, err := s.client(s.fingerprint).Do(req)
	require.NoError(s.t, err)
	defer resp.Body.Close()
	var out map[string]any
	if resp.StatusCode != http.StatusNoContent {
		require.NoError(s.t, json.NewDecoder(resp.Body).Decode(&out))
	}
	return resp.StatusCode, out
}

func (s *server) pair(code, name string) (int, map[string]any) {
	return s.call("POST", "/api/v1/pairing", "", map[string]string{"code": code, "name": name})
}

func TestHealthzOverHTTPS(t *testing.T) {
	s := start(t, t.TempDir())
	status, body := s.call("GET", "/healthz", "", nil)
	assert.Equal(t, http.StatusOK, status)
	assert.Equal(t, "ok", body["status"])
	assert.Equal(t, "v0.0.0-e2e", body["version"])
	assert.Equal(t, version.MinAppVersion, body["minAppVersion"])
	assert.Equal(t, float64(1), body["syncProtocol"])

	// HTTPS only: a plain HTTP request gets no API answer.
	resp, err := http.Get(fmt.Sprintf("http://127.0.0.1:%d/healthz", s.port))
	if err == nil {
		assert.Equal(t, http.StatusBadRequest, resp.StatusCode)
		resp.Body.Close()
	}

	// The image's health check command.
	cmd := exec.Command(binary, "healthcheck")
	cmd.Env = s.env()
	out, err := cmd.CombinedOutput()
	assert.NoError(t, err, string(out))
}

func TestPairingCodes(t *testing.T) {
	s := start(t, t.TempDir())

	// A valid code pairs a device once.
	code := s.pairingCode()
	status, body := s.pair(code, "Phone")
	require.Equal(t, http.StatusCreated, status, body)
	key := body["deviceKey"].(string)
	status, _ = s.call("GET", "/api/v1/devices", key, nil)
	assert.Equal(t, http.StatusOK, status)

	// Already used.
	status, body = s.pair(code, "Phone again")
	assert.Equal(t, http.StatusUnauthorized, status)
	assert.Equal(t, "PAIRING_CODE_USED", body["code"])

	// Wrong.
	status, body = s.pair("ZZZZ-ZZZZ", "Phone")
	assert.Equal(t, http.StatusUnauthorized, status)
	assert.Equal(t, "PAIRING_CODE_INVALID", body["code"])

	// Expired.
	short := s.pairingCode("-ttl", "1s")
	time.Sleep(1100 * time.Millisecond)
	status, body = s.pair(short, "Phone")
	assert.Equal(t, http.StatusUnauthorized, status)
	assert.Equal(t, "PAIRING_CODE_EXPIRED", body["code"])
}

func TestKeysAndRevocation(t *testing.T) {
	s := start(t, t.TempDir())
	_, phone := s.pair(s.pairingCode(), "Phone")
	_, laptop := s.pair(s.pairingCode(), "Laptop")
	phoneKey, laptopKey := phone["deviceKey"].(string), laptop["deviceKey"].(string)

	// No key.
	status, body := s.call("GET", "/api/v1/devices", "", nil)
	assert.Equal(t, http.StatusUnauthorized, status)
	assert.Equal(t, "DEVICE_KEY_MISSING", body["code"])

	// Revoked from another device.
	status, _ = s.call("DELETE", "/api/v1/devices/"+phone["deviceId"].(string), laptopKey, nil)
	require.Equal(t, http.StatusNoContent, status)
	status, body = s.call("GET", "/api/v1/devices", phoneKey, nil)
	assert.Equal(t, http.StatusUnauthorized, status)
	assert.Equal(t, "DEVICE_REVOKED", body["code"])
	status, _ = s.call("GET", "/api/v1/devices", laptopKey, nil)
	assert.Equal(t, http.StatusOK, status)
}

func TestStateSurvivesARestart(t *testing.T) {
	dir := t.TempDir()
	first := start(t, dir)
	_, phone := first.pair(first.pairingCode(), "Phone")
	fingerprint := first.fingerprint

	second := start(t, dir) // same data dir, new process and port
	assert.Equal(t, fingerprint, second.fingerprint, "the certificate is kept in the data directory")
	status, _ := second.call("GET", "/api/v1/devices", phone["deviceKey"].(string), nil)
	assert.Equal(t, http.StatusOK, status)
}

func TestAnotherCertificateIsRefused(t *testing.T) {
	genuine := start(t, t.TempDir())
	impostor := start(t, t.TempDir()) // same software, its own certificate

	// A client pinned on the genuine server refuses the impostor.
	_, err := genuine.client(genuine.fingerprint).Get(impostor.url("/healthz"))
	require.Error(t, err)
	assert.True(t, errors.Is(err, tlscert.ErrFingerprintMismatch), err)

	// Without the pin, the self-signed certificate is not trusted either.
	_, err = (&http.Client{Transport: &http.Transport{TLSClientConfig: &tls.Config{}}}).Get(genuine.url("/healthz"))
	assert.Error(t, err)
}

func entryJSON(millis int, origin, record, field, value string) map[string]string {
	return map[string]string{
		"hlc": fmt.Sprintf("%015d:0000:%s", millis, origin), "entity": "note", "recordId": record, "field": field, "value": value,
	}
}

func (s *server) exchange(key string, known map[string]string, since map[string]string, entries ...map[string]string) map[string]any {
	s.t.Helper()
	if entries == nil {
		entries = []map[string]string{}
	}
	status, body := s.call("POST", "/api/v1/sync", key, map[string]any{
		"protocol": 1, "appVersion": "0.3.0", "known": known, "since": since, "entries": entries, "limit": 2,
	})
	require.Equal(s.t, http.StatusOK, status, body)
	return body
}

// Two simulated devices exchange their entries through the real binary,
// with pages of two entries; the journal survives a restart.
func TestSyncBetweenTwoDevices(t *testing.T) {
	dir := t.TempDir()
	s := start(t, dir)
	_, phone := s.pair(s.pairingCode(), "Phone")
	_, laptop := s.pair(s.pairingCode(), "Laptop")
	phoneKey, laptopKey := phone["deviceKey"].(string), laptop["deviceKey"].(string)
	const a, b = "aaaaaaaa-0000-4000-8000-000000000000", "bbbbbbbb-0000-4000-8000-000000000000"

	page := []map[string]string{
		entryJSON(1000, a, "n1", "title", `"Loyer"`),
		entryJSON(1000, a, "n1", "amount", `-150000`),
		entryJSON(2000, a, "n2", "title", `"Coop"`),
	}
	body := s.exchange(phoneKey, map[string]string{a: page[2]["hlc"]}, nil, page...)
	assert.Equal(t, float64(3), body["added"])

	// The laptop pages through them: two pages, the first modification whole.
	pull := func(srv *server, key string, known map[string]string) []any {
		var got []any
		for range 10 {
			body := srv.exchange(key, known, nil)
			entries := body["entries"].([]any)
			got = append(got, entries...)
			for _, e := range entries {
				known[a] = e.(map[string]any)["hlc"].(string)
			}
			if body["more"] == false {
				break
			}
		}
		return got
	}
	got := pull(s, laptopKey, map[string]string{})
	require.Len(t, got, 3)

	// The laptop's own change, sent the same way.
	mine := entryJSON(3000, b, "n1", "title", `"Loyer et charges"`)
	body = s.exchange(laptopKey, map[string]string{a: page[2]["hlc"], b: mine["hlc"]}, map[string]string{}, mine)
	assert.Equal(t, float64(1), body["added"])

	// After a restart, a device holding nothing receives all four once.
	again := start(t, dir)
	all := again.exchange(phoneKey, map[string]string{}, nil)
	assert.Len(t, all["entries"].([]any), 2, "pages of two")
	assert.Equal(t, map[string]any{a: page[2]["hlc"], b: mine["hlc"]}, all["known"])
}

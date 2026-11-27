package web

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/alkariin/batz/batz-web/internal/application"
	"github.com/alkariin/batz/batz-web/internal/domain/device"
	"github.com/alkariin/batz/batz-web/internal/infrastructure/extraction"
	"github.com/alkariin/batz/batz-web/internal/infrastructure/persistence"
)

type fixture struct {
	t       *testing.T
	devices *application.Devices
	imports *application.Imports
	backups *persistence.Backups
	handler http.Handler
	now     time.Time
}

func newFixture(t *testing.T) *fixture {
	t.Helper()
	db, err := persistence.Open(filepath.Join(t.TempDir(), "batz.db"))
	require.NoError(t, err)
	t.Cleanup(func() { db.Close() })
	f := &fixture{t: t, now: time.Date(2026, 11, 20, 10, 0, 0, 0, time.UTC)}
	f.devices = application.NewDevices(persistence.NewDeviceStore(db), func() time.Time { return f.now })
	sync := application.NewSync(persistence.NewJournalStore(db), func() time.Time { return f.now })
	dir := t.TempDir()
	f.backups = persistence.NewBackups(db, filepath.Join(dir, "backups"), 12, func() time.Time {
		f.now = f.now.Add(time.Second)
		return f.now
	})
	f.imports = application.NewImports(extraction.New(), persistence.NewStatementFiles(filepath.Join(dir, "statements")), f.backups)
	f.handler = NewRouter(f.devices, sync, f.imports, Health{Version: "v9.9.9", MinAppVersion: "0.1.0", ImportFormats: []string{"postfinance", "neon"}})
	return f
}

func (f *fixture) do(method, path, key string, body any) (*httptest.ResponseRecorder, map[string]any) {
	f.t.Helper()
	var r *http.Request
	if body != nil {
		var buf bytes.Buffer
		if s, ok := body.(string); ok {
			buf.WriteString(s)
		} else {
			require.NoError(f.t, json.NewEncoder(&buf).Encode(body))
		}
		r = httptest.NewRequest(method, path, &buf)
		r.Header.Set("Content-Type", "application/json")
	} else {
		r = httptest.NewRequest(method, path, nil)
	}
	if key != "" {
		r.Header.Set("Authorization", "Bearer "+key)
	}
	w := httptest.NewRecorder()
	f.handler.ServeHTTP(w, r)
	var out map[string]any
	if w.Body.Len() > 0 {
		require.NoError(f.t, json.Unmarshal(w.Body.Bytes(), &out), w.Body.String())
	}
	return w, out
}

func (f *fixture) code() string {
	f.t.Helper()
	c, err := f.devices.CreatePairingCode(context.Background(), device.PairingCodeTTL)
	require.NoError(f.t, err)
	return c.Code
}

func (f *fixture) pair(name string) (id, key string) {
	f.t.Helper()
	w, body := f.do("POST", "/api/v1/pairing", "", map[string]string{"code": f.code(), "name": name})
	require.Equal(f.t, http.StatusCreated, w.Code, body)
	return body["deviceId"].(string), body["deviceKey"].(string)
}

func TestHealthz(t *testing.T) {
	f := newFixture(t)
	w, body := f.do("GET", "/healthz", "", nil)
	assert.Equal(t, http.StatusOK, w.Code)
	assert.Equal(t, map[string]any{
		"status": "ok", "version": "v9.9.9", "minAppVersion": "0.1.0", "syncProtocol": float64(1),
		"importFormats": []any{"postfinance", "neon"},
	}, body)
}

func TestPairing(t *testing.T) {
	f := newFixture(t)
	code := f.code()

	w, body := f.do("POST", "/api/v1/pairing", "", map[string]string{"code": code, "name": "Phone"})
	require.Equal(t, http.StatusCreated, w.Code)
	assert.NotEmpty(t, body["deviceId"])
	assert.NotEmpty(t, body["deviceKey"])

	w, body = f.do("POST", "/api/v1/pairing", "", map[string]string{"code": code, "name": "Phone"})
	assert.Equal(t, http.StatusUnauthorized, w.Code)
	assert.Equal(t, CodePairingCodeUsed, body["code"])

	w, body = f.do("POST", "/api/v1/pairing", "", map[string]string{"code": "0000-0000", "name": "Phone"})
	assert.Equal(t, http.StatusUnauthorized, w.Code)
	assert.Equal(t, CodePairingCodeInvalid, body["code"])

	expiring := f.code()
	f.now = f.now.Add(device.PairingCodeTTL)
	w, body = f.do("POST", "/api/v1/pairing", "", map[string]string{"code": expiring, "name": "Phone"})
	assert.Equal(t, http.StatusUnauthorized, w.Code)
	assert.Equal(t, CodePairingCodeExpired, body["code"])
}

func TestPairingBadRequests(t *testing.T) {
	f := newFixture(t)
	w, body := f.do("POST", "/api/v1/pairing", "", "{not json")
	assert.Equal(t, http.StatusBadRequest, w.Code)
	assert.Equal(t, CodeBadRequest, body["code"])

	w, body = f.do("POST", "/api/v1/pairing", "", map[string]string{"code": f.code(), "name": ""})
	assert.Equal(t, http.StatusBadRequest, w.Code)
	assert.Equal(t, CodeDeviceNameInvalid, body["code"])

	huge := `{"code":"` + strings.Repeat("A", 2<<20) + `","name":"x"}`
	w, _ = f.do("POST", "/api/v1/pairing", "", huge)
	assert.Equal(t, http.StatusBadRequest, w.Code)
}

func TestDevicesNeedAValidKey(t *testing.T) {
	f := newFixture(t)
	f.pair("Phone")

	w, body := f.do("GET", "/api/v1/devices", "", nil)
	assert.Equal(t, http.StatusUnauthorized, w.Code)
	assert.Equal(t, CodeDeviceKeyMissing, body["code"])

	w, body = f.do("GET", "/api/v1/devices", "wrong", nil)
	assert.Equal(t, http.StatusUnauthorized, w.Code)
	assert.Equal(t, CodeDeviceKeyInvalid, body["code"])
}

func TestListAndRevokeDevices(t *testing.T) {
	f := newFixture(t)
	phoneID, phoneKey := f.pair("Phone")
	f.now = f.now.Add(time.Minute)
	laptopID, laptopKey := f.pair("Laptop")

	w, body := f.do("GET", "/api/v1/devices", laptopKey, nil)
	require.Equal(t, http.StatusOK, w.Code)
	list := body["devices"].([]any)
	require.Len(t, list, 2)
	phone, laptop := list[0].(map[string]any), list[1].(map[string]any)
	assert.Equal(t, phoneID, phone["id"])
	assert.Equal(t, "Phone", phone["name"])
	assert.Equal(t, false, phone["current"])
	assert.Nil(t, phone["revokedAt"])
	assert.Equal(t, laptopID, laptop["id"])
	assert.Equal(t, true, laptop["current"])
	assert.NotContains(t, w.Body.String(), phoneKey)

	// The laptop revokes the phone: the phone is refused from then on.
	w, _ = f.do("DELETE", "/api/v1/devices/"+phoneID, laptopKey, nil)
	assert.Equal(t, http.StatusNoContent, w.Code)
	w, body = f.do("GET", "/api/v1/devices", phoneKey, nil)
	assert.Equal(t, http.StatusUnauthorized, w.Code)
	assert.Equal(t, CodeDeviceRevoked, body["code"])

	w, body = f.do("GET", "/api/v1/devices", laptopKey, nil)
	require.Equal(t, http.StatusOK, w.Code)
	assert.NotNil(t, body["devices"].([]any)[0].(map[string]any)["revokedAt"])

	w, body = f.do("DELETE", "/api/v1/devices/unknown", laptopKey, nil)
	assert.Equal(t, http.StatusNotFound, w.Code)
	assert.Equal(t, CodeDeviceNotFound, body["code"])

	// A device unpairs by revoking itself.
	w, _ = f.do("DELETE", "/api/v1/devices/"+laptopID, laptopKey, nil)
	assert.Equal(t, http.StatusNoContent, w.Code)
	w, _ = f.do("GET", "/api/v1/devices", laptopKey, nil)
	assert.Equal(t, http.StatusUnauthorized, w.Code)
}

func TestUnknownRoute(t *testing.T) {
	f := newFixture(t)
	w, body := f.do("GET", "/nope", "", nil)
	assert.Equal(t, http.StatusNotFound, w.Code)
	assert.Equal(t, CodeNotFound, body["code"])
}

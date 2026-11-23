package web

import (
	"fmt"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/alkariin/batz/batz-web/internal/version"
)

const origin = "aaaaaaaa-0000-4000-8000-000000000000"

func stamp(millis int) string { return fmt.Sprintf("%015d:0000:%s", millis, origin) }

func wireEntry(millis int, field string, value string) map[string]string {
	return map[string]string{"hlc": stamp(millis), "entity": "transaction", "recordId": "t1", "field": field, "value": value}
}

func syncBody(known map[string]string, entries ...map[string]string) map[string]any {
	if entries == nil {
		entries = []map[string]string{}
	}
	return map[string]any{"protocol": 1, "appVersion": "0.10.0-alpha", "known": known, "since": map[string]string{}, "entries": entries}
}

// everything returns what a device that holds nothing receives.
func (f *fixture) everything(key string) []any {
	f.t.Helper()
	w, body := f.do("POST", "/api/v1/sync", key, syncBody(nil))
	require.Equal(f.t, http.StatusOK, w.Code, body)
	require.Equal(f.t, false, body["more"])
	return body["entries"].([]any)
}

func TestSyncExchangesEntries(t *testing.T) {
	f := newFixture(t)
	_, phone := f.pair("Phone")
	_, laptop := f.pair("Laptop")

	page := []map[string]string{wireEntry(1000, "note", `"Légumes"`), wireEntry(1000, "amount", `-4590`)}
	w, body := f.do("POST", "/api/v1/sync", phone, syncBody(map[string]string{origin: stamp(1000)}, page...))
	require.Equal(t, http.StatusOK, w.Code, body)
	assert.Equal(t, float64(1), body["protocol"])
	assert.Equal(t, float64(2), body["added"])
	assert.Equal(t, map[string]any{origin: stamp(1000)}, body["known"])
	assert.Equal(t, []any{}, body["entries"])
	assert.Equal(t, map[string]any{}, body["since"])
	assert.Equal(t, "2026-11-20T10:00:00Z", body["serverTime"])

	got := f.everything(laptop)
	require.Len(t, got, 2)
	assert.Equal(t, map[string]any{"hlc": stamp(1000), "entity": "transaction", "recordId": "t1", "field": "amount", "value": "-4590"}, got[0])
	assert.Equal(t, `"Légumes"`, got[1].(map[string]any)["value"], "the value comes back exactly as sent")
}

func TestSyncAcceptsTheSamePageTwiceWithoutDuplicate(t *testing.T) {
	f := newFixture(t)
	_, phone := f.pair("Phone")
	page := []map[string]string{wireEntry(1000, "note", `"a"`), wireEntry(2000, "note", `"b"`)}
	for _, added := range []float64{2, 0} {
		w, body := f.do("POST", "/api/v1/sync", phone, syncBody(nil, page...))
		require.Equal(t, http.StatusOK, w.Code, body)
		assert.Equal(t, added, body["added"])
	}
	assert.Len(t, f.everything(phone), 2)
}

func TestSyncRefusesAnIncorrectPageWhole(t *testing.T) {
	f := newFixture(t)
	_, phone := f.pair("Phone")
	valid := wireEntry(1000, "note", `"a"`)
	for name, bad := range map[string]map[string]string{
		"float":        wireEntry(2000, "amount", `1.5`),
		"object":       wireEntry(2000, "note", `{"x":1}`),
		"not json":     wireEntry(2000, "note", `abc`),
		"bad hlc":      {"hlc": "123", "entity": "transaction", "recordId": "t1", "field": "note", "value": `"a"`},
		"no record":    {"hlc": stamp(2000), "entity": "transaction", "recordId": "", "field": "note", "value": `"a"`},
		"bad entity":   {"hlc": stamp(2000), "entity": "Bad Entity", "recordId": "t1", "field": "note", "value": `"a"`},
		"bad deletion": wireEntry(2000, "_deleted", `"yes"`),
		"unsorted":     wireEntry(500, "note", `"a"`),
		"twice":        valid,
	} {
		w, body := f.do("POST", "/api/v1/sync", phone, syncBody(nil, valid, bad))
		assert.Equal(t, http.StatusBadRequest, w.Code, name)
		assert.Equal(t, CodeSyncPageInvalid, body["code"], name)
		assert.Empty(t, f.everything(phone), "%s: nothing of the page is kept", name)
	}

	w, body := f.do("POST", "/api/v1/sync", phone, syncBody(map[string]string{origin: "x"}))
	assert.Equal(t, http.StatusBadRequest, w.Code)
	assert.Equal(t, CodeSyncPageInvalid, body["code"])

	w, body = f.do("POST", "/api/v1/sync", phone, `{"protocol": 1, "appVersion": "0.10.0-alpha", "extra": true}`)
	assert.Equal(t, http.StatusBadRequest, w.Code)
	assert.Equal(t, CodeBadRequest, body["code"])

	w, body = f.do("POST", "/api/v1/sync", phone, `{not json`)
	assert.Equal(t, http.StatusBadRequest, w.Code)
	assert.Equal(t, CodeBadRequest, body["code"])
}

func TestSyncRefusesAPageThatWouldLeaveAGap(t *testing.T) {
	f := newFixture(t)
	_, phone := f.pair("Phone")
	req := syncBody(nil, wireEntry(3000, "note", `"c"`))
	req["since"] = map[string]string{origin: stamp(2000)}
	w, body := f.do("POST", "/api/v1/sync", phone, req)
	assert.Equal(t, http.StatusConflict, w.Code)
	assert.Equal(t, CodeSyncStateChanged, body["code"])
	assert.Empty(t, f.everything(phone))
}

func TestSyncChecksProtocolAndAppVersion(t *testing.T) {
	f := newFixture(t)
	_, phone := f.pair("Phone")
	req := syncBody(nil)
	req["protocol"] = 2
	w, body := f.do("POST", "/api/v1/sync", phone, req)
	assert.Equal(t, http.StatusBadRequest, w.Code)
	assert.Equal(t, CodeSyncProtocolUnsupported, body["code"])

	for _, old := range []string{"0.2.0", "0.6.0", "0.8.0-alpha", "0.9.0", "0.9.0-alpha"} {
		req = syncBody(nil)
		req["appVersion"] = old
		w, body = f.do("POST", "/api/v1/sync", phone, req)
		assert.Equal(t, http.StatusUpgradeRequired, w.Code, old)
		assert.Equal(t, CodeAppVersionUnsupported, body["code"], old)
		assert.Contains(t, body["message"], version.MinAppVersion)
	}

	// The server 0.10.0-alpha accepts apps 0.10.0, and apps 0.10.0-alpha,
	// whose suffix does not count.
	assert.Equal(t, "0.10.0", version.MinAppVersion)
	for _, accepted := range []string{"0.10.0", "0.10.0-alpha"} {
		req = syncBody(nil)
		req["appVersion"] = accepted
		w, _ = f.do("POST", "/api/v1/sync", phone, req)
		assert.Equal(t, http.StatusOK, w.Code, accepted)
	}
}

func TestSyncSizeLimits(t *testing.T) {
	f := newFixture(t)
	_, phone := f.pair("Phone")

	entries := make([]map[string]string, 10001)
	for i := range entries {
		entries[i] = wireEntry(1000, fmt.Sprintf("f%d", i), "1")
	}
	w, body := f.do("POST", "/api/v1/sync", phone, syncBody(nil, entries...))
	assert.Equal(t, http.StatusRequestEntityTooLarge, w.Code)
	assert.Equal(t, CodeSyncPageTooLarge, body["code"])

	huge := `{"protocol": 1, "appVersion": "0.10.0-alpha", "entries": [{"hlc": "` + strings.Repeat("0", 33<<20) + `"}]}`
	w, body = f.do("POST", "/api/v1/sync", phone, huge)
	assert.Equal(t, http.StatusRequestEntityTooLarge, w.Code)
	assert.Equal(t, CodeSyncPageTooLarge, body["code"])

	// A page larger than the 1 MiB of the other routes is fine here.
	big := make([]map[string]string, 0, 50)
	for i := range 50 {
		big = append(big, wireEntry(1000+i, "note", `"`+strings.Repeat("x", 30<<10)+`"`))
	}
	w, body = f.do("POST", "/api/v1/sync", phone, syncBody(nil, big...))
	assert.Equal(t, http.StatusOK, w.Code, body)
}

func TestSyncNeedsAValidDevice(t *testing.T) {
	f := newFixture(t)
	w, body := f.do("POST", "/api/v1/sync", "", syncBody(nil))
	assert.Equal(t, http.StatusUnauthorized, w.Code)
	assert.Equal(t, CodeDeviceKeyMissing, body["code"])

	phoneID, phone := f.pair("Phone")
	_, laptop := f.pair("Laptop")
	f.now = f.now.Add(time.Minute)
	w, _ = f.do("DELETE", "/api/v1/devices/"+phoneID, laptop, nil)
	require.Equal(t, http.StatusNoContent, w.Code)
	w, body = f.do("POST", "/api/v1/sync", phone, syncBody(nil, wireEntry(1000, "note", `"a"`)))
	assert.Equal(t, http.StatusUnauthorized, w.Code)
	assert.Equal(t, CodeDeviceRevoked, body["code"])
	assert.Empty(t, f.everything(laptop), "nothing from a revoked device is kept")
}

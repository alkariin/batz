package web

import (
	"bytes"
	"encoding/json"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/alkariin/batz/batz-web/internal/application"
)

func (f *fixture) sendDocument(key string, file []byte) *httptest.ResponseRecorder {
	f.t.Helper()
	r := httptest.NewRequest("POST", "/api/v1/documents", bytes.NewReader(file))
	r.Header.Set("Content-Type", "application/octet-stream")
	if key != "" {
		r.Header.Set("Authorization", "Bearer "+key)
	}
	w := httptest.NewRecorder()
	f.handler.ServeHTTP(w, r)
	return w
}

func (f *fixture) readDocument(key, fingerprint string) *httptest.ResponseRecorder {
	f.t.Helper()
	r := httptest.NewRequest("GET", "/api/v1/documents/"+fingerprint, nil)
	if key != "" {
		r.Header.Set("Authorization", "Bearer "+key)
	}
	w := httptest.NewRecorder()
	f.handler.ServeHTTP(w, r)
	return w
}

// A document is kept under its fingerprint, given back to any device, and
// sent twice is kept once.
func TestADocumentIsKeptAndGivenBack(t *testing.T) {
	var logs bytes.Buffer
	previous := slog.Default()
	slog.SetDefault(slog.New(slog.NewTextHandler(&logs, nil)))
	t.Cleanup(func() { slog.SetDefault(previous) })

	f := newFixture(t)
	_, phone := f.pair("Phone")
	_, laptop := f.pair("Laptop")
	file := []byte("%PDF-1.7 a fictitious policy, Assurance Imaginaire SA")

	w := f.sendDocument(phone, file)
	require.Equal(t, http.StatusCreated, w.Code, w.Body.String())
	var body struct {
		Fingerprint string `json:"fingerprint"`
		Size        int    `json:"size"`
	}
	require.NoError(t, json.Unmarshal(w.Body.Bytes(), &body))
	assert.Equal(t, application.Fingerprint(file), body.Fingerprint)
	assert.Equal(t, len(file), body.Size)
	assert.Equal(t, http.StatusOK, f.sendDocument(laptop, file).Code, "already held: nothing new")
	entries, err := os.ReadDir(f.documentsDir)
	require.NoError(t, err)
	assert.Len(t, entries, 1)

	got := f.readDocument(laptop, body.Fingerprint)
	require.Equal(t, http.StatusOK, got.Code)
	assert.Equal(t, file, got.Body.Bytes())
	assert.NotContains(t, logs.String(), "Imaginaire", "the logs never hold a document")
}

func TestDocumentRefusals(t *testing.T) {
	f := newFixture(t)
	_, key := f.pair("Phone")
	assert.Equal(t, http.StatusUnauthorized, f.sendDocument("", []byte("x")).Code)
	assert.Equal(t, http.StatusUnauthorized, f.readDocument("", application.Fingerprint([]byte("x"))).Code)

	w := f.sendDocument(key, nil)
	assert.Equal(t, http.StatusBadRequest, w.Code)
	assert.Contains(t, w.Body.String(), `"code":"DOCUMENT_EMPTY"`)

	w = f.sendDocument(key, make([]byte, MaxDocumentBytes+1))
	assert.Equal(t, http.StatusRequestEntityTooLarge, w.Code)
	assert.Contains(t, w.Body.String(), `"code":"DOCUMENT_TOO_LARGE"`)

	for _, fp := range []string{application.Fingerprint([]byte("never sent")), "not-a-fingerprint", "..%2Fbatz.db"} {
		w = f.readDocument(key, fp)
		assert.Equal(t, http.StatusNotFound, w.Code, fp)
	}
	assert.Contains(t, f.readDocument(key, application.Fingerprint([]byte("never sent"))).Body.String(), `"code":"DOCUMENT_NOT_FOUND"`)
}

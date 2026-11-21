package web

import (
	"bytes"
	"encoding/json"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/alkariin/batz/batz-web/internal/application"
	"github.com/alkariin/batz/batz-web/internal/infrastructure/extraction/postfinance/fake"
)

func testdata(t *testing.T, name string) []byte {
	t.Helper()
	pdf, err := os.ReadFile(filepath.Join("..", "extraction", "postfinance", "testdata", name))
	require.NoError(t, err)
	return pdf
}

// send posts a statement file as the raw body, as the app does.
func (f *fixture) send(key string, pdf []byte) *httptest.ResponseRecorder {
	f.t.Helper()
	r := httptest.NewRequest("POST", "/api/v1/imports", bytes.NewReader(pdf))
	r.Header.Set("Content-Type", "application/pdf")
	if key != "" {
		r.Header.Set("Authorization", "Bearer "+key)
	}
	w := httptest.NewRecorder()
	f.handler.ServeHTTP(w, r)
	return w
}

func (f *fixture) backupCount() int {
	f.t.Helper()
	names, err := f.backups.List()
	require.NoError(f.t, err)
	return len(names)
}

func TestImportAStatement(t *testing.T) {
	f := newFixture(t)
	_, key := f.pair("Phone")
	pdf := testdata(t, "2026-01.pdf")

	w := f.send(key, pdf)
	require.Equal(t, http.StatusOK, w.Code, w.Body.String())
	var body struct {
		Fingerprint string          `json:"fingerprint"`
		Statement   json.RawMessage `json:"statement"`
	}
	require.NoError(t, json.Unmarshal(w.Body.Bytes(), &body))
	assert.Equal(t, application.Fingerprint(pdf), body.Fingerprint)
	var expected struct {
		Statement json.RawMessage `json:"statement"`
	}
	require.NoError(t, json.Unmarshal(testdata(t, "2026-01.json"), &expected))
	assert.JSONEq(t, string(expected.Statement), string(body.Statement))
	assert.Equal(t, 1, f.backupCount(), "a copy of the database before storing a new statement")

	// The same file again: the same answer, no new copy.
	again := f.send(key, pdf)
	require.Equal(t, http.StatusOK, again.Code)
	assert.Equal(t, w.Body.String(), again.Body.String())
	assert.Equal(t, 1, f.backupCount())

	// Another statement: a new copy.
	require.Equal(t, http.StatusOK, f.send(key, testdata(t, "2026-02.pdf")).Code)
	assert.Equal(t, 2, f.backupCount())
}

func TestTheServerKeeps12CopiesOfItsDatabase(t *testing.T) {
	f := newFixture(t)
	_, key := f.pair("Phone")
	jan := fake.Fixtures()[0].Statement
	for i := range 14 {
		// 14 distinct files: the same statement for 14 holders.
		jan.Holder = []string{"Holder " + string(rune('A'+i)), "Chemin des Essais 7", "9999 Fictiville"}
		require.Equal(t, http.StatusOK, f.send(key, jan.PDF()).Code)
	}
	assert.Equal(t, 12, f.backupCount())
}

func TestRefusedStatements(t *testing.T) {
	f := newFixture(t)
	_, key := f.pair("Phone")
	cases := map[string][3]string{
		"inconsistent-amount.pdf":  {"IMPORT_INCONSISTENT", "runningBalance"},
		"inconsistent-total.pdf":   {"IMPORT_INCONSISTENT", "totals"},
		"inconsistent-balance.pdf": {"IMPORT_INCONSISTENT", "closingBalance"},
		"not-a-statement.pdf":      {"IMPORT_UNKNOWN_FORMAT", ""},
	}
	for name, want := range cases {
		w := f.send(key, testdata(t, name))
		assert.Equal(t, http.StatusUnprocessableEntity, w.Code, name)
		var body ErrorBody
		require.NoError(t, json.Unmarshal(w.Body.Bytes(), &body))
		assert.Equal(t, want[0], body.Code, name)
		assert.Equal(t, want[1], body.Check, name)
		assert.NotEmpty(t, body.Message, name)
	}
	w := f.send(key, []byte("plain text, no PDF"))
	assert.Equal(t, http.StatusUnprocessableEntity, w.Code)
	assert.Contains(t, w.Body.String(), `"code":"IMPORT_UNREADABLE"`)
	assert.Equal(t, 0, f.backupCount(), "a refused statement is neither kept nor backed up")
}

func TestATooLargeFileIsRefused(t *testing.T) {
	f := newFixture(t)
	_, key := f.pair("Phone")
	w := f.send(key, append([]byte("%PDF-1.4\n"), make([]byte, MaxImportBytes)...))
	assert.Equal(t, http.StatusRequestEntityTooLarge, w.Code)
	assert.Contains(t, w.Body.String(), `"code":"IMPORT_TOO_LARGE"`)
}

func TestImportRoutesRequireADevice(t *testing.T) {
	f := newFixture(t)
	assert.Equal(t, http.StatusUnauthorized, f.send("", testdata(t, "2026-01.pdf")).Code)
	w, _ := f.do("GET", "/api/v1/imports/"+application.Fingerprint(nil)+"/pdf", "", nil)
	assert.Equal(t, http.StatusUnauthorized, w.Code)
}

func TestTheOriginalPDFIsFoundByItsFingerprint(t *testing.T) {
	f := newFixture(t)
	_, key := f.pair("Phone")
	pdf := testdata(t, "2026-03.pdf")
	require.Equal(t, http.StatusOK, f.send(key, pdf).Code)

	r := httptest.NewRequest("GET", "/api/v1/imports/"+application.Fingerprint(pdf)+"/pdf", nil)
	r.Header.Set("Authorization", "Bearer "+key)
	w := httptest.NewRecorder()
	f.handler.ServeHTTP(w, r)
	require.Equal(t, http.StatusOK, w.Code)
	assert.Equal(t, "application/pdf", w.Header().Get("Content-Type"))
	assert.Equal(t, pdf, w.Body.Bytes())

	// A file the server does not hold (never sent, or a rebuilt server).
	for _, fp := range []string{application.Fingerprint([]byte("other")), "not-a-fingerprint"} {
		w, body := f.do("GET", "/api/v1/imports/"+fp+"/pdf", key, nil)
		assert.Equal(t, http.StatusNotFound, w.Code, fp)
		assert.Equal(t, "IMPORT_PDF_NOT_FOUND", body["code"], fp)
	}
	w, _ = f.do("GET", "/api/v1/imports/..%2Fbatz.db/pdf", key, nil)
	assert.Equal(t, http.StatusNotFound, w.Code, "no way out of the directory")
}

func TestTheLogsHoldNoTextOfAStatement(t *testing.T) {
	var logs bytes.Buffer
	previous := slog.Default()
	slog.SetDefault(slog.New(slog.NewTextHandler(&logs, nil)))
	t.Cleanup(func() { slog.SetDefault(previous) })

	f := newFixture(t)
	_, key := f.pair("Phone")
	for _, name := range []string{"2026-01.pdf", "inconsistent-amount.pdf", "not-a-statement.pdf"} {
		f.send(key, testdata(t, name))
	}
	require.Contains(t, logs.String(), "import")
	for _, f := range fake.Fixtures() {
		if f.NotStatement {
			continue
		}
		for _, e := range f.Statement.Entries {
			for _, line := range e.Text {
				if len(line) > 6 {
					assert.NotContains(t, logs.String(), line)
				}
			}
		}
		for _, line := range f.Statement.Holder {
			assert.NotContains(t, logs.String(), line)
		}
		assert.NotContains(t, logs.String(), strings.ReplaceAll(f.Statement.IBAN, " ", ""))
	}
	assert.NotContains(t, logs.String(), "Facture")
}

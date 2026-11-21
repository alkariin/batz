package application

import (
	"context"
	"crypto/sha256"
	"encoding/hex"
	"errors"
	"fmt"
	"regexp"
	"sync"

	"github.com/alkariin/batz/batz-web/internal/domain/statement"
)

// StatementExtractor reads a statement file and checks its consistency; see
// postfinance.Extractor.
type StatementExtractor interface {
	Extract(ctx context.Context, pdf []byte) (statement.Statement, error)
}

// StatementFiles keeps the original PDF files, under their fingerprint.
type StatementFiles interface {
	Has(fingerprint string) (bool, error)
	// Save stores the file; when it returns, the file is complete.
	Save(fingerprint string, pdf []byte) error
	// Read returns ErrPDFNotFound when there is no such file.
	Read(fingerprint string) ([]byte, error)
}

// DatabaseBackups writes a dated copy of the server database and keeps the
// latest ones.
type DatabaseBackups interface {
	Backup(ctx context.Context) error
}

var (
	// ErrPDFNotFound means the server holds no original PDF with that
	// fingerprint: it was never sent, or the server was rebuilt.
	ErrPDFNotFound = errors.New("no original PDF with this fingerprint")

	fingerprintRe = regexp.MustCompile(`^[0-9a-f]{64}$`)
)

// Fingerprint identifies a file: the SHA-256 of its bytes, in lower-case hex.
func Fingerprint(file []byte) string {
	sum := sha256.Sum256(file)
	return hex.EncodeToString(sum[:])
}

// ValidFingerprint reports whether s has the form of a fingerprint.
func ValidFingerprint(s string) bool { return fingerprintRe.MatchString(s) }

// ImportResult is what the server answers for a statement it accepts.
type ImportResult struct {
	Fingerprint string
	Statement   statement.Statement
	// New is true when the server did not hold the file before: it wrote a
	// copy of its database, then stored the file.
	New bool
}

// Imports reads the statements the apps send (principle 1 of phase 3): the
// server extracts and checks, keeps the file, and answers with the lines. It
// writes nothing to the journal; the app does.
type Imports struct {
	extractor StatementExtractor
	files     StatementFiles
	backups   DatabaseBackups
	mu        sync.Mutex
}

// NewImports builds the service.
func NewImports(extractor StatementExtractor, files StatementFiles, backups DatabaseBackups) *Imports {
	return &Imports{extractor: extractor, files: files, backups: backups}
}

// Import extracts and checks pdf. A refused statement returns the error of
// the extraction (statement.Refusal tells its code) and nothing is kept. An
// accepted one the server did not hold yet is kept under its fingerprint,
// after a copy of the database (principle 5); sending the same file again
// gives the same answer and writes nothing.
func (i *Imports) Import(ctx context.Context, pdf []byte) (ImportResult, error) {
	fingerprint := Fingerprint(pdf)
	st, err := i.extractor.Extract(ctx, pdf)
	if err != nil {
		return ImportResult{}, err
	}
	// One import at a time: two copies of the same file sent together give
	// one backup and one file.
	i.mu.Lock()
	defer i.mu.Unlock()
	known, err := i.files.Has(fingerprint)
	if err != nil {
		return ImportResult{}, fmt.Errorf("look for the statement file: %w", err)
	}
	if !known {
		if err := i.backups.Backup(ctx); err != nil {
			return ImportResult{}, fmt.Errorf("back up the database: %w", err)
		}
		if err := i.files.Save(fingerprint, pdf); err != nil {
			return ImportResult{}, fmt.Errorf("store the statement file: %w", err)
		}
	}
	return ImportResult{Fingerprint: fingerprint, Statement: st, New: !known}, nil
}

// PDF returns the original file of the statement with that fingerprint, or
// ErrPDFNotFound.
func (i *Imports) PDF(ctx context.Context, fingerprint string) ([]byte, error) {
	if !ValidFingerprint(fingerprint) {
		return nil, ErrPDFNotFound
	}
	return i.files.Read(fingerprint)
}

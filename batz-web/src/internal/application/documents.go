package application

import (
	"context"
	"errors"
	"fmt"
	"sync"
)

// DocumentFiles keeps the documents the apps send, under their fingerprint.
type DocumentFiles interface {
	Has(fingerprint string) (bool, error)
	// Save stores the file; when it returns, the file is complete.
	Save(fingerprint string, file []byte) error
	// Read returns ErrDocumentNotFound when there is no such file.
	Read(fingerprint string) ([]byte, error)
}

var (
	// ErrDocumentNotFound means the server holds no document with that
	// fingerprint: it was never sent, or the server was rebuilt.
	ErrDocumentNotFound = errors.New("no document with this fingerprint")
	// ErrDocumentEmpty refuses a document of no byte.
	ErrDocumentEmpty = errors.New("the document is empty")
)

// Documents keeps the files the apps attach to their records (the documents
// of an insurance): the server stores each one under its fingerprint and
// gives it back. It knows nothing of what it is attached to: the journal
// says that, and a document deleted there stays here.
type Documents struct {
	files DocumentFiles
	mu    sync.Mutex
}

// NewDocuments builds the service.
func NewDocuments(files DocumentFiles) *Documents { return &Documents{files: files} }

// Store keeps file under its fingerprint and returns it; sending the same
// file again writes nothing. isNew tells whether the server did not hold it.
func (d *Documents) Store(_ context.Context, file []byte) (fingerprint string, isNew bool, err error) {
	if len(file) == 0 {
		return "", false, ErrDocumentEmpty
	}
	fingerprint = Fingerprint(file)
	d.mu.Lock()
	defer d.mu.Unlock()
	known, err := d.files.Has(fingerprint)
	if err != nil {
		return "", false, fmt.Errorf("look for the document: %w", err)
	}
	if !known {
		if err := d.files.Save(fingerprint, file); err != nil {
			return "", false, fmt.Errorf("store the document: %w", err)
		}
	}
	return fingerprint, !known, nil
}

// Read returns the document with that fingerprint, or ErrDocumentNotFound.
func (d *Documents) Read(_ context.Context, fingerprint string) ([]byte, error) {
	if !ValidFingerprint(fingerprint) {
		return nil, ErrDocumentNotFound
	}
	return d.files.Read(fingerprint)
}

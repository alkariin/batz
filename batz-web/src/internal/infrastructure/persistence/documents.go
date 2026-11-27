package persistence

import (
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"

	"github.com/alkariin/batz/batz-web/internal/application"
)

// DocumentFiles keeps the documents of the apps in a directory, each named
// by its fingerprint.
type DocumentFiles struct{ dir string }

// NewDocumentFiles uses dir, created on the first file.
func NewDocumentFiles(dir string) *DocumentFiles { return &DocumentFiles{dir: dir} }

func (d *DocumentFiles) path(fingerprint string) (string, error) {
	if !application.ValidFingerprint(fingerprint) {
		return "", fmt.Errorf("invalid fingerprint %q", fingerprint)
	}
	return filepath.Join(d.dir, fingerprint), nil
}

func (d *DocumentFiles) Has(fingerprint string) (bool, error) {
	path, err := d.path(fingerprint)
	if err != nil {
		return false, err
	}
	_, err = os.Stat(path)
	if errors.Is(err, fs.ErrNotExist) {
		return false, nil
	}
	return err == nil, err
}

func (d *DocumentFiles) Save(fingerprint string, file []byte) error {
	path, err := d.path(fingerprint)
	if err != nil {
		return err
	}
	return writeAtomically(d.dir, path, file)
}

func (d *DocumentFiles) Read(fingerprint string) ([]byte, error) {
	path, err := d.path(fingerprint)
	if err != nil {
		return nil, application.ErrDocumentNotFound
	}
	file, err := os.ReadFile(path)
	if errors.Is(err, fs.ErrNotExist) {
		return nil, application.ErrDocumentNotFound
	}
	return file, err
}

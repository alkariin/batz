package persistence

import (
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"

	"github.com/alkariin/batz/batz-web/internal/application"
)

// StatementFiles keeps the original PDF files in a directory, each named by
// its fingerprint.
type StatementFiles struct{ dir string }

// NewStatementFiles uses dir, created on the first file.
func NewStatementFiles(dir string) *StatementFiles { return &StatementFiles{dir: dir} }

func (s *StatementFiles) path(fingerprint string) (string, error) {
	if !application.ValidFingerprint(fingerprint) {
		return "", fmt.Errorf("invalid fingerprint %q", fingerprint)
	}
	return filepath.Join(s.dir, fingerprint+".pdf"), nil
}

func (s *StatementFiles) Has(fingerprint string) (bool, error) {
	path, err := s.path(fingerprint)
	if err != nil {
		return false, err
	}
	_, err = os.Stat(path)
	if errors.Is(err, fs.ErrNotExist) {
		return false, nil
	}
	return err == nil, err
}

// Save writes the file under a temporary name, then renames it: a file
// present under its fingerprint is always complete.
func (s *StatementFiles) Save(fingerprint string, pdf []byte) error {
	path, err := s.path(fingerprint)
	if err != nil {
		return err
	}
	if err := os.MkdirAll(s.dir, 0o700); err != nil {
		return err
	}
	tmp, err := os.CreateTemp(s.dir, ".incoming-*")
	if err != nil {
		return err
	}
	defer os.Remove(tmp.Name()) //nolint:errcheck // gone after the rename
	if _, err := tmp.Write(pdf); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Sync(); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	return os.Rename(tmp.Name(), path)
}

func (s *StatementFiles) Read(fingerprint string) ([]byte, error) {
	path, err := s.path(fingerprint)
	if err != nil {
		return nil, application.ErrPDFNotFound
	}
	pdf, err := os.ReadFile(path)
	if errors.Is(err, fs.ErrNotExist) {
		return nil, application.ErrPDFNotFound
	}
	return pdf, err
}

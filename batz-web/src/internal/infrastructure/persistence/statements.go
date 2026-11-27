package persistence

import (
	"bytes"
	"errors"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"

	"github.com/alkariin/batz/batz-web/internal/application"
)

// StatementFiles keeps the original files in a directory, each named by its
// fingerprint: `.pdf` for a PDF statement, `.csv` for an export.
type StatementFiles struct{ dir string }

// NewStatementFiles uses dir, created on the first file.
func NewStatementFiles(dir string) *StatementFiles { return &StatementFiles{dir: dir} }

var extensions = []string{".pdf", ".csv"}

func (s *StatementFiles) path(fingerprint, extension string) (string, error) {
	if !application.ValidFingerprint(fingerprint) {
		return "", fmt.Errorf("invalid fingerprint %q", fingerprint)
	}
	return filepath.Join(s.dir, fingerprint+extension), nil
}

func extensionOf(file []byte) string {
	if bytes.HasPrefix(file, []byte("%PDF-")) {
		return ".pdf"
	}
	return ".csv"
}

func (s *StatementFiles) Has(fingerprint string) (bool, error) {
	for _, extension := range extensions {
		path, err := s.path(fingerprint, extension)
		if err != nil {
			return false, err
		}
		_, err = os.Stat(path)
		if errors.Is(err, fs.ErrNotExist) {
			continue
		}
		return err == nil, err
	}
	return false, nil
}

// Save writes the file under a temporary name, then renames it: a file
// present under its fingerprint is always complete.
func (s *StatementFiles) Save(fingerprint string, file []byte) error {
	path, err := s.path(fingerprint, extensionOf(file))
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
	if _, err := tmp.Write(file); err != nil {
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
	for _, extension := range extensions {
		path, err := s.path(fingerprint, extension)
		if err != nil {
			return nil, application.ErrPDFNotFound
		}
		file, err := os.ReadFile(path)
		if errors.Is(err, fs.ErrNotExist) {
			continue
		}
		return file, err
	}
	return nil, application.ErrPDFNotFound
}

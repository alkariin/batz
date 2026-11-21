package application

import (
	"context"
	"errors"
	"sync"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/alkariin/batz/batz-web/internal/domain/statement"
)

// events records, in order, what the fakes were asked to do.
type events struct {
	mu  sync.Mutex
	log []string
}

func (e *events) add(s string) { e.mu.Lock(); e.log = append(e.log, s); e.mu.Unlock() }

type fakeExtractor struct{ err error }

func (f fakeExtractor) Extract(_ context.Context, pdf []byte) (statement.Statement, error) {
	if f.err != nil {
		return statement.Statement{}, f.err
	}
	return statement.Statement{Format: "postfinance", IBAN: string(pdf)}, nil
}

type memoryFiles struct {
	ev    *events
	files map[string][]byte
}

func (m *memoryFiles) Has(fp string) (bool, error) { _, ok := m.files[fp]; return ok, nil }
func (m *memoryFiles) Save(fp string, pdf []byte) error {
	m.ev.add("save")
	m.files[fp] = pdf
	return nil
}
func (m *memoryFiles) Read(fp string) ([]byte, error) {
	if pdf, ok := m.files[fp]; ok {
		return pdf, nil
	}
	return nil, ErrPDFNotFound
}

type fakeBackups struct {
	ev  *events
	err error
}

func (b fakeBackups) Backup(context.Context) error {
	if b.err != nil {
		return b.err
	}
	b.ev.add("backup")
	return nil
}

func newImports(extractErr, backupErr error) (*Imports, *events, *memoryFiles) {
	ev := &events{}
	files := &memoryFiles{ev: ev, files: map[string][]byte{}}
	return NewImports(fakeExtractor{extractErr}, files, fakeBackups{ev, backupErr}), ev, files
}

func TestANewStatementIsKeptAfterABackup(t *testing.T) {
	imports, ev, files := newImports(nil, nil)
	res, err := imports.Import(context.Background(), []byte("statement A"))
	require.NoError(t, err)
	assert.True(t, res.New)
	assert.Equal(t, Fingerprint([]byte("statement A")), res.Fingerprint)
	assert.Equal(t, []string{"backup", "save"}, ev.log, "the copy of the database comes first")
	assert.Equal(t, []byte("statement A"), files.files[res.Fingerprint])
}

func TestTheSameFileTwiceGivesTheSameAnswerAndNoBackup(t *testing.T) {
	imports, ev, _ := newImports(nil, nil)
	first, err := imports.Import(context.Background(), []byte("statement A"))
	require.NoError(t, err)
	second, err := imports.Import(context.Background(), []byte("statement A"))
	require.NoError(t, err)
	assert.Equal(t, first.Statement, second.Statement)
	assert.Equal(t, first.Fingerprint, second.Fingerprint)
	assert.False(t, second.New)
	assert.Equal(t, []string{"backup", "save"}, ev.log)
}

func TestConcurrentCopiesOfAFileGiveOneBackup(t *testing.T) {
	imports, ev, _ := newImports(nil, nil)
	var wg sync.WaitGroup
	for range 8 {
		wg.Add(1)
		go func() {
			defer wg.Done()
			_, err := imports.Import(context.Background(), []byte("statement A"))
			assert.NoError(t, err)
		}()
	}
	wg.Wait()
	assert.Equal(t, []string{"backup", "save"}, ev.log)
}

func TestARefusedStatementIsNotKept(t *testing.T) {
	refusal := &statement.InconsistentError{Check: statement.CheckTotals}
	imports, ev, files := newImports(refusal, nil)
	_, err := imports.Import(context.Background(), []byte("statement A"))
	assert.ErrorIs(t, err, refusal)
	assert.Empty(t, ev.log)
	assert.Empty(t, files.files)
}

func TestNoFileIsKeptWithoutItsBackup(t *testing.T) {
	imports, _, files := newImports(nil, errors.New("disk full"))
	_, err := imports.Import(context.Background(), []byte("statement A"))
	assert.Error(t, err)
	assert.Empty(t, files.files)
}

func TestThePDFIsFoundByItsFingerprint(t *testing.T) {
	imports, _, _ := newImports(nil, nil)
	res, err := imports.Import(context.Background(), []byte("statement A"))
	require.NoError(t, err)
	pdf, err := imports.PDF(context.Background(), res.Fingerprint)
	require.NoError(t, err)
	assert.Equal(t, []byte("statement A"), pdf)

	_, err = imports.PDF(context.Background(), Fingerprint([]byte("never sent")))
	assert.ErrorIs(t, err, ErrPDFNotFound)
	for _, bad := range []string{"", "../batz.db", "ABCDEF", Fingerprint(nil) + "0"} {
		_, err = imports.PDF(context.Background(), bad)
		assert.ErrorIs(t, err, ErrPDFNotFound, bad)
	}
}

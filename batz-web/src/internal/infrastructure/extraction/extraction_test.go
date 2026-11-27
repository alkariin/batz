package extraction

import (
	"context"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/alkariin/batz/batz-web/internal/domain/statement"
)

func TestEachFileGoesToTheModuleOfItsFormat(t *testing.T) {
	x := New()
	assert.Equal(t, []string{"postfinance", "neon"}, x.Formats())
	for name, format := range map[string]string{
		"postfinance/testdata/2026-01.pdf": "postfinance",
		"neon/testdata/2026-export.csv":    "neon",
	} {
		file, err := os.ReadFile(filepath.FromSlash(name))
		require.NoError(t, err)
		st, err := x.Extract(context.Background(), file)
		require.NoError(t, err, name)
		assert.Equal(t, format, st.Format, name)
	}
	_, err := x.Extract(context.Background(), []byte("neither a PDF nor an export"))
	assert.ErrorIs(t, err, statement.ErrUnknownFormat)
}

package neon

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/alkariin/batz/batz-web/internal/domain/statement"
)

func read(t *testing.T, name string) []byte {
	t.Helper()
	data, err := os.ReadFile(filepath.Join("testdata", name))
	require.NoError(t, err)
	return data
}

const head = `"Date";"Amount";"Original amount";"Original currency";"Exchange rate";"Description";"Subject";"Category";"Tags";"Wise";"Spaces"` + "\n"

func TestAnExportIsReadOldestFirst(t *testing.T) {
	data := read(t, "2026-export.csv")
	require.True(t, Detect(data))
	st, err := New().Extract(context.Background(), data)
	require.NoError(t, err)
	assert.Equal(t, Format, st.Format)
	assert.Equal(t, "CHF", st.Currency)
	assert.Empty(t, st.IBAN)
	assert.Nil(t, st.OpeningBalance, "an export prints no balance")
	assert.Nil(t, st.TotalCredits)
	assert.Equal(t, "2026-01-05", st.PeriodStart.String())
	assert.Equal(t, "2026-03-14", st.PeriodEnd.String())
	var amounts []int64
	var texts []string
	for _, l := range st.Lines {
		amounts = append(amounts, l.Amount)
		texts = append(texts, l.RawText)
	}
	assert.Equal(t, []int64{-2390, -4500, 50000, -850, -850, -1240}, amounts)
	assert.Equal(t, []string{
		"Kiosque du Port\n-180.00 DKK",
		"Boulangerie Fictive",
		"Titulaire Fictif\nVersement depuis PostFinance",
		"Musée Imaginaire\n-9.00 EUR",
		"Musée Imaginaire\n-9.00 EUR",
		"Café des Essais",
	}, texts, "the description, the subject, the original amount; never the rate nor Neon's category")
	assert.Equal(t, "Titulaire Fictif", st.Lines[2].Label)
	for _, l := range st.Lines {
		assert.Nil(t, l.Balance)
	}
}

func TestFieldsAndAmounts(t *testing.T) {
	data := []byte("\xef\xbb\xbf" + head +
		`"2026-04-02";"7";"";"CHF";"";"";"Only a subject";"";"";"no";"no"` + "\r\n" +
		`"2026-04-01";"-1.5";"-1.50";"CHF";"1";"  Two   spaces` + "\n" + `and a break ";;"";"";"no";"no"` + "\r\n")
	st, err := Parse(data)
	require.NoError(t, err)
	require.Len(t, st.Lines, 2)
	assert.Equal(t, statement.Line{Date: st.Lines[0].Date, Amount: -150, RawText: "Two spaces and a break", Label: "Two spaces and a break"}, st.Lines[0], "a payment in francs has no original amount")
	assert.Equal(t, int64(700), st.Lines[1].Amount)
	assert.Equal(t, "Only a subject", st.Lines[1].RawText)
}

func TestRefusals(t *testing.T) {
	for name, data := range map[string]string{
		"no header":            `"2026-04-01";"-1.00"` + "\n",
		"a missing column":     `"Date";"Amount";"Description"` + "\n",
		"empty":                "",
		"some other CSV":       "a,b,c\n1,2,3\n",
		"a PDF, not an export": "%PDF-1.4\n",
	} {
		assert.False(t, Detect([]byte(data)), name)
		_, err := New().Extract(context.Background(), []byte(data))
		assert.True(t, errors.Is(err, statement.ErrUnknownFormat), name)
	}
	for name, line := range map[string]string{
		"date":     `"01.04.2026";"-1.00";"";"";"";"Shop";"";"";"";"no";"no"`,
		"amount":   `"2026-04-01";"-1,00";"";"";"";"Shop";"";"";"";"no";"no"`,
		"cents":    `"2026-04-01";"-1.005";"";"";"";"Shop";"";"";"";"no";"no"`,
		"label":    `"2026-04-01";"-1.00";"";"";"";"";"";"";"";"no";"no"`,
		"fields":   `"2026-04-01";"-1.00";"Shop"`,
		"no lines": ``,
	} {
		_, err := New().Extract(context.Background(), []byte(head+line+"\n"))
		var inc *statement.InconsistentError
		require.ErrorAs(t, err, &inc, name)
		assert.Equal(t, statement.CheckLayout, inc.Check, name)
		assert.NotContains(t, inc.Detail, "Shop", "errors never quote the export")
	}
}

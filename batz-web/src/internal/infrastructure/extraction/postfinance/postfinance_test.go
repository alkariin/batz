package postfinance

import (
	"context"
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"

	"github.com/alkariin/batz/batz-web/internal/domain/statement"
	"github.com/alkariin/batz/batz-web/internal/infrastructure/extraction/postfinance/fake"
)

// Every fictitious statement gives exactly what its generator printed:
// dates, amounts, texts without the page furniture, short labels, the
// balances printed in its course, or the refusal with the check in cause.
func TestFixtures(t *testing.T) {
	for _, f := range fake.Fixtures() {
		t.Run(f.Name, func(t *testing.T) {
			pdf, err := os.ReadFile(filepath.Join("testdata", f.Name+".pdf"))
			require.NoError(t, err)
			st, err := New().Extract(context.Background(), pdf)
			want := f.Expected()
			if !want.Accepted {
				code, check, ok := statement.Refusal(err)
				require.True(t, ok, "refused: %v", err)
				assert.Equal(t, want.Code, code)
				assert.Equal(t, want.Check, check)
				return
			}
			require.NoError(t, err)
			assert.Equal(t, *want.Statement, st)
		})
	}
}

// The balance computed after each movement is the one printed, wherever the
// statement prints one, and the last one is the closing balance.
func TestComputedBalancesAreThePrintedOnes(t *testing.T) {
	for _, name := range []string{"2026-01", "2026-02", "2026-03"} {
		pdf, err := os.ReadFile(filepath.Join("testdata", name+".pdf"))
		require.NoError(t, err)
		st, err := New().Extract(context.Background(), pdf)
		require.NoError(t, err)
		balance, printed := st.OpeningBalance, 0
		for _, l := range st.Lines {
			balance += l.Amount
			if l.Balance != nil {
				printed++
				assert.Equal(t, *l.Balance, balance, name)
			}
		}
		assert.Equal(t, st.ClosingBalance, balance, name)
		assert.Greater(t, printed, 5, name)
	}
}

func TestUnreadableFiles(t *testing.T) {
	for name, content := range map[string][]byte{
		"empty":           nil,
		"text":            []byte("Date Texte Crédit Débit Valeur Solde"),
		"broken PDF":      []byte("%PDF-1.4\nnothing else"),
		"image signature": {0x89, 'P', 'N', 'G', '\r', '\n', 0x1a, '\n'},
	} {
		_, err := New().Extract(context.Background(), content)
		assert.ErrorIs(t, err, statement.ErrUnreadable, name)
	}
}

func TestPdftotextIsBoundInTime(t *testing.T) {
	script := filepath.Join(t.TempDir(), "slow")
	require.NoError(t, os.WriteFile(script, []byte("#!/bin/sh\nexec sleep 10\n"), 0o755))
	x := &Extractor{Command: script, Timeout: 100 * time.Millisecond}
	start := time.Now()
	_, err := x.Extract(context.Background(), []byte("%PDF-1.4\n"))
	assert.ErrorIs(t, err, statement.ErrUnreadable)
	assert.Less(t, time.Since(start), 5*time.Second)
}

func TestAMissingPdftotextIsAnInternalFailure(t *testing.T) {
	x := &Extractor{Command: filepath.Join(t.TempDir(), "absent"), Timeout: time.Second}
	assert.Error(t, x.Available())
	_, err := x.Extract(context.Background(), []byte("%PDF-1.4\n"))
	require.Error(t, err)
	_, _, refusal := statement.Refusal(err)
	assert.False(t, refusal, "not the file's fault: %v", err)
}

// --- Parse, on texts laid out by hand -----------------------------------

// row places each string so that it ends at its column (or starts there for
// a negative column).
func row(parts ...any) string {
	var b []rune
	for i := 0; i+1 < len(parts); i += 2 {
		col, s := parts[i].(int), []rune(parts[i+1].(string))
		start := col - len(s)
		if col < 0 {
			start = -col
		}
		for len(b) < start+len(s) {
			b = append(b, ' ')
		}
		copy(b[start:], s)
	}
	return string(b)
}

// Columns of the hand-made pages: text from 20, « Crédit » ends at 70,
// « Débit » at 85, value dates end at 96, balances at 110.
const (
	cText   = -20
	cCredit = 70
	cDebit  = 85
	cValue  = 96
	cSolde  = 110
)

func header() string {
	return row(-3, "Date", cText, "Texte", cCredit, "Crédit", cDebit, "Débit", cValue, "Valeur", cSolde, "Solde")
}

// statementText is a statement of the 2025 layout: the period and the IBAN
// with its currency on the first page, page furniture repeated on the next.
func statementText(body ...string) string {
	lines := []string{
		row(-3, "Compte privé"),
		row(-3, "Extrait de compte 01.03.2026 - 31.03.2026", 100, "Date:   01.04.2026"),
		row(-50, "Camille Exemple", -70, "IBAN CH00 9000 0000 1234 5678 9   CHF"),
		row(-70, "Numéro de compte 00-123456-7"),
		row(-70, "BIC POFICHBEXXX"),
		"",
		header(),
		"",
		row(-3, "01.03.26", cText, "Etat de compte", cSolde, "1 000.00"),
	}
	return strings.Join(append(lines, body...), "\n")
}

func TestParseThe2025Layout(t *testing.T) {
	text := statementText(
		row(-3, "02.03.26", cText, "ACHAT/SERVICE DU 01.03.2026", cDebit, "50.00", cValue, "02.03.26"),
		row(cText, "CARTE NO XXXX0000"),
		row(cText, "Commerce A"),
		row(cText, "ACHAT/SERVICE DU 01.03.2026", cDebit, "100.00", cValue, "02.03.26", cSolde, "850.00"),
		row(cText, "CARTE NO XXXX0000"),
		row(cText, "Commerce B"),
		"12345 FR 000000.00",
		"\f"+row(-3, "Extrait de compte 01.03.2026 - 31.03.2026"),
		row(-3, "IBAN CH00 9000 0000 1234 5678 9"),
		row(-3, "Numéro de compte 00-123456-7", 80, "Date:   01.04.2026", 105, "Page 2 / 2"),
		header(),
		// The day goes on over the page, without its date.
		row(cText, "ACHAT/SERVICE DU 01.03.2026", cDebit, "1 234.50", cValue, "02.03.26", cSolde, "-384.50"),
		row(cText, "CARTE NO XXXX0000"),
		row(cText, "Commerce C"),
		row(-3, "25.03.26", cText, "CRÉDIT", cCredit, "1 434.50", cValue, "25.03.26", cSolde, "1 050.00"),
		row(cText, "DONNEUR D'ORDRE:"),
		row(cText, "Employeur Fictif SA"),
		row(cText, "Total", cCredit, "1 434.50", cDebit, "1 384.50"),
		row(-3, "31.03.26", cText, "Etat de compte", cSolde, "1 050.00"),
		row(cText, "Notes after the closing balance are ignored  12.00  31.03.26"),
	)
	st, err := Parse(text)
	require.NoError(t, err)
	require.NoError(t, st.Check())
	assert.Equal(t, "CH0090000000123456789", st.IBAN)
	assert.Equal(t, "CHF", st.Currency)
	assert.Equal(t, "2026-03-01", st.PeriodStart.String())
	assert.Equal(t, "2026-03-31", st.PeriodEnd.String())
	assert.Equal(t, []int64{100000, 105000, 143450, 138450}, []int64{st.OpeningBalance, st.ClosingBalance, st.TotalCredits, st.TotalDebits})
	require.Len(t, st.Lines, 4)
	assert.Equal(t, []int64{-5000, -10000, -123450, 143450}, []int64{st.Lines[0].Amount, st.Lines[1].Amount, st.Lines[2].Amount, st.Lines[3].Amount})
	assert.Equal(t, "2026-03-02", st.Lines[2].Date.String(), "the day goes on over the page")
	assert.Equal(t, "ACHAT/SERVICE DU 01.03.2026\nCARTE NO XXXX0000\nCommerce B", st.Lines[1].RawText,
		"the form code and the furniture of the next page are not part of the text")
	assert.Equal(t, "Commerce B", st.Lines[1].Label)
	assert.Equal(t, "Employeur Fictif SA", st.Lines[3].Label)
	assert.Nil(t, st.Lines[0].Balance)
	assert.Equal(t, int64(85000), *st.Lines[1].Balance)
}

func TestParseAnAmountSeparatedFromItsLabel(t *testing.T) {
	text := statementText(
		row(-3, "02.03.26", cText, "ACHAT/SERVICE DU 01.03.2026", cDebit, "50.00", cValue, "02.03.26"),
		row(cText, "CARTE NO XXXX0000"),
		row(cText, "Commerce A"),
		row(cText, "ENVOI D'ARGENT TWINT DU 02.03.2026"),
		"12345 FR 000000.00",
		// The amount of the label above, with the date of a new day.
		row(-3, "03.03.26", cDebit, "25.00", cValue, "03.03.26", cSolde, "925.00"),
		row(cText, "POUR Dominique Essai."),
		row(cText, "ACHAT/SERVICE DU 03.03.2026"),
		"Page 1 / 2",
		// Then without a date.
		row(cDebit, "15.00", cValue, "03.03.26", cSolde, "910.00"),
		row(cText, "CARTE NO XXXX0000"),
		row(cText, "Commerce B"),
		row(cText, "Total", cDebit, "90.00"),
		row(-3, "31.03.26", cText, "Etat de compte", cSolde, "910.00"),
	)
	st, err := Parse(text)
	require.NoError(t, err)
	require.NoError(t, st.Check())
	require.Len(t, st.Lines, 3)
	assert.Equal(t, "ACHAT/SERVICE DU 01.03.2026\nCARTE NO XXXX0000\nCommerce A", st.Lines[0].RawText)
	assert.Equal(t, "ENVOI D'ARGENT TWINT DU 02.03.2026\nPOUR Dominique Essai.", st.Lines[1].RawText)
	assert.Equal(t, "2026-03-03", st.Lines[1].Date.String())
	assert.Equal(t, "ACHAT/SERVICE DU 03.03.2026\nCARTE NO XXXX0000\nCommerce B", st.Lines[2].RawText)
	assert.Equal(t, "2026-03-03", st.Lines[2].Date.String())
}

func TestParseAmounts(t *testing.T) {
	for raw, want := range map[string]int64{
		"0.05": 5, "12.50": 1250, "1 234.50": 123450, "1 234.50": 123450, "1 234.50": 123450,
		"1'234'567.89": 123456789, "-384.50": -38450,
	} {
		got, err := cents(raw)
		require.NoError(t, err, raw)
		assert.Equal(t, want, got, raw)
	}
	_, err := cents("12.5")
	assert.Error(t, err)
}

func layoutError(t *testing.T, err error) string {
	t.Helper()
	var inc *statement.InconsistentError
	require.ErrorAs(t, err, &inc)
	assert.Equal(t, statement.CheckLayout, inc.Check)
	return inc.Detail
}

func TestParseRefusesWhatItCannotReadEntirely(t *testing.T) {
	movement := row(-3, "02.03.26", cText, "DÉBIT", cDebit, "50.00", cValue, "02.03.26", cSolde, "950.00")
	end := []string{row(cText, "Total", cDebit, "50.00"), row(-3, "31.03.26", cText, "Etat de compte", cSolde, "950.00")}

	_, err := Parse(statementText(append([]string{movement}, end[1:]...)...))
	assert.Contains(t, layoutError(t, err), "totals")

	_, err = Parse(statementText(movement, end[0]))
	assert.Contains(t, layoutError(t, err), "closing balance")

	noDate := row(cText, "DÉBIT", cDebit, "50.00", cValue, "02.03.26")
	_, err = Parse(statementText(append([]string{noDate}, end...)...))
	assert.Contains(t, layoutError(t, err), "no date")

	alone := row(-3, "02.03.26", cDebit, "50.00", cValue, "02.03.26")
	_, err = Parse(statementText(append([]string{alone}, end...)...))
	assert.Contains(t, layoutError(t, err), "without a label")

	other := row(-3, "IBAN CH00 9000 0000 9876 5432 1")
	_, err = Parse(statementText(append([]string{movement, other}, end...)...))
	assert.Contains(t, layoutError(t, err), "two different IBANs")

	withoutOpening := strings.Replace(statementText(append([]string{movement}, end...)...), "Etat de compte", "Solde initial", 1)
	_, err = Parse(withoutOpening)
	assert.Contains(t, layoutError(t, err), "before the opening balance")
}

func TestParseTellsAStatementFromAnotherDocument(t *testing.T) {
	_, err := Parse("Facture n° 42\nTotal CHF 120.00\n")
	assert.True(t, errors.Is(err, statement.ErrUnknownFormat))

	// A statement whose table is missing is one, badly read.
	_, err = Parse(row(-3, "Extrait de compte 01.03.2026 - 31.03.2026") + "\n" + row(-3, "IBAN CH00 9000 0000 1234 5678 9 CHF"))
	assert.Contains(t, layoutError(t, err), "table")
}

func TestTheCurrencyIsChecked(t *testing.T) {
	text := strings.Replace(statementText(
		row(cText, "Total"),
		row(-3, "31.03.26", cText, "Etat de compte", cSolde, "1 000.00"),
	), "   CHF", "   EUR", 1)
	st, err := Parse(text)
	require.NoError(t, err)
	var inc *statement.InconsistentError
	require.ErrorAs(t, st.Check(), &inc)
	assert.Equal(t, statement.CheckCurrency, inc.Check)
}

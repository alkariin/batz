package postfinance

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestLabel(t *testing.T) {
	for name, c := range map[string]struct {
		lines []string
		want  string
	}{
		"card purchase":        {[]string{"ACHAT/SERVICE DU 05.01.2026", "CARTE NO XXXX0000", "Épicerie du Coin", "Fictiville"}, "Épicerie du Coin Fictiville"},
		"online, card N°":      {[]string{"ACHAT/SHOPPING EN LIGNE DU", "03.01.2026", "CARTE N° XXXX0000", "Librairie SA", "Exempleville (CH)"}, "Librairie SA Exempleville (CH)"},
		"TWINT payment":        {[]string{"ACHAT/PRESTATION TWINT DU", "06.01.2026", "Café de la Démo", "Fictiville"}, "Café de la Démo Fictiville"},
		"TWINT sent":           {[]string{"ENVOI D'ARGENT TWINT DU 09.01.2026", "POUR Dominique Essai.", "+41000000001", ", Repas"}, "POUR Dominique Essai. +41000000001 , Repas"},
		"TWINT received":       {[]string{"RÉCEPTION D'ARGENT TWINT DU", "13.01.2026", "DE Alex Modèle", "+41000000002"}, "DE Alex Modèle +41000000002"},
		"debit with IBAN":      {[]string{"DÉBIT", "CH0000000000000000001", "Gérance Imaginaire SA", "Rue du Bail 3"}, "Gérance Imaginaire SA Rue du Bail 3"},
		"credit with ordering": {[]string{"CRÉDIT", "DONNEUR D'ORDRE:", "Employeur Fictif SA"}, "Employeur Fictif SA"},
		"card refund":          {[]string{"CRÉDIT POSTFINANCE CARD", "DU 18.01.2026", "CARTE NO XXXX0000", "Grand Magasin"}, "Grand Magasin"},
		"fee":                  {[]string{"PRIX POUR", "TENUE DE COMPTE 12.2025"}, "TENUE DE COMPTE 12.2025"},
		"unknown operation":    {[]string{"BONIFICATION INTÉRÊTS", "CARTE NO XXXX0000", "2025"}, "BONIFICATION INTÉRÊTS CARTE NO XXXX0000 2025"},
		"nothing but generic":  {[]string{"ACHAT/SERVICE DU 05.01.2026", "CARTE NO XXXX0000"}, "ACHAT/SERVICE DU 05.01.2026 CARTE NO XXXX0000"},
		"a date further down":  {[]string{"ACHAT/PRESTATION TWINT DU", "Kiosque", "06.01.2026"}, "Kiosque 06.01.2026"},
		"spaces collapsed":     {[]string{"DÉBIT", "Assurance   Fictive"}, "Assurance Fictive"},
		"one line":             {[]string{"Ligne unique"}, "Ligne unique"},
	} {
		assert.Equal(t, c.want, Label(c.lines), name)
	}
}

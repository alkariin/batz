// Package tlscert creates the server's self-signed certificate on first start
// and loads it afterwards. Apps trust it by pinning its fingerprint, so the
// certificate never needs a domain name or a certificate authority.
package tlscert

import (
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/sha256"
	"crypto/tls"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/pem"
	"errors"
	"fmt"
	"io/fs"
	"math/big"
	"net"
	"os"
	"path/filepath"
	"strings"
	"time"
)

// ValidityYears is how long a new certificate is valid.
const ValidityYears = 10

const (
	dirName  = "tls"
	certFile = "server.crt"
	keyFile  = "server.key"
)

// LoadOrCreate returns the certificate stored under dataDir/tls, creating it
// at now if it does not exist yet.
func LoadOrCreate(dataDir string, now time.Time) (tls.Certificate, error) {
	dir := filepath.Join(dataDir, dirName)
	certPath, keyPath := filepath.Join(dir, certFile), filepath.Join(dir, keyFile)

	cert, err := tls.LoadX509KeyPair(certPath, keyPath)
	if err == nil {
		return cert, nil
	}
	if !errors.Is(err, fs.ErrNotExist) {
		return tls.Certificate{}, fmt.Errorf("load certificate: %w", err)
	}
	if err := create(dir, certPath, keyPath, now); err != nil {
		return tls.Certificate{}, err
	}
	cert, err = tls.LoadX509KeyPair(certPath, keyPath)
	if err != nil {
		return tls.Certificate{}, fmt.Errorf("load new certificate: %w", err)
	}
	return cert, nil
}

// Load returns the existing certificate under dataDir/tls.
func Load(dataDir string) (tls.Certificate, error) {
	dir := filepath.Join(dataDir, dirName)
	cert, err := tls.LoadX509KeyPair(filepath.Join(dir, certFile), filepath.Join(dir, keyFile))
	if err != nil {
		return tls.Certificate{}, fmt.Errorf("load certificate: %w", err)
	}
	return cert, nil
}

func create(dir, certPath, keyPath string, now time.Time) error {
	if err := os.MkdirAll(dir, 0o700); err != nil {
		return fmt.Errorf("create certificate directory: %w", err)
	}
	key, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		return fmt.Errorf("generate key: %w", err)
	}
	serial, err := rand.Int(rand.Reader, new(big.Int).Lsh(big.NewInt(1), 127))
	if err != nil {
		return fmt.Errorf("generate serial: %w", err)
	}
	tmpl := &x509.Certificate{
		SerialNumber:          serial,
		Subject:               pkix.Name{CommonName: "batz"},
		NotBefore:             now.Add(-time.Hour),
		NotAfter:              now.AddDate(ValidityYears, 0, 0),
		KeyUsage:              x509.KeyUsageDigitalSignature,
		ExtKeyUsage:           []x509.ExtKeyUsage{x509.ExtKeyUsageServerAuth},
		BasicConstraintsValid: true,
		DNSNames:              []string{"localhost"},
		IPAddresses:           []net.IP{net.IPv4(127, 0, 0, 1), net.IPv6loopback},
	}
	der, err := x509.CreateCertificate(rand.Reader, tmpl, tmpl, &key.PublicKey, key)
	if err != nil {
		return fmt.Errorf("create certificate: %w", err)
	}
	keyDER, err := x509.MarshalPKCS8PrivateKey(key)
	if err != nil {
		return fmt.Errorf("encode key: %w", err)
	}
	// Key first: a crash between both writes leaves no certificate without
	// its key, and the next start creates a fresh pair.
	if err := writePEM(keyPath, "PRIVATE KEY", keyDER, 0o600); err != nil {
		return err
	}
	return writePEM(certPath, "CERTIFICATE", der, 0o644)
}

func writePEM(path, blockType string, der []byte, mode os.FileMode) error {
	tmp := path + ".tmp"
	data := pem.EncodeToMemory(&pem.Block{Type: blockType, Bytes: der})
	if err := os.WriteFile(tmp, data, mode); err != nil {
		return fmt.Errorf("write %s: %w", path, err)
	}
	if err := os.Rename(tmp, path); err != nil {
		return fmt.Errorf("write %s: %w", path, err)
	}
	return nil
}

// Fingerprint returns the SHA-256 of the leaf certificate (DER), as upper-case
// hex pairs separated by colons: the value the app pins and shows.
func Fingerprint(cert tls.Certificate) string {
	if len(cert.Certificate) == 0 {
		return ""
	}
	return FingerprintDER(cert.Certificate[0])
}

// FingerprintDER is Fingerprint for a DER-encoded certificate.
func FingerprintDER(der []byte) string {
	sum := sha256.Sum256(der)
	parts := make([]string, len(sum))
	for i, b := range sum {
		parts[i] = fmt.Sprintf("%02X", b)
	}
	return strings.Join(parts, ":")
}

// ErrFingerprintMismatch is returned when a server presents a certificate
// other than the pinned one.
var ErrFingerprintMismatch = errors.New("server certificate does not match the pinned fingerprint")

// PinnedConfig returns a client TLS configuration that accepts exactly the
// certificate whose fingerprint is given, whatever its name or issuer. It is
// what the app does; the server uses it for its own health check.
func PinnedConfig(fingerprint string) *tls.Config {
	return &tls.Config{
		MinVersion: tls.VersionTLS12,
		// The chain and host name are not checked: the pin replaces them.
		InsecureSkipVerify: true, //nolint:gosec // verified by VerifyConnection
		VerifyConnection: func(cs tls.ConnectionState) error {
			if len(cs.PeerCertificates) == 0 || FingerprintDER(cs.PeerCertificates[0].Raw) != fingerprint {
				return ErrFingerprintMismatch
			}
			return nil
		},
	}
}

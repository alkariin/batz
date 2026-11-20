// Package persistence stores the server data in a SQLite file.
package persistence

import (
	"database/sql"
	"embed"
	"errors"
	"fmt"
	"net/url"

	"github.com/golang-migrate/migrate/v4"
	migratesqlite "github.com/golang-migrate/migrate/v4/database/sqlite"
	"github.com/golang-migrate/migrate/v4/source/iofs"
	_ "modernc.org/sqlite" // pure Go driver, registered as "sqlite"
)

//go:embed migrations/*.sql
var migrations embed.FS

// Open opens (or creates) the database file at path and applies the pending
// migrations. Migrations are embedded in the binary, so a server always runs
// against the schema of its own version.
func Open(path string) (*sql.DB, error) {
	q := url.Values{}
	q.Add("_pragma", "foreign_keys(1)")
	q.Add("_pragma", "journal_mode(WAL)")
	q.Add("_pragma", "busy_timeout(5000)")
	q.Add("_txlock", "immediate")
	db, err := sql.Open("sqlite", "file:"+path+"?"+q.Encode())
	if err != nil {
		return nil, fmt.Errorf("open database: %w", err)
	}
	// One connection: SQLite has a single writer anyway, and the pairing
	// command of another process waits on busy_timeout.
	db.SetMaxOpenConns(1)
	if err := db.Ping(); err != nil {
		db.Close()
		return nil, fmt.Errorf("open database %s: %w", path, err)
	}
	if err := migrateUp(db); err != nil {
		db.Close()
		return nil, err
	}
	return db, nil
}

func migrateUp(db *sql.DB) error {
	src, err := iofs.New(migrations, "migrations")
	if err != nil {
		return fmt.Errorf("load migrations: %w", err)
	}
	drv, err := migratesqlite.WithInstance(db, &migratesqlite.Config{})
	if err != nil {
		return fmt.Errorf("migration driver: %w", err)
	}
	m, err := migrate.NewWithInstance("iofs", src, "sqlite", drv)
	if err != nil {
		return fmt.Errorf("migrations: %w", err)
	}
	if err := m.Up(); err != nil && !errors.Is(err, migrate.ErrNoChange) {
		return fmt.Errorf("apply migrations: %w", err)
	}
	return nil
}

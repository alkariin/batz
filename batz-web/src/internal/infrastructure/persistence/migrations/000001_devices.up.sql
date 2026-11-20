-- Times are Unix milliseconds, UTC.
CREATE TABLE devices (
    id           TEXT    PRIMARY KEY,
    name         TEXT    NOT NULL,
    key_hash     TEXT    NOT NULL UNIQUE,
    created_at   INTEGER NOT NULL,
    last_seen_at INTEGER,
    revoked_at   INTEGER
) STRICT;

CREATE TABLE pairing_codes (
    code_hash  TEXT    PRIMARY KEY,
    created_at INTEGER NOT NULL,
    expires_at INTEGER NOT NULL,
    used_at    INTEGER,
    device_id  TEXT    REFERENCES devices (id)
) STRICT;

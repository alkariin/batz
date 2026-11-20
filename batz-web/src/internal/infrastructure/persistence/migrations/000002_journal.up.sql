-- The reference copy of the change journal, kept as the apps send it.
-- hlc sorts in time order and ends with the origin device, copied to origin
-- so that the latest entry of each origin is one index lookup.
CREATE TABLE journal (
    hlc           TEXT    NOT NULL,
    entity        TEXT    NOT NULL,
    record_id     TEXT    NOT NULL,
    field         TEXT    NOT NULL,
    value         TEXT    NOT NULL,
    origin        TEXT    NOT NULL,
    received_from TEXT    NOT NULL,
    received_at   INTEGER NOT NULL,
    PRIMARY KEY (hlc, entity, record_id, field)
) STRICT, WITHOUT ROWID;

CREATE INDEX journal_origin_hlc ON journal (origin, hlc);

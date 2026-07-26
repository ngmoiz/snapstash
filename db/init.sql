CREATE TABLE items (
    id   SERIAL   PRIMARY KEY,
    filename  TEXT  NOT NULL,
    title  TEXT  NOT NULL,
    target_url  TEXT  NOT NULL,
    size_bytes  BIGINT  NOT NULL,
    created_at  TIMESTAMPTZ  DEFAULT now()
);
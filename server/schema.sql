CREATE SCHEMA IF NOT EXISTS audioguide;

CREATE TABLE IF NOT EXISTS audioguide.guides (
  id                 TEXT PRIMARY KEY,
  title              TEXT NOT NULL,
  subtitle           TEXT,
  city               TEXT NOT NULL,
  region             TEXT,
  language           TEXT NOT NULL DEFAULT 'ru',
  center_lat         DOUBLE PRECISION NOT NULL,
  center_lon         DOUBLE PRECISION NOT NULL,
  intro_title        TEXT,
  intro_text         TEXT,
  intro_audio_path   TEXT,
  intro_duration_sec INTEGER,
  stops_count        INTEGER NOT NULL DEFAULT 0,
  duration_sec       INTEGER NOT NULL DEFAULT 0,
  content_version    INTEGER NOT NULL DEFAULT 1,
  status             TEXT NOT NULL DEFAULT 'draft'
                     CHECK (status IN ('draft', 'published')),
  published_at       TIMESTAMPTZ,
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS audioguide.guide_aliases (
  guide_id TEXT NOT NULL REFERENCES audioguide.guides(id) ON DELETE CASCADE,
  alias    TEXT NOT NULL,
  PRIMARY KEY (guide_id, alias)
);

CREATE TABLE IF NOT EXISTS audioguide.stops (
  id           TEXT NOT NULL,
  guide_id     TEXT NOT NULL REFERENCES audioguide.guides(id) ON DELETE CASCADE,
  name         TEXT NOT NULL,
  category     TEXT,
  lat          DOUBLE PRECISION NOT NULL,
  lon          DOUBLE PRECISION NOT NULL,
  sort_order   INTEGER NOT NULL,
  body_text    TEXT NOT NULL,
  audio_path   TEXT NOT NULL,
  duration_sec INTEGER,
  PRIMARY KEY (guide_id, id)
);

CREATE INDEX IF NOT EXISTS guides_published_idx ON audioguide.guides (status, city);
CREATE INDEX IF NOT EXISTS aliases_lower_idx ON audioguide.guide_aliases (lower(alias));
CREATE INDEX IF NOT EXISTS stops_order_idx ON audioguide.stops (guide_id, sort_order);

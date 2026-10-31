-- Aggregate counters only; no IPs, cookies, referrers, or other visitor identifiers.
CREATE TABLE download_totals (
  source TEXT PRIMARY KEY CHECK (source IN ('all', 'hero', 'footer', 'direct')),
  downloads INTEGER NOT NULL DEFAULT 0 CHECK (downloads >= 0)
);
INSERT INTO download_totals (source) VALUES ('all'), ('hero'), ('footer'), ('direct');
CREATE TABLE download_daily (
  day TEXT PRIMARY KEY,
  downloads INTEGER NOT NULL DEFAULT 0 CHECK (downloads >= 0)
);

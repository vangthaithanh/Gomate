CREATE TABLE IF NOT EXISTS place_categories (
 id BIGSERIAL PRIMARY KEY,
 code VARCHAR(50) NOT NULL UNIQUE,
 name VARCHAR(100) NOT NULL UNIQUE,
 description TEXT,
 active BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS places (
 id BIGSERIAL PRIMARY KEY,
 category_id BIGINT NOT NULL REFERENCES place_categories(id),
 name VARCHAR(200) NOT NULL,
 description TEXT,
 province VARCHAR(100) NOT NULL,
 district VARCHAR(100),
 address TEXT,
 latitude DECIMAL(10,7) NOT NULL,
 longitude DECIMAL(10,7) NOT NULL,
 opening_hours JSONB,
 price_level SMALLINT CHECK (price_level IS NULL OR price_level BETWEEN 0 AND 4),
 avg_rating NUMERIC(3,2) NOT NULL DEFAULT 0 CHECK (avg_rating BETWEEN 0 AND 5),
 review_count INT NOT NULL DEFAULT 0 CHECK (review_count >= 0),
 save_count INT NOT NULL DEFAULT 0 CHECK (save_count >= 0),
 source_type VARCHAR(20) NOT NULL DEFAULT 'ADMIN' CHECK (source_type IN ('ADMIN','EXTERNAL_API','USER_APPROVED')),
 external_source VARCHAR(50),
 external_id VARCHAR(150),
 status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','HIDDEN','DELETED')),
 created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
 updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
 CONSTRAINT uq_places_external UNIQUE (external_source, external_id)
);

CREATE TABLE IF NOT EXISTS place_media (
 id BIGSERIAL PRIMARY KEY,
 place_id BIGINT NOT NULL REFERENCES places(id) ON DELETE CASCADE,
 media_type VARCHAR(10) NOT NULL CHECK (media_type IN ('IMAGE','VIDEO')),
 url TEXT NOT NULL,
 public_id TEXT NOT NULL,
 caption VARCHAR(255),
 sort_order INT NOT NULL DEFAULT 0,
 created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS ix_places_category ON places(category_id);
CREATE INDEX IF NOT EXISTS ix_places_status_province ON places(status, province);
CREATE INDEX IF NOT EXISTS ix_places_coordinates ON places(latitude, longitude);
CREATE INDEX IF NOT EXISTS ix_places_search_basic ON places(name, province);
CREATE INDEX IF NOT EXISTS ix_place_media_place_sort ON place_media(place_id, sort_order, id);

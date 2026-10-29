CREATE TABLE posts (
 id BIGSERIAL PRIMARY KEY,
 author_id UUID NOT NULL REFERENCES users(id),
 client_request_id UUID NOT NULL,
 request_hash VARCHAR(64) NOT NULL,
 content TEXT NOT NULL,
 audience VARCHAR(20) NOT NULL CHECK (audience IN ('ACCOUNT','FRIENDS','ONLY_ME')),
 place_id BIGINT REFERENCES places(id),
 created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
 CONSTRAINT uq_posts_publish UNIQUE(author_id,client_request_id)
);
CREATE INDEX ix_posts_author_created ON posts(author_id,created_at,id);

CREATE TABLE post_media (
 id UUID PRIMARY KEY,
 owner_id UUID NOT NULL REFERENCES users(id),
 post_id BIGINT REFERENCES posts(id),
 content_hash VARCHAR(64) NOT NULL,
 kind VARCHAR(10) NOT NULL CHECK (kind IN ('IMAGE','VIDEO')),
 state VARCHAR(15) NOT NULL CHECK (state IN ('UPLOADING','READY','ATTACHED','CLEANUP')),
 public_id TEXT NOT NULL UNIQUE,
 thumbnail_public_id TEXT NOT NULL UNIQUE,
 format VARCHAR(20),
 mime_type VARCHAR(80),
 bytes BIGINT,
 duration_ms BIGINT,
 width INTEGER,
 height INTEGER,
 sort_order INTEGER,
 created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
 CONSTRAINT ck_post_media_attachment CHECK ((post_id IS NULL AND sort_order IS NULL AND state<>'ATTACHED') OR (post_id IS NOT NULL AND sort_order>=0 AND state='ATTACHED')),
 CONSTRAINT ck_post_media_duration CHECK (duration_ms IS NULL OR (duration_ms>0 AND duration_ms<=60000)),
 CONSTRAINT uq_post_media_order UNIQUE(post_id,sort_order)
);
CREATE INDEX ix_post_media_staging ON post_media(state,created_at);

CREATE TABLE hashtags (
 id BIGSERIAL PRIMARY KEY,
 name TEXT NOT NULL,
 name_hash VARCHAR(64) NOT NULL UNIQUE
);
CREATE TABLE post_hashtags (
 post_id BIGINT NOT NULL REFERENCES posts(id),
 hashtag_id BIGINT NOT NULL REFERENCES hashtags(id),
 PRIMARY KEY(post_id,hashtag_id)
);
CREATE TABLE post_user_tags (
 post_id BIGINT NOT NULL REFERENCES posts(id),
 user_id UUID NOT NULL REFERENCES users(id),
 PRIMARY KEY(post_id,user_id)
);

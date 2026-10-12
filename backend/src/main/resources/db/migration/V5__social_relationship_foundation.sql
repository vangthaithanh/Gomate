CREATE TABLE IF NOT EXISTS user_follows (
 follower_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 followed_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
 PRIMARY KEY (follower_user_id,followed_user_id),
 CONSTRAINT ck_user_follows_no_self CHECK (follower_user_id <> followed_user_id)
);

CREATE INDEX IF NOT EXISTS ix_user_follows_followed_follower
 ON user_follows(followed_user_id,follower_user_id);

CREATE INDEX IF NOT EXISTS ix_user_follows_follower_created
 ON user_follows(follower_user_id,created_at,followed_user_id);

CREATE INDEX IF NOT EXISTS ix_user_follows_followed_created
 ON user_follows(followed_user_id,created_at,follower_user_id);

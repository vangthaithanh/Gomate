CREATE TABLE post_likes (
 post_id BIGINT NOT NULL REFERENCES posts(id),
 user_id UUID NOT NULL REFERENCES users(id),
 created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
 PRIMARY KEY(post_id,user_id)
);
CREATE TABLE post_saves (
 post_id BIGINT NOT NULL REFERENCES posts(id),
 user_id UUID NOT NULL REFERENCES users(id),
 created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
 PRIMARY KEY(post_id,user_id)
);
CREATE INDEX ix_post_saves_user ON post_saves(user_id,created_at,post_id);
CREATE INDEX ix_posts_feed_created ON posts(created_at,id);

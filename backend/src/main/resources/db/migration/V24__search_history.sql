-- Search metadata only. Messages continue to use the existing Mongo collection.
CREATE TABLE recent_searches (
    user_id UUID NOT NULL REFERENCES users(id),
    query_key VARCHAR(200) NOT NULL,
    display_query VARCHAR(200) NOT NULL,
    used_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY(user_id,query_key)
);
CREATE INDEX ix_recent_searches_user_time ON recent_searches(user_id,used_at DESC,query_key);
CREATE INDEX ix_post_hashtags_tag_post ON post_hashtags(hashtag_id,post_id);

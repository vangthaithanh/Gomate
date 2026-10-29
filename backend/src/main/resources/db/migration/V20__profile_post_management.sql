ALTER TABLE posts ADD COLUMN pinned_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE posts ADD COLUMN deleted_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE post_media ADD COLUMN cleaned_at TIMESTAMP WITH TIME ZONE;
CREATE INDEX ix_posts_profile_order ON posts(author_id,deleted_at,pinned_at,created_at,id);

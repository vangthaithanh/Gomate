CREATE TABLE comments (
 id BIGSERIAL PRIMARY KEY,
 post_id BIGINT NOT NULL REFERENCES posts(id),
 user_id UUID NOT NULL REFERENCES users(id),
 client_request_id UUID NOT NULL,
 request_hash VARCHAR(64) NOT NULL,
 parent_comment_id BIGINT,
 reply_to_user_id UUID REFERENCES users(id),
 content TEXT NOT NULL,
 publication_status VARCHAR(12) NOT NULL DEFAULT 'ACTIVE' CHECK(publication_status IN ('ACTIVE','DELETED')),
 moderation_status VARCHAR(12) NOT NULL DEFAULT 'VISIBLE' CHECK(moderation_status IN ('VISIBLE','HIDDEN')),
 created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
 updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
 UNIQUE(user_id,client_request_id),
 UNIQUE(id,post_id),
 UNIQUE(id,user_id,post_id),
 FOREIGN KEY(parent_comment_id,post_id) REFERENCES comments(id,post_id),
 CHECK(parent_comment_id IS NULL OR parent_comment_id<>id),
 CHECK(parent_comment_id IS NOT NULL OR reply_to_user_id IS NULL)
);
CREATE INDEX ix_comments_thread ON comments(post_id,parent_comment_id,id);
CREATE TABLE comment_likes (
 comment_id BIGINT NOT NULL REFERENCES comments(id),
 user_id UUID NOT NULL REFERENCES users(id),
 created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
 PRIMARY KEY(comment_id,user_id)
);
CREATE TABLE comment_media (
 id UUID PRIMARY KEY,
 owner_id UUID NOT NULL REFERENCES users(id),
 post_id BIGINT NOT NULL REFERENCES posts(id),
 comment_id BIGINT,
 content_hash VARCHAR(64) NOT NULL,
 state VARCHAR(15) NOT NULL CHECK(state IN ('UPLOADING','READY','ATTACHED','CLEANUP')),
 public_id TEXT NOT NULL UNIQUE,
 thumbnail_public_id TEXT NOT NULL UNIQUE,
 format VARCHAR(20),
 mime_type VARCHAR(80),
 bytes BIGINT,
 width INTEGER,
 height INTEGER,
 sort_order INTEGER,
 created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
 cleaned_at TIMESTAMP WITH TIME ZONE,
 FOREIGN KEY(comment_id,owner_id,post_id) REFERENCES comments(id,user_id,post_id),
 UNIQUE(comment_id,sort_order),
 CHECK((comment_id IS NULL AND sort_order IS NULL AND state<>'ATTACHED') OR (comment_id IS NOT NULL AND sort_order BETWEEN 0 AND 5 AND state='ATTACHED'))
);
CREATE INDEX ix_comment_media_staging ON comment_media(state,created_at);
CREATE TABLE post_reports (
 id UUID PRIMARY KEY,
 reporter_id UUID NOT NULL REFERENCES users(id),
 post_id BIGINT NOT NULL REFERENCES posts(id),
 client_request_id UUID NOT NULL,
 request_hash VARCHAR(64) NOT NULL,
 reason_code VARCHAR(50) NOT NULL CHECK(reason_code IN ('NEGATIVE_OR_VIOLENCE','NUDITY_OR_INAPPROPRIATE','SCAM_OR_SPAM','PROHIBITED_GOODS','FALSE_INFORMATION','INTELLECTUAL_PROPERTY')),
 details TEXT NOT NULL,
 status VARCHAR(15) NOT NULL DEFAULT 'PENDING' CHECK(status='PENDING'),
 created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
 updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
 UNIQUE(reporter_id,client_request_id)
);
CREATE INDEX ix_post_reports_reporter ON post_reports(reporter_id,created_at,id);

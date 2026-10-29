CREATE TABLE IF NOT EXISTS conversations (
 id UUID PRIMARY KEY,
 type VARCHAR(20) NOT NULL CHECK (type IN ('DIRECT')),
 status VARCHAR(20) NOT NULL CHECK (status IN ('PENDING','ACCEPTED','REMOVED','CLOSED')),
 created_by UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 requester_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 recipient_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 user_low_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 user_high_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 title VARCHAR(150),
 created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
 updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
 accepted_at TIMESTAMP WITH TIME ZONE,
 removed_at TIMESTAMP WITH TIME ZONE,
 CHECK (requester_id <> recipient_id),
 CHECK (user_low_id <> user_high_id),
 UNIQUE (type,user_low_id,user_high_id)
);

CREATE TABLE IF NOT EXISTS conversation_members (
 conversation_id UUID NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
 user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 role VARCHAR(20) NOT NULL DEFAULT 'MEMBER' CHECK (role IN ('MEMBER')),
 status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','REMOVED')),
 muted BOOLEAN NOT NULL DEFAULT FALSE,
 blocked BOOLEAN NOT NULL DEFAULT FALSE,
 last_read_at TIMESTAMP WITH TIME ZONE,
 joined_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
 removed_at TIMESTAMP WITH TIME ZONE,
 PRIMARY KEY (conversation_id,user_id)
);

CREATE INDEX IF NOT EXISTS ix_conversations_user_low_high
 ON conversations(user_low_id,user_high_id);

CREATE INDEX IF NOT EXISTS ix_conversations_recipient_status_updated
 ON conversations(recipient_id,status,updated_at DESC);

CREATE INDEX IF NOT EXISTS ix_conversation_members_user_status
 ON conversation_members(user_id,status,conversation_id);

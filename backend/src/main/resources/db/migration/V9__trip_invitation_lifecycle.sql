CREATE TABLE IF NOT EXISTS trip_invitations (
 id UUID PRIMARY KEY,
 trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
 inviter_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 invitee_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 status VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING','ACCEPTED','DECLINED')),
 created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
 responded_at TIMESTAMP WITH TIME ZONE,
 updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
 CONSTRAINT ck_trip_invitations_not_self CHECK (inviter_user_id <> invitee_user_id)
);

CREATE INDEX IF NOT EXISTS ix_trip_invitations_invitee_status_created
 ON trip_invitations(invitee_user_id,status,created_at);

CREATE INDEX IF NOT EXISTS ix_trip_invitations_trip_status
 ON trip_invitations(trip_id,status);

CREATE INDEX IF NOT EXISTS ix_trip_invitations_trip_invitee_status
 ON trip_invitations(trip_id,invitee_user_id,status);

ALTER TABLE trip_members ADD COLUMN location_sharing_updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP;

-- Earlier ON flags were created implicitly by pin/publish, not explicit consent.
UPDATE trip_members SET location_sharing_enabled=FALSE WHERE location_sharing_enabled=TRUE;

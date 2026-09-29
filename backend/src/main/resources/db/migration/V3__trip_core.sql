CREATE TABLE IF NOT EXISTS trips (
 id UUID PRIMARY KEY,
 owner_id UUID NOT NULL REFERENCES users(id),
 title VARCHAR(200) NOT NULL,
 description TEXT,
 trip_type VARCHAR(20) NOT NULL DEFAULT 'PERSONAL' CHECK (trip_type IN ('PERSONAL','GROUP')),
 status VARCHAR(20) NOT NULL DEFAULT 'DRAFT' CHECK (status IN ('DRAFT','PLANNED','ACTIVE','COMPLETED','CANCELLED')),
 start_date DATE NOT NULL,
 end_date DATE NOT NULL,
 timezone VARCHAR(64) NOT NULL DEFAULT 'Asia/Ho_Chi_Minh',
 started_at TIMESTAMP WITH TIME ZONE,
 completed_at TIMESTAMP WITH TIME ZONE,
 created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
 updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
 CONSTRAINT ck_trips_date_range CHECK (end_date >= start_date)
);

CREATE TABLE IF NOT EXISTS trip_members (
 trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
 user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 role VARCHAR(20) NOT NULL CHECK (role IN ('LEADER','MEMBER')),
 status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE' CHECK (status IN ('ACTIVE','LEFT','KICKED')),
 invited_by UUID REFERENCES users(id),
 joined_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
 left_at TIMESTAMP WITH TIME ZONE,
 location_sharing_enabled BOOLEAN NOT NULL DEFAULT FALSE,
 PRIMARY KEY (trip_id,user_id)
);

CREATE TABLE IF NOT EXISTS trip_stops (
 id UUID PRIMARY KEY,
 trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
 place_id BIGINT NOT NULL REFERENCES places(id),
 day_no INT NOT NULL CHECK (day_no >= 1),
 order_no INT NOT NULL CHECK (order_no >= 1),
 planned_start_at TIMESTAMP WITH TIME ZONE,
 planned_duration_min INT CHECK (planned_duration_min IS NULL OR planned_duration_min > 0),
 note TEXT,
 checkin_radius_m INT NOT NULL DEFAULT 150 CHECK (checkin_radius_m > 0),
 status VARCHAR(20) NOT NULL DEFAULT 'PLANNED' CHECK (status IN ('PLANNED','VISITED','SKIPPED')),
 created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
 updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
 CONSTRAINT uq_trip_stops_order UNIQUE (trip_id,day_no,order_no)
);

CREATE TABLE IF NOT EXISTS trip_reminders (
 id UUID PRIMARY KEY,
 trip_id UUID NOT NULL REFERENCES trips(id) ON DELETE CASCADE,
 trip_stop_id UUID REFERENCES trip_stops(id) ON DELETE CASCADE,
 recipient_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 reminder_type VARCHAR(30) NOT NULL CHECK (reminder_type IN ('TRIP_START','UPCOMING_STOP')),
 remind_at TIMESTAMP WITH TIME ZONE NOT NULL,
 status VARCHAR(20) NOT NULL DEFAULT 'PENDING' CHECK (status IN ('PENDING','SENT','CANCELLED')),
 created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS ix_trips_owner_status ON trips(owner_id,status,created_at);
CREATE INDEX IF NOT EXISTS ix_trip_members_user_status ON trip_members(user_id,status);
CREATE INDEX IF NOT EXISTS ix_trip_members_trip_role_status ON trip_members(trip_id,role,status);
CREATE INDEX IF NOT EXISTS ix_trip_stops_trip_order ON trip_stops(trip_id,day_no,order_no);
CREATE INDEX IF NOT EXISTS ix_trip_stops_place ON trip_stops(place_id);
CREATE INDEX IF NOT EXISTS ix_trip_reminders_recipient_status_time ON trip_reminders(recipient_user_id,status,remind_at);

ALTER TABLE trips ADD COLUMN planned_start_time TIME;

ALTER TABLE trip_reminders ADD COLUMN offset_minutes INTEGER;
ALTER TABLE trip_reminders ADD COLUMN planned_start_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE trip_reminders ADD COLUMN sent_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE trip_reminders ADD CONSTRAINT ck_trip_start_reminder_offset CHECK (
 offset_minutes IS NULL OR
 (reminder_type='TRIP_START' AND trip_stop_id IS NULL AND offset_minutes IN (60,30))
);
ALTER TABLE trip_reminders ADD CONSTRAINT uq_trip_start_reminder_offset
 UNIQUE(trip_id,recipient_user_id,reminder_type,offset_minutes);
CREATE INDEX ix_trip_reminders_due ON trip_reminders(status,remind_at,id);

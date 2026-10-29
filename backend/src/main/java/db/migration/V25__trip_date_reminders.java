package db.migration;

import java.sql.*;
import java.time.*;
import java.util.UUID;
import org.flywaydb.core.api.migration.BaseJavaMigration;
import org.flywaydb.core.api.migration.Context;

/** Keep V17 history intact; day-based reminders have their own explicit identity. */
public class V25__trip_date_reminders extends BaseJavaMigration {
 @Override public Integer getChecksum() { return 25001; }
 @Override public void migrate(Context context) throws Exception {
  var c=context.getConnection();
  try(var sql=c.createStatement()) {
   sql.execute("ALTER TABLE trip_reminders ADD COLUMN days_before INTEGER");
   sql.execute("ALTER TABLE trip_reminders ADD COLUMN trip_start_date DATE");
   sql.execute("ALTER TABLE trip_reminders ADD COLUMN reminder_date DATE");
   sql.execute("ALTER TABLE trip_reminders ADD COLUMN reminder_timezone VARCHAR(64)");
   sql.execute("""
    ALTER TABLE trip_reminders ADD CONSTRAINT ck_trip_date_reminder CHECK (
     (days_before IS NULL AND trip_start_date IS NULL AND reminder_date IS NULL AND reminder_timezone IS NULL)
     OR (days_before IS NOT NULL AND days_before IN (1,2) AND trip_start_date IS NOT NULL
      AND reminder_date IS NOT NULL AND reminder_timezone IS NOT NULL
      AND reminder_type='TRIP_START' AND trip_stop_id IS NULL
      AND offset_minutes IS NULL AND planned_start_at IS NULL))
    """);
   sql.execute("ALTER TABLE trip_reminders ADD CONSTRAINT uq_trip_date_reminder_day UNIQUE(trip_id,recipient_user_id,reminder_type,reminder_date)");
   sql.execute("UPDATE trip_reminders SET status='CANCELLED' WHERE reminder_type='TRIP_START' AND status='PENDING'");
  }
  Instant now;
  try(var sql=c.createStatement();var r=sql.executeQuery("SELECT CURRENT_TIMESTAMP")) {
   r.next(); now=r.getObject(1,OffsetDateTime.class).toInstant();
  }
  // Migration-time backfill only: no startup sweep or new background subsystem.
  // Future deadlines only, so cutover never revives a missed reminder.
  try(var sql=c.createStatement();var rows=sql.executeQuery("""
   SELECT t.id,t.start_date,t.timezone,m.user_id
   FROM trips t JOIN trip_members m ON m.trip_id=t.id JOIN users u ON u.id=m.user_id
   WHERE t.archived_at IS NULL AND m.status='ACTIVE' AND u.status='ACTIVE'
   """)) {
   while(rows.next()) {
    var trip=rows.getObject(1,UUID.class);
    var start=rows.getObject(2,LocalDate.class);
    var zone=ZoneId.of(rows.getString(3));
    var user=rows.getObject(4,UUID.class);
    for(int days:new int[]{2,1}) {
     var date=start.minusDays(days);
     var local=date.atTime(20,0);
     var offsets=zone.getRules().getValidOffsets(local);
     if(offsets.isEmpty()) continue; // Never shift a nonexistent local 20:00.
     var due=local.toInstant(offsets.get(0));
     if(!due.isAfter(now)) continue;
     try(var insert=c.prepareStatement("""
      INSERT INTO trip_reminders(id,trip_id,recipient_user_id,reminder_type,remind_at,
       days_before,trip_start_date,reminder_date,reminder_timezone)
      VALUES(?,?,?,'TRIP_START',?,?,?,?,?)
      """)) {
      insert.setObject(1,UUID.randomUUID());insert.setObject(2,trip);insert.setObject(3,user);
      insert.setObject(4,due.atOffset(ZoneOffset.UTC));insert.setInt(5,days);
      insert.setObject(6,start);insert.setObject(7,date);insert.setString(8,zone.getId());
      insert.executeUpdate();
     }
    }
   }
  }
 }
}

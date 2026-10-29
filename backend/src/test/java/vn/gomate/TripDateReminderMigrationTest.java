package vn.gomate;

import java.sql.*;
import java.time.*;
import java.util.*;
import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class TripDateReminderMigrationTest {
 private String url() {return "jdbc:h2:mem:date_migration_"+UUID.randomUUID()+";MODE=PostgreSQL;DATABASE_TO_LOWER=TRUE;DB_CLOSE_DELAY=-1";}
 private Flyway flyway(String url,String target) {return Flyway.configure().dataSource(url,"sa","").locations("classpath:db/migration").target(target).load();}
 @Test void cleanRunsV1ThroughV25WithoutAddingTables() throws Exception {
  var url=url();flyway(url,"24").migrate();
  try(var c=DriverManager.getConnection(url,"sa","")) {
   long tables=count(c,"SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public'");
   flyway(url,"25").migrate();
   assertEquals(tables,count(c,"SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public'"));
   assertEquals(25,count(c,"SELECT COUNT(*) FROM flyway_schema_history WHERE success=TRUE AND version IS NOT NULL"));
  }
 }
 @Test void upgradeCancelsLegacyPendingPreservesSentInboxHourStopAndBackfillsFutureOnly() throws Exception {
  var url=url();flyway(url,"24").migrate();
  try(var c=DriverManager.getConnection(url,"sa","")) {
   var user=UUID.randomUUID();var trip=UUID.randomUUID();var pending=UUID.randomUUID();var sent=UUID.randomUUID();var notice=UUID.randomUUID();
   var start=LocalDate.now(ZoneId.of("Asia/Ho_Chi_Minh")).plusDays(4);
   execute(c,"INSERT INTO users(id,email,password_hash) VALUES(?,?,'fixture-not-login')",user,user+"@example.invalid");
   execute(c,"INSERT INTO trips(id,owner_id,title,start_date,end_date,timezone,planned_start_time) VALUES(?,?,'Migration fixture',?,?,'Asia/Ho_Chi_Minh','08:15')",trip,user,start,start);
   execute(c,"INSERT INTO trip_members(trip_id,user_id,role) VALUES(?,?,'LEADER')",trip,user);
   execute(c,"INSERT INTO trip_reminders(id,trip_id,recipient_user_id,reminder_type,offset_minutes,remind_at,planned_start_at) VALUES(?,?,?,'TRIP_START',60,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP)",pending,trip,user);
   execute(c,"INSERT INTO trip_reminders(id,trip_id,recipient_user_id,reminder_type,offset_minutes,remind_at,planned_start_at,status,sent_at) VALUES(?,?,?,'TRIP_START',30,CURRENT_TIMESTAMP,CURRENT_TIMESTAMP,'SENT',CURRENT_TIMESTAMP)",sent,trip,user);
   execute(c,"INSERT INTO notifications(id,user_id,type,entity_type,entity_id,title,body,is_read) VALUES(?,?,'TRIP_START_REMINDER','TRIP_REMINDER',?,'Historical','Keep this original body',TRUE)",notice,user,sent.toString());
   var sentBefore=row(c,"SELECT * FROM trip_reminders WHERE id=?",sent);
   var noticeBefore=row(c,"SELECT * FROM notifications WHERE id=?",notice);
   var tripBefore=row(c,"SELECT * FROM trips WHERE id=?",trip);
   long tables=count(c,"SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public'");
   flyway(url,"25").migrate();
   assertEquals("CANCELLED",row(c,"SELECT status FROM trip_reminders WHERE id=?",pending).get("status"));
   for(var field:sentBefore.entrySet())assertEquals(field.getValue(),row(c,"SELECT * FROM trip_reminders WHERE id=?",sent).get(field.getKey()));
   assertEquals(noticeBefore,row(c,"SELECT * FROM notifications WHERE id=?",notice));
   assertEquals(tripBefore,row(c,"SELECT * FROM trips WHERE id=?",trip));
   assertEquals(tables,count(c,"SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public'"));
   assertEquals(2,count(c,"SELECT COUNT(*) FROM trip_reminders WHERE days_before IN (1,2) AND status='PENDING'"));
   assertEquals(0,count(c,"SELECT COUNT(*) FROM trip_reminders WHERE days_before IS NOT NULL AND (offset_minutes IS NOT NULL OR planned_start_at IS NOT NULL)"));
   assertThrows(SQLException.class,() -> execute(c,"INSERT INTO trip_reminders(id,trip_id,recipient_user_id,reminder_type,remind_at,days_before,trip_start_date,reminder_date,reminder_timezone) SELECT ?,trip_id,recipient_user_id,reminder_type,remind_at,days_before,trip_start_date,reminder_date,reminder_timezone FROM trip_reminders WHERE days_before=2",UUID.randomUUID()));
   assertThrows(SQLException.class,() -> execute(c,"UPDATE trip_reminders SET days_before=3 WHERE days_before=2"));
   flyway(url,"25").migrate();assertEquals(4,count(c,"SELECT COUNT(*) FROM trip_reminders"));
  }
 }
 private long count(Connection c,String query) throws SQLException {try(var s=c.createStatement();var r=s.executeQuery(query)){r.next();return r.getLong(1);}}
 private void execute(Connection c,String sql,Object...args) throws SQLException {try(var s=c.prepareStatement(sql)){for(int i=0;i<args.length;i++)s.setObject(i+1,args[i]);s.executeUpdate();}}
 private Map<String,Object> row(Connection c,String sql,Object...args) throws SQLException {try(var s=c.prepareStatement(sql)){for(int i=0;i<args.length;i++)s.setObject(i+1,args[i]);try(var r=s.executeQuery()){r.next();var result=new LinkedHashMap<String,Object>();for(int i=1;i<=r.getMetaData().getColumnCount();i++)result.put(r.getMetaData().getColumnLabel(i),r.getObject(i));return result;}}}
}

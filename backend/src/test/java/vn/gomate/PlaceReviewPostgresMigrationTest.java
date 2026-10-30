package vn.gomate;

import java.sql.*;
import java.util.*;
import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import static org.junit.jupiter.api.Assertions.*;

/** Dedicated disposable PostgreSQL only, including a restored V26 snapshot. */
@EnabledIfEnvironmentVariable(named="GOMATE_REVIEW_PG_PROBE",matches="true")
class PlaceReviewPostgresMigrationTest {
 @Test void cleanAndRestoredV26PreserveEveryOldTableAndHistory()throws Exception {
  String url=System.getenv("REVIEW_PG_URL"),password=System.getenv("REVIEW_PG_PASSWORD");
  assertTrue(url.matches("jdbc:postgresql://127\\.0\\.0\\.1:[0-9]+/gomate_review_(clean|upgrade)"));
  boolean restored=url.endsWith("_upgrade");
  var flyway=Flyway.configure().dataSource(url,"review_probe",password).locations("classpath:db/migration").load();
  try(var c=DriverManager.getConnection(url,"review_probe",password)) {
   var old=new TreeMap<String,Long>();var history=new ArrayList<String>();
   if(restored) {
    try(var s=c.createStatement();var r=s.executeQuery("SELECT tablename FROM pg_tables WHERE schemaname='public' AND tablename<>'flyway_schema_history' ORDER BY tablename")) {while(r.next())old.put(r.getString(1),0L);}
    for(String table:old.keySet())old.put(table,count(c,"SELECT COUNT(*) FROM "+table));
    try(var s=c.createStatement();var r=s.executeQuery("SELECT version||':'||COALESCE(checksum::text,'') FROM flyway_schema_history ORDER BY installed_rank")){while(r.next())history.add(r.getString(1));}
    assertEquals(26,history.size());assertEquals(38,old.size());
   }
   flyway.migrate();flyway.validate();flyway.migrate();
   assertEquals(27,count(c,"SELECT COUNT(*) FROM flyway_schema_history WHERE success=TRUE AND version IS NOT NULL"));
   assertEquals(40,count(c,"SELECT COUNT(*) FROM pg_tables WHERE schemaname='public'"));
   assertEquals(0,count(c,"SELECT COUNT(*) FROM reviews"));
   for(var entry:old.entrySet())assertEquals(entry.getValue(),count(c,"SELECT COUNT(*) FROM "+entry.getKey()),entry.getKey());
   if(restored) {
    var after=new ArrayList<String>();try(var s=c.createStatement();var r=s.executeQuery("SELECT version||':'||COALESCE(checksum::text,'') FROM flyway_schema_history WHERE version<>'27' ORDER BY installed_rank")){while(r.next())after.add(r.getString(1));}
    assertEquals(history,after);
   }
   try(var s=c.createStatement();var r=s.executeQuery("SELECT indexdef FROM pg_indexes WHERE indexname='uq_reviews_active_user_place'")) {assertTrue(r.next());assertTrue(r.getString(1).contains("WHERE"));}
   // Constraint probe is rolled back; no seed reviews survive even in the probe.
   c.setAutoCommit(false);
   UUID actor=UUID.randomUUID();long place;
   try(var s=c.createStatement()) {
    s.execute("INSERT INTO users(id,email,password_hash) VALUES('"+actor+"','"+actor+"@example.invalid','probe-no-login')");
    s.execute("INSERT INTO place_categories(code,name) VALUES('review_probe','Review probe')");
    s.execute("INSERT INTO places(category_id,name,province,latitude,longitude) SELECT id,'Review probe','Probe',11,108 FROM place_categories WHERE code='review_probe'");
    try(var r=s.executeQuery("SELECT id FROM places WHERE name='Review probe'")){r.next();place=r.getLong(1);}
    s.execute("INSERT INTO reviews(user_id,place_id,rating) VALUES('"+actor+"',"+place+",5)");
    Savepoint save=c.setSavepoint();assertThrows(SQLException.class,()->s.execute("INSERT INTO reviews(user_id,place_id,rating) VALUES('"+actor+"',"+place+",3)"));c.rollback(save);
    save=c.setSavepoint();assertThrows(SQLException.class,()->s.execute("INSERT INTO reviews(user_id,place_id,rating) VALUES('"+UUID.randomUUID()+"',"+place+",0)"));c.rollback(save);
    s.execute("UPDATE reviews SET publication_status='DELETED' WHERE place_id="+place);
    s.execute("INSERT INTO reviews(user_id,place_id,rating) VALUES('"+actor+"',"+place+",3)");
   } finally {c.rollback();}
  }
 }
 long count(Connection c,String query)throws Exception {try(var s=c.createStatement();var r=s.executeQuery(query)){r.next();return r.getLong(1);}}
}

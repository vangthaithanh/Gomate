package vn.gomate;

import java.sql.*;
import java.util.*;
import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import static org.junit.jupiter.api.Assertions.*;

/** Explicit opt-in; only dedicated restored/clean probe databases, never business DB. */
@EnabledIfEnvironmentVariable(named="GOMATE_GLOBAL_BLOCK_PG_PROBE",matches="true")
class GlobalBlockPostgresMigrationTest {
 @Test void restoredV25AndCleanPostgresUpgradeWithHistoryPreserved() throws Exception {
  String password=System.getenv("DB_PASSWORD");
  for(String key:List.of("PG_UPGRADE_URL","PG_CLEAN_URL")) {
   String url=System.getenv(key);assertTrue(url.matches("jdbc:postgresql://postgres:5432/gomate_block_(upgrade|clean)_20261029"));
   var f=Flyway.configure().dataSource(url,"gomate",password).locations("classpath:db/migration").load();
   try(var c=DriverManager.getConnection(url,"gomate",password)) {
    boolean restored=key.equals("PG_UPGRADE_URL");
    long oldPosts=restored?count(c,"SELECT COUNT(*) FROM posts"):0,oldTrips=restored?count(c,"SELECT COUNT(*) FROM trips"):0,oldChats=restored?count(c,"SELECT COUNT(*) FROM conversations"):0;
    UUID a=null,b=null,chat=null;
    if(restored) {
     assertEquals(25,count(c,"SELECT COUNT(*) FROM flyway_schema_history WHERE success=TRUE AND version IS NOT NULL"));
     a=UUID.randomUUID();b=UUID.randomUUID();chat=UUID.randomUUID();
     for(UUID id:List.of(a,b)) exec(c,"INSERT INTO users(id,email,password_hash) VALUES(?,?,'probe-no-login')",id,id+"@example.invalid");
     exec(c,"INSERT INTO conversations(id,type,status,user_low_id,user_high_id,requester_id,recipient_id,created_by) VALUES(?,'DIRECT','ACCEPTED',?,?,?,?,?)",chat,a,b,a,b,a);
     for(UUID id:List.of(a,b))exec(c,"INSERT INTO conversation_members(conversation_id,user_id,blocked) VALUES(?,?,TRUE)",chat,id);
    }
    f.migrate();f.validate();f.migrate();
    assertEquals(26,count(c,"SELECT COUNT(*) FROM flyway_schema_history WHERE success=TRUE AND version IS NOT NULL"));
    assertEquals(39,count(c,"SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public' AND table_type='BASE TABLE'"));
    assertEquals(oldPosts,count(c,"SELECT COUNT(*) FROM posts"));assertEquals(oldTrips,count(c,"SELECT COUNT(*) FROM trips"));
    assertEquals(oldChats+(restored?1:0),count(c,"SELECT COUNT(*) FROM conversations"));
    assertEquals(restored?2:0,count(c,"SELECT COUNT(*) FROM user_blocks"));
    if(restored) {
     exec(c,"DELETE FROM user_blocks WHERE blocker_user_id=? AND blocked_user_id=?",a,b);
     assertEquals(1,count(c,"SELECT COUNT(*) FROM user_blocks"));
     assertEquals(2,count(c,"SELECT COUNT(*) FROM conversation_members WHERE conversation_id='"+chat+"' AND blocked=TRUE"));
     f.migrate();assertEquals(1,count(c,"SELECT COUNT(*) FROM user_blocks"));
    }
   }
  }
 }
 long count(Connection c,String sql)throws SQLException{try(var s=c.createStatement();var r=s.executeQuery(sql)){r.next();return r.getLong(1);}}
 void exec(Connection c,String sql,Object...args)throws SQLException{try(var s=c.prepareStatement(sql)){for(int i=0;i<args.length;i++)s.setObject(i+1,args[i]);s.executeUpdate();}}
}

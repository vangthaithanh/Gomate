package vn.gomate;

import java.sql.*;
import java.util.*;
import org.flywaydb.core.Flyway;
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

class GlobalBlockMigrationTest {
 String url(){return "jdbc:h2:mem:block_migration_"+UUID.randomUUID()+";MODE=PostgreSQL;DATABASE_TO_LOWER=TRUE;DB_CLOSE_DELAY=-1";}
 Flyway migrate(String url,String target){var f=Flyway.configure().dataSource(url,"sa","").locations("classpath:db/migration").target(target).load();f.migrate();return f;}
 @Test void cleanV26CreatesExactlyOneAdditionalBusinessTableAndConstraints() throws Exception {
  String url=url();migrate(url,"25");try(var c=DriverManager.getConnection(url,"sa","")) {
   long before=count(c,"SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public'");migrate(url,"26");
   assertEquals(before+1,count(c,"SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='public'"));
   assertEquals(26,count(c,"SELECT COUNT(*) FROM flyway_schema_history WHERE success=TRUE AND version IS NOT NULL"));
   assertEquals(0,count(c,"SELECT COUNT(*) FROM user_blocks"));
   UUID a=user(c),b=user(c);exec(c,"INSERT INTO user_blocks(blocker_user_id,blocked_user_id) VALUES(?,?)",a,b);
   assertThrows(SQLException.class,()->exec(c,"INSERT INTO user_blocks(blocker_user_id,blocked_user_id) VALUES(?,?)",a,b));
   assertThrows(SQLException.class,()->exec(c,"INSERT INTO user_blocks(blocker_user_id,blocked_user_id) VALUES(?,?)",a,a));
   assertThrows(SQLException.class,()->exec(c,"INSERT INTO user_blocks(blocker_user_id,blocked_user_id) VALUES(?,?)",a,UUID.randomUUID()));
  }
 }
 @Test void legacyBothDirectionsPreserveConversationFlagsAndRevokeOnlyAffectedFollowData() throws Exception {
  String url=url();migrate(url,"25");try(var c=DriverManager.getConnection(url,"sa","")) {
   UUID a=user(c),b=user(c),other=user(c),chat=UUID.randomUUID(),request=UUID.randomUUID();
   exec(c,"INSERT INTO conversations(id,type,status,user_low_id,user_high_id,requester_id,recipient_id,created_by) VALUES(?,'DIRECT','ACCEPTED',?,?,?,?,?)",chat,a,b,a,b,a);
   for(UUID u:List.of(a,b))exec(c,"INSERT INTO conversation_members(conversation_id,user_id,blocked) VALUES(?,?,TRUE)",chat,u);
   exec(c,"INSERT INTO user_follows(follower_user_id,followed_user_id) VALUES(?,?),(?,?),(?,?)",a,b,b,a,a,other);
   exec(c,"INSERT INTO follow_requests(id,requester_id,target_id,status) VALUES(?,?,?,'PENDING')",request,a,b);
   migrate(url,"26");
   assertEquals(2,count(c,"SELECT COUNT(*) FROM user_blocks"));assertEquals(2,count(c,"SELECT COUNT(*) FROM conversation_members WHERE blocked=TRUE"));
   assertEquals(1,count(c,"SELECT COUNT(*) FROM user_follows"));assertEquals(1,count(c,"SELECT COUNT(*) FROM follow_requests WHERE status='CANCELLED'"));
   assertEquals(1,count(c,"SELECT COUNT(*) FROM conversations WHERE status='ACCEPTED'"));
   exec(c,"DELETE FROM user_blocks WHERE blocker_user_id=? AND blocked_user_id=?",a,b);
   assertEquals(1,count(c,"SELECT COUNT(*) FROM user_blocks"));migrate(url,"26");assertEquals(1,count(c,"SELECT COUNT(*) FROM user_blocks"));
  }
 }
 UUID user(Connection c)throws SQLException{UUID id=UUID.randomUUID();exec(c,"INSERT INTO users(id,email,password_hash) VALUES(?,?,'migration-fixture')",id,id+"@example.invalid");return id;}
 long count(Connection c,String sql)throws SQLException{try(var s=c.createStatement();var r=s.executeQuery(sql)){r.next();return r.getLong(1);}}
 void exec(Connection c,String sql,Object...args)throws SQLException{try(var s=c.prepareStatement(sql)){for(int i=0;i<args.length;i++)s.setObject(i+1,args[i]);s.executeUpdate();}}
}

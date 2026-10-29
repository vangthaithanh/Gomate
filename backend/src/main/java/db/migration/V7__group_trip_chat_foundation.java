package db.migration;

import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Statement;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import org.flywaydb.core.api.migration.BaseJavaMigration;
import org.flywaydb.core.api.migration.Context;

public class V7__group_trip_chat_foundation extends BaseJavaMigration {
 @Override
 public void migrate(Context context) throws Exception {
  Connection connection=context.getConnection();
  String database=connection.getMetaData().getDatabaseProductName().toLowerCase(Locale.ROOT);

  if(database.contains("h2")) {
   dropH2CheckConstraints(connection);
  } else {
   dropConstraintIfExists(connection,"conversations","conversations_type_check");
   dropConstraintIfExists(connection,"conversations","conversations_status_check");
   dropConstraintIfExists(connection,"conversations","conversations_requester_id_check");
   dropConstraintIfExists(connection,"conversations","conversations_user_low_id_check");
   dropConstraintIfExists(connection,"conversation_members","conversation_members_role_check");
  }

  execute(connection,"ALTER TABLE conversations ADD COLUMN IF NOT EXISTS linked_trip_id UUID REFERENCES trips(id) ON DELETE CASCADE");
  execute(connection,"ALTER TABLE conversations ALTER COLUMN requester_id DROP NOT NULL");
  execute(connection,"ALTER TABLE conversations ALTER COLUMN recipient_id DROP NOT NULL");
  execute(connection,"ALTER TABLE conversations ALTER COLUMN user_low_id DROP NOT NULL");
  execute(connection,"ALTER TABLE conversations ALTER COLUMN user_high_id DROP NOT NULL");

  execute(connection,"ALTER TABLE conversations ADD CONSTRAINT ck_conversations_type CHECK (type IN ('DIRECT','GROUP'))");
  execute(connection,"ALTER TABLE conversations ADD CONSTRAINT ck_conversations_status CHECK (status IN ('PENDING','ACCEPTED','REMOVED','CLOSED'))");
  execute(connection,"""
   ALTER TABLE conversations
   ADD CONSTRAINT ck_conversations_direct_shape
   CHECK (
    (type='DIRECT'
     AND linked_trip_id IS NULL
     AND requester_id IS NOT NULL
     AND recipient_id IS NOT NULL
     AND user_low_id IS NOT NULL
     AND user_high_id IS NOT NULL
     AND requester_id <> recipient_id
     AND user_low_id <> user_high_id)
    OR
    (type='GROUP'
     AND linked_trip_id IS NOT NULL
     AND requester_id IS NULL
     AND recipient_id IS NULL
     AND user_low_id IS NULL
     AND user_high_id IS NULL
     AND status='ACCEPTED')
   )
   """);
  execute(connection,"ALTER TABLE conversations ADD CONSTRAINT uq_conversations_linked_trip UNIQUE(linked_trip_id)");

  execute(connection,"ALTER TABLE conversation_members ADD CONSTRAINT ck_conversation_members_role CHECK (role IN ('LEADER','MEMBER'))");
  execute(connection,"CREATE INDEX IF NOT EXISTS ix_conversations_type_linked_trip ON conversations(type,linked_trip_id)");
 }

 private void dropH2CheckConstraints(Connection connection) throws SQLException {
  for(String name: h2CheckConstraints(connection,"conversations")) {
   dropQuotedConstraintIfExists(connection,"conversations",name);
  }
  for(String name: h2CheckConstraints(connection,"conversation_members")) {
   dropQuotedConstraintIfExists(connection,"conversation_members",name);
  }
 }

 private List<String> h2CheckConstraints(Connection connection,String tableName) throws SQLException {
  List<String> names=new ArrayList<>();
  try(PreparedStatement statement=connection.prepareStatement("""
    SELECT tc.constraint_name, cc.check_clause
    FROM information_schema.table_constraints tc
    JOIN information_schema.check_constraints cc ON cc.constraint_name=tc.constraint_name
    WHERE tc.constraint_type='CHECK' AND tc.table_name=?
   """)) {
   statement.setString(1,tableName);
   try(ResultSet rs=statement.executeQuery()) {
    while(rs.next()) {
     String clause=rs.getString("check_clause");
     String normalized=normalizeCheckClause(clause);
     if(normalized.equals("TYPE='DIRECT'")
      || normalized.equals("REQUESTER_ID<>RECIPIENT_ID")
      || normalized.equals("USER_LOW_ID<>USER_HIGH_ID")
      || normalized.contains("STATUSIN('PENDING','ACCEPTED','REMOVED','CLOSED')")
      || normalized.equals("ROLE='MEMBER'")) {
      names.add(rs.getString("constraint_name"));
     }
    }
   }
  }
  return names;
 }

 private String normalizeCheckClause(String clause) {
  if(clause==null) return "";
  return clause.replace("\"","")
   .replace(" ","")
   .replace("\n","")
   .replace("\r","")
   .toUpperCase(Locale.ROOT);
 }

 private void dropConstraintIfExists(Connection connection,String tableName,String constraintName) throws SQLException {
  execute(connection,"ALTER TABLE "+tableName+" DROP CONSTRAINT IF EXISTS "+constraintName);
 }

 private void dropQuotedConstraintIfExists(Connection connection,String tableName,String constraintName) throws SQLException {
  execute(connection,"ALTER TABLE "+tableName+" DROP CONSTRAINT IF EXISTS \""+constraintName.replace("\"","\"\"")+"\"");
 }

 private void execute(Connection connection,String sql) throws SQLException {
  try(Statement statement=connection.createStatement()) {
   statement.execute(sql);
  }
 }
}

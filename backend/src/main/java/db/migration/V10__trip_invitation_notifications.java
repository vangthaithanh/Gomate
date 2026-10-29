package db.migration;

import java.sql.*;
import java.util.UUID;
import org.flywaydb.core.api.migration.BaseJavaMigration;
import org.flywaydb.core.api.migration.Context;

public class V10__trip_invitation_notifications extends BaseJavaMigration {
 @Override
 public void migrate(Context context) throws Exception {
  Connection connection=context.getConnection();
  try(Statement sql=connection.createStatement()) {
   sql.execute("""
    CREATE TABLE notifications (
     id UUID PRIMARY KEY,
     user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
     type VARCHAR(50) NOT NULL,
     actor_id UUID REFERENCES users(id) ON DELETE SET NULL,
     entity_type VARCHAR(30),
     entity_id VARCHAR(80),
     title VARCHAR(150) NOT NULL,
     body VARCHAR(500) NOT NULL,
     data JSONB,
     is_read BOOLEAN NOT NULL DEFAULT FALSE,
     created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
     CONSTRAINT uq_notifications_recipient_event UNIQUE(user_id,type,entity_type,entity_id)
    )
    """);
   sql.execute("CREATE INDEX ix_notifications_inbox ON notifications(user_id,is_read,created_at)");
   sql.execute("CREATE INDEX ix_notifications_recipient_created ON notifications(user_id,created_at,id)");
  }
  // Existing invites retain their identity; inbox events have separate IDs.
  try(PreparedStatement read=connection.prepareStatement("SELECT * FROM trip_invitations");
      ResultSet rows=read.executeQuery();
      PreparedStatement insert=connection.prepareStatement("""
       INSERT INTO notifications(id,user_id,type,actor_id,entity_type,entity_id,title,body,created_at)
       VALUES(?,?,'TRIP_INVITATION',?,'TRIP_INVITATION',?,'Loi moi lich trinh','moi ban tham gia lich trinh',?)
       """)) {
   while(rows.next()) {
    insert.setObject(1,UUID.randomUUID());
    insert.setObject(2,rows.getObject("invitee_user_id"));
    insert.setObject(3,rows.getObject("inviter_user_id"));
    insert.setString(4,rows.getObject("id").toString());
    insert.setObject(5,rows.getObject("created_at"));
    insert.executeUpdate();
   }
  }
 }
}

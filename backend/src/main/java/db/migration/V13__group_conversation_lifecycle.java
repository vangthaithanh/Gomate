package db.migration;

import java.util.Locale;
import org.flywaydb.core.api.migration.BaseJavaMigration;
import org.flywaydb.core.api.migration.Context;

/** CLOSED group chats retain history but no longer own an active Trip link. */
public class V13__group_conversation_lifecycle extends BaseJavaMigration {
 @Override public void migrate(Context context) throws Exception {
  var connection=context.getConnection();
  boolean h2=connection.getMetaData().getDatabaseProductName().toLowerCase(Locale.ROOT).contains("h2");
  try(var statement=connection.createStatement()) {
   statement.execute("ALTER TABLE conversations DROP CONSTRAINT uq_conversations_linked_trip");
   statement.execute("ALTER TABLE conversations DROP CONSTRAINT ck_conversations_direct_shape");
   statement.execute("""
    ALTER TABLE conversations ADD CONSTRAINT ck_conversations_direct_shape CHECK (
     (type='DIRECT' AND linked_trip_id IS NULL
      AND requester_id IS NOT NULL AND recipient_id IS NOT NULL
      AND user_low_id IS NOT NULL AND user_high_id IS NOT NULL
      AND requester_id<>recipient_id AND user_low_id<>user_high_id)
     OR
     (type='GROUP' AND linked_trip_id IS NOT NULL
      AND requester_id IS NULL AND recipient_id IS NULL
      AND user_low_id IS NULL AND user_high_id IS NULL
      AND status IN ('ACCEPTED','CLOSED'))
    )
    """);
   if(h2) {
    // H2 has no PostgreSQL partial indexes; a generated null key is equivalent.
    statement.execute("""
     ALTER TABLE conversations ADD COLUMN active_linked_trip_id UUID
     GENERATED ALWAYS AS (CASE WHEN type='GROUP' AND status='ACCEPTED' THEN linked_trip_id ELSE NULL END)
     """);
    statement.execute("CREATE UNIQUE INDEX uq_conversations_active_linked_trip ON conversations(active_linked_trip_id)");
   } else {
    statement.execute("""
     CREATE UNIQUE INDEX uq_conversations_active_linked_trip ON conversations(linked_trip_id)
     WHERE type='GROUP' AND status='ACCEPTED'
     """);
   }
  }
 }
}

package db.migration;

import java.util.ArrayList;
import java.util.UUID;
import org.flywaydb.core.api.migration.BaseJavaMigration;
import org.flywaydb.core.api.migration.Context;

/** Removes superseded journey/share state; keeps deletion and membership separate. */
public class V16__trip_pin_centric_reset extends BaseJavaMigration {
 @Override public void migrate(Context context) throws Exception {
  var connection=context.getConnection();
  var chats=new ArrayList<UUID>();
  try(var statement=connection.createStatement();
      var rows=statement.executeQuery("""
       SELECT t.id,
        (SELECT c.id FROM conversations c WHERE c.linked_trip_id=t.id AND c.type='GROUP' AND c.status='CLOSED'
         ORDER BY c.created_at DESC,c.id DESC LIMIT 1) AS chat_id
       FROM trips t
       WHERE t.archived_at IS NULL AND t.trip_type='GROUP' AND t.status IN ('COMPLETED','CANCELLED')
        AND NOT EXISTS (SELECT 1 FROM conversations c WHERE c.linked_trip_id=t.id AND c.type='GROUP' AND c.status='ACCEPTED')
       """)) {
   while(rows.next()) {
    UUID chat=rows.getObject("chat_id",UUID.class);
    if(chat==null) throw new IllegalStateException("Terminal non-deleted group has no retained chat: "+rows.getObject("id"));
    chats.add(chat);
   }
  }
  // User approved reopening these same retained chats, never creating chats/pins.
  try(var update=connection.prepareStatement("UPDATE conversations SET status='ACCEPTED' WHERE id=? AND status='CLOSED'")) {
   for(UUID chat:chats) { update.setObject(1,chat); update.executeUpdate(); }
  }
  try(var statement=connection.createStatement()) {
   statement.execute("DROP INDEX IF EXISTS ix_trips_owner_status");
   statement.execute("ALTER TABLE trips DROP COLUMN status");
   statement.execute("ALTER TABLE trips DROP COLUMN started_at");
   statement.execute("ALTER TABLE trips DROP COLUMN completed_at");
   statement.execute("ALTER TABLE trip_members DROP COLUMN location_sharing_enabled");
   statement.execute("ALTER TABLE trip_members DROP COLUMN location_sharing_updated_at");
   statement.execute("CREATE INDEX ix_trips_owner_created ON trips(owner_id,created_at)");
  }
 }
}

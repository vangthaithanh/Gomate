package db.migration;

import org.flywaydb.core.api.migration.BaseJavaMigration;
import org.flywaydb.core.api.migration.Context;

/** Promote legacy DIRECT flags without changing any chat/history or old flag. */
public class V26__global_user_blocks extends BaseJavaMigration {
 @Override public Integer getChecksum() { return 26001; }
 @Override public void migrate(Context context) throws Exception {
  try(var sql=context.getConnection().createStatement()) {
   sql.execute("""
    CREATE TABLE user_blocks (
     blocker_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
     blocked_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
     created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP,
     PRIMARY KEY(blocker_user_id,blocked_user_id),
     CHECK(blocker_user_id<>blocked_user_id)
    )
    """);
   sql.execute("CREATE INDEX ix_user_blocks_reverse ON user_blocks(blocked_user_id,blocker_user_id)");
   sql.execute("""
    INSERT INTO user_blocks(blocker_user_id,blocked_user_id)
    SELECT DISTINCT cm.user_id,CASE WHEN cm.user_id=c.user_low_id THEN c.user_high_id ELSE c.user_low_id END
    FROM conversation_members cm JOIN conversations c ON c.id=cm.conversation_id
    WHERE cm.blocked=TRUE AND c.type='DIRECT'
     AND cm.user_id IN (c.user_low_id,c.user_high_id) AND c.user_low_id<>c.user_high_id
    ON CONFLICT DO NOTHING
    """);
   sql.execute("""
    DELETE FROM user_follows WHERE EXISTS (SELECT 1 FROM user_blocks b
     WHERE (b.blocker_user_id=follower_user_id AND b.blocked_user_id=followed_user_id)
        OR (b.blocker_user_id=followed_user_id AND b.blocked_user_id=follower_user_id))
    """);
   sql.execute("""
    UPDATE follow_requests SET status='CANCELLED',responded_at=CURRENT_TIMESTAMP
    WHERE status='PENDING' AND EXISTS (SELECT 1 FROM user_blocks b
     WHERE (b.blocker_user_id=requester_id AND b.blocked_user_id=target_id)
        OR (b.blocker_user_id=target_id AND b.blocked_user_id=requester_id))
    """);
  }
 }
}

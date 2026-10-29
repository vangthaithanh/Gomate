package vn.gomate.relationship.block;

import java.util.*;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import vn.gomate.common.ApiException;
import vn.gomate.common.Db;
import static vn.gomate.common.Db.args;

@Service
public class GlobalBlockService {
 public record Changed(UUID actor,UUID target) {}
 private final Db db;
 private final GlobalBlockPolicy policy;
 private final ApplicationEventPublisher events;
 public GlobalBlockService(Db db,GlobalBlockPolicy policy,ApplicationEventPublisher events) {
  this.db=db;this.policy=policy;this.events=events;
 }
 @Transactional public Map<String,Object> set(UUID actor,UUID target,boolean value) {
  if(actor.equals(target)) throw new ApiException(400,"SELF_BLOCK_NOT_ALLOWED","Không thể chặn chính mình.");
  if(db.count("SELECT COUNT(*) FROM users WHERE id=:id"+(value?" AND status='ACTIVE'":""),args("id",target))!=1) throw ApiException.notFound();
  policy.lockPair(actor,target);
  if(value && db.count("SELECT COUNT(*) FROM users WHERE id=:id AND status='ACTIVE'",args("id",target))!=1) throw ApiException.notFound();
  int changed;
  if(value) {
   changed=db.update("INSERT INTO user_blocks(blocker_user_id,blocked_user_id) VALUES(:a,:b) ON CONFLICT DO NOTHING",args("a",actor,"b",target));
   db.update("DELETE FROM user_follows WHERE (follower_user_id=:a AND followed_user_id=:b) OR (follower_user_id=:b AND followed_user_id=:a)",args("a",actor,"b",target));
   db.update("UPDATE follow_requests SET status='CANCELLED',responded_at=CURRENT_TIMESTAMP WHERE status='PENDING' AND ((requester_id=:a AND target_id=:b) OR (requester_id=:b AND target_id=:a))",args("a",actor,"b",target));
  } else changed=db.update("DELETE FROM user_blocks WHERE blocker_user_id=:a AND blocked_user_id=:b",args("a",actor,"b",target));
  if(changed>0) events.publishEvent(new Changed(actor,target));
  return Map.of("userId",target,"isBlockedByMe",policy.byMe(actor,target),"canInteract",!policy.either(actor,target));
 }
 public Map<String,Object> list(UUID actor,int page,int size) {
  int safePage=Math.max(0,Math.min(page,Integer.MAX_VALUE/50)),safeSize=Math.max(1,Math.min(size,50));
  var rows=db.list("""
   SELECT b.blocked_user_id AS user_id,b.created_at AS blocked_at,p.nickname,
    COALESCE(p.full_name,p.nickname) AS display_name,p.avatar_url
   FROM user_blocks b JOIN user_profiles p ON p.user_id=b.blocked_user_id
   WHERE b.blocker_user_id=:actor ORDER BY b.created_at DESC,b.blocked_user_id LIMIT :size OFFSET :offset
   """,args("actor",actor,"size",safeSize,"offset",safePage*safeSize));
  return Map.of("items",rows,"page",safePage,"size",safeSize,"total",db.count("SELECT COUNT(*) FROM user_blocks WHERE blocker_user_id=:id",args("id",actor)));
 }
}

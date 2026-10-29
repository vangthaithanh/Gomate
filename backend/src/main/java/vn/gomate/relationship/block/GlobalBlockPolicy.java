package vn.gomate.relationship.block;

import java.util.*;
import org.springframework.stereotype.Service;
import vn.gomate.common.ApiException;
import vn.gomate.common.Db;
import static vn.gomate.common.Db.args;

/** Single PostgreSQL authority. Never reads conversation_members.blocked. */
@Service
public class GlobalBlockPolicy {
 private final Db db;
 public GlobalBlockPolicy(Db db) {this.db=db;}
 // Expressions are repository-owned SQL, never user input.
 public static String allowed(String a,String b) {
  return "NOT EXISTS (SELECT 1 FROM user_blocks gb WHERE (gb.blocker_user_id="+a+" AND gb.blocked_user_id="+b+") OR (gb.blocker_user_id="+b+" AND gb.blocked_user_id="+a+"))";
 }
 public boolean byMe(UUID actor,UUID target) {
  if(actor==null || target==null || actor.equals(target)) return false;
  return db.count("SELECT COUNT(*) FROM user_blocks WHERE blocker_user_id=:a AND blocked_user_id=:b",args("a",actor,"b",target))>0;
 }
 public boolean either(UUID a,UUID b) {
  if(a==null || b==null || a.equals(b)) return false;
  return db.count("SELECT COUNT(*) FROM user_blocks WHERE (blocker_user_id=:a AND blocked_user_id=:b) OR (blocker_user_id=:b AND blocked_user_id=:a)",args("a",a,"b",b))>0;
 }
 public void requireAllowed(UUID a,UUID b) {if(either(a,b)) throw ApiException.notFound();}
 public void lockPair(UUID a,UUID b) {
  UUID low=a.compareTo(b)<0?a:b,high=a.compareTo(b)<0?b:a;
  db.one("SELECT user_id FROM user_settings WHERE user_id=:id FOR UPDATE",args("id",low));
  if(!low.equals(high)) db.one("SELECT user_id FROM user_settings WHERE user_id=:id FOR UPDATE",args("id",high));
 }
 public void lockUsers(Collection<UUID> users) {
  for(UUID id:users.stream().distinct().sorted().toList())
   db.one("SELECT user_id FROM user_settings WHERE user_id=:id FOR UPDATE",args("id",id));
 }
 public Set<UUID> ownBlocked(UUID viewer,Collection<UUID> candidates) {
  if(candidates.isEmpty()) return Set.of();
  var result=new HashSet<UUID>();
  for(var row:db.list("SELECT blocked_user_id FROM user_blocks WHERE blocker_user_id=:viewer AND blocked_user_id IN (:ids)",args("viewer",viewer,"ids",candidates))) result.add((UUID)row.get("blockedUserId"));
  return result;
 }
 public Set<UUID> hidden(UUID viewer,Collection<UUID> candidates) {
  if(candidates.isEmpty()) return Set.of();
  var rows=db.list("""
   SELECT CASE WHEN blocker_user_id=:viewer THEN blocked_user_id ELSE blocker_user_id END AS hidden_id
   FROM user_blocks WHERE (blocker_user_id=:viewer AND blocked_user_id IN (:ids))
    OR (blocked_user_id=:viewer AND blocker_user_id IN (:ids))
   """,args("viewer",viewer,"ids",candidates));
  var result=new HashSet<UUID>();for(var r:rows) result.add((UUID)r.get("hiddenId"));return result;
 }
}

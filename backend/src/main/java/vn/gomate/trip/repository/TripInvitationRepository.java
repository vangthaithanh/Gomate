package vn.gomate.trip.repository;

import java.util.*;
import org.springframework.stereotype.Repository;
import vn.gomate.common.Db;
import static vn.gomate.common.Db.args;

@Repository
public class TripInvitationRepository {
 private final Db db;

 public TripInvitationRepository(Db db) {
  this.db=db;
 }

 public void insert(UUID id,UUID tripId,UUID inviterUserId,UUID inviteeUserId) {
  db.update("""
   INSERT INTO trip_invitations(id,trip_id,inviter_user_id,invitee_user_id,status)
   VALUES(:id,:tripId,:inviterUserId,:inviteeUserId,'PENDING')
   """,args("id",id,"tripId",tripId,"inviterUserId",inviterUserId,"inviteeUserId",inviteeUserId));
 }

 public Optional<Map<String,Object>> pending(UUID tripId,UUID inviteeUserId) {
  return rows("""
   WHERE ti.trip_id=:tripId AND ti.invitee_user_id=:inviteeUserId AND ti.status='PENDING'
   """,args("tripId",tripId,"inviteeUserId",inviteeUserId)).stream().findFirst();
 }

 public Optional<Map<String,Object>> byId(UUID invitationId) {
  return rows("WHERE ti.id=:invitationId",args("invitationId",invitationId)).stream().findFirst();
 }

 public Optional<Map<String,Object>> forUpdate(UUID invitationId) {
  return db.list("""
   SELECT id,trip_id,inviter_user_id,invitee_user_id,status,created_at,responded_at,updated_at
   FROM trip_invitations
   WHERE id=:invitationId
   FOR UPDATE
   """,args("invitationId",invitationId)).stream().findFirst();
 }

 public List<Map<String,Object>> incoming(UUID inviteeUserId,String status) {
  if(status==null || status.isBlank()) {
   return rows("""
    WHERE ti.invitee_user_id=:inviteeUserId
    ORDER BY ti.created_at DESC,ti.id
    """,args("inviteeUserId",inviteeUserId));
  }
  return rows("""
   WHERE ti.invitee_user_id=:inviteeUserId AND ti.status=:status
   ORDER BY ti.created_at DESC,ti.id
   """,args("inviteeUserId",inviteeUserId,"status",status));
 }

 public void markResponded(UUID invitationId,String status) {
  db.update("""
   UPDATE trip_invitations
   SET status=:status,responded_at=COALESCE(responded_at,CURRENT_TIMESTAMP),updated_at=CURRENT_TIMESTAMP
   WHERE id=:invitationId
   """,args("invitationId",invitationId,"status",status));
 }

 public List<Map<String,Object>> pendingForTrip(UUID tripId) {
  return rows("WHERE ti.trip_id=:tripId AND ti.status='PENDING' ORDER BY ti.created_at,ti.id",args("tripId",tripId));
 }

 public List<Map<String,Object>> allForTrip(UUID tripId) {
  return rows("WHERE ti.trip_id=:tripId ORDER BY ti.id",args("tripId",tripId));
 }

 public void markCancelled(UUID invitationId) {
  db.update("""
   UPDATE trip_invitations SET status='CANCELLED',updated_at=CURRENT_TIMESTAMP
   WHERE id=:invitationId AND status='PENDING'
   """,args("invitationId",invitationId));
 }

 private List<Map<String,Object>> rows(String whereSql,Map<String,Object> params) {
  return db.list("""
   SELECT ti.id AS invitation_id,
          ti.trip_id,
          t.title AS trip_title,
          ti.inviter_user_id,
          CASE WHEN up.full_name IS NULL OR up.full_name='' THEN up.nickname ELSE up.full_name END AS inviter_display_name,
          up.avatar_url AS inviter_avatar_url,
          ti.invitee_user_id,
          COALESCE(NULLIF(invitee.full_name,''),invitee.nickname) AS invitee_display_name,
          invitee.avatar_url AS invitee_avatar_url,
          ti.status,
          ti.created_at,
          ti.responded_at
   FROM trip_invitations ti
   JOIN trips t ON t.id=ti.trip_id
   JOIN users u ON u.id=ti.inviter_user_id
   JOIN user_profiles up ON up.user_id=u.id
   JOIN user_profiles invitee ON invitee.user_id=ti.invitee_user_id
   """+whereSql,params);
 }
}

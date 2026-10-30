package vn.gomate.place.review;

import java.util.*;
import org.springframework.stereotype.Repository;
import vn.gomate.common.*;
import vn.gomate.relationship.block.GlobalBlockPolicy;
import static vn.gomate.common.Db.args;

@Repository
public class PlaceReviewRepository {
 private final Db db;
 public PlaceReviewRepository(Db db) {this.db=db;}
 public void activeActor(UUID actor) {
  var row=db.one("SELECT status FROM users WHERE id=:id FOR UPDATE",args("id",actor));
  if(!"ACTIVE".equals(row.get("status"))) throw new ApiException(403,"ACCOUNT_INACTIVE","Tài khoản không được đánh giá.");
 }
 public void lockPlace(long place) {
  var row=db.one("SELECT status,category_id FROM places WHERE id=:id FOR UPDATE",args("id",place));
  if(!"ACTIVE".equals(row.get("status")) || db.count("SELECT COUNT(*) FROM place_categories WHERE id=:id AND active=TRUE",args("id",row.get("categoryId")))==0) throw ApiException.notFound();
 }
 public void publicPlace(long place) {
  if(db.count("SELECT COUNT(*) FROM places p JOIN place_categories c ON c.id=p.category_id WHERE p.id=:id AND p.status='ACTIVE' AND c.active=TRUE",args("id",place))==0) throw ApiException.notFound();
 }
 public Map<String,Object> review(long id) {return db.one("SELECT * FROM reviews WHERE id=:id",args("id",id));}
 public Map<String,Object> mine(UUID actor,long place) {
  return db.list("SELECT * FROM reviews WHERE user_id=:user AND place_id=:place AND publication_status='ACTIVE'",args("user",actor,"place",place)).stream().findFirst().orElse(null);
 }
 public long create(UUID actor,long place,int rating,String content) {
  db.update("INSERT INTO reviews(user_id,place_id,rating,content) VALUES(:user,:place,:rating,:content)",args("user",actor,"place",place,"rating",rating,"content",content));
  return ((Number)mine(actor,place).get("id")).longValue();
 }
 public void update(long id,int rating,String content) {
  db.update("UPDATE reviews SET rating=:rating,content=:content,updated_at=CURRENT_TIMESTAMP WHERE id=:id",args("id",id,"rating",rating,"content",content));
 }
 public void delete(long id) {db.update("UPDATE reviews SET publication_status='DELETED',updated_at=CURRENT_TIMESTAMP WHERE id=:id AND publication_status='ACTIVE'",args("id",id));}
 // All mutations serialize on the same places row. Cache and review commit together.
 public void aggregate(long place) {
  db.update("""
   UPDATE places SET avg_rating=COALESCE((SELECT CAST(AVG(CAST(rating AS NUMERIC(10,2))) AS NUMERIC(3,2)) FROM reviews WHERE place_id=:id AND publication_status='ACTIVE' AND moderation_status='VISIBLE'),0),
    review_count=(SELECT COUNT(*) FROM reviews WHERE place_id=:id AND publication_status='ACTIVE' AND moderation_status='VISIBLE') WHERE id=:id
   """,args("id",place));
 }
 public Map<String,Object> stats(long place) {return db.one("SELECT id AS place_id,avg_rating,review_count FROM places WHERE id=:id",args("id",place));}
 public List<Map<String,Object>> page(UUID viewer,long place,int size,long before,String sort) {
  String cursor="r.id<:before",order="r.id DESC";
  if(!sort.equals("newest")) {
   String compare=sort.equals("highest")?"<":">";
   cursor="(:before=9223372036854775807 OR r.rating "+compare+" (SELECT rating FROM reviews WHERE id=:before AND place_id=:place) OR (r.rating=(SELECT rating FROM reviews WHERE id=:before AND place_id=:place) AND r.id<:before))";
   order="r.rating "+(sort.equals("highest")?"DESC":"ASC")+",r.id DESC";
  }
  return db.list("""
   SELECT r.id,r.place_id,r.rating,r.content,r.created_at,r.updated_at,r.user_id,
    COALESCE(NULLIF(TRIM(up.full_name),''),up.nickname) AS display_name,up.avatar_url
   FROM reviews r JOIN users u ON u.id=r.user_id JOIN user_profiles up ON up.user_id=r.user_id
   WHERE r.place_id=:place AND r.publication_status='ACTIVE' AND r.moderation_status='VISIBLE' AND u.status='ACTIVE'
    AND
   """+cursor+" AND "+GlobalBlockPolicy.allowed(":viewer","r.user_id")+" ORDER BY "+order+" LIMIT :size",args("viewer",viewer,"place",place,"before",before,"size",size));
 }
}

package vn.gomate.social.report;
import java.util.*;
import org.springframework.stereotype.Repository;
import vn.gomate.common.Db;
import static vn.gomate.common.Db.args;
@Repository
public class PostReportRepository {
 private final Db db;
 public PostReportRepository(Db db) {this.db=db;}
 public Map<String,Object> insert(UUID actor,long post,PostReportService.Create req,String hash,String description) {
  db.update("INSERT INTO post_reports(id,reporter_id,post_id,client_request_id,request_hash,reason_code,details) VALUES(:id,:actor,:post,:key,:hash,:reason,:details) ON CONFLICT DO NOTHING",args("id",UUID.randomUUID(),"actor",actor,"post",post,"key",req.clientRequestId(),"hash",hash,"reason",req.reasonCode(),"details",description));
  return db.one("SELECT * FROM post_reports WHERE reporter_id=:actor AND client_request_id=:key",args("actor",actor,"key",req.clientRequestId()));
 }
 public Map<String,Object> detail(UUID actor,UUID id) {return db.one("SELECT * FROM post_reports WHERE id=:id AND reporter_id=:actor",args("id",id,"actor",actor));}
 public List<Map<String,Object>> page(UUID actor,int limit,PostReportService.Cursor cursor) {
  var params=args("actor",actor,"limit",limit);String after="";
  if(cursor!=null) {params.putAll(args("time",cursor.created(),"id",cursor.id()));after=" AND (created_at<:time OR (created_at=:time AND id<:id))";}
  return db.list("SELECT * FROM post_reports WHERE reporter_id=:actor"+after+" ORDER BY created_at DESC,id DESC LIMIT :limit",params);
 }
}

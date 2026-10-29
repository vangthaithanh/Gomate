package vn.gomate;

import com.mongodb.client.MongoClients;
import java.util.*;
import java.util.concurrent.*;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.data.mongodb.core.MongoTemplate;
import vn.gomate.common.ApiException;
import vn.gomate.message.service.MessageMongoService;
import static org.junit.jupiter.api.Assertions.*;

@EnabledIfEnvironmentVariable(named="GOMATE_P4_REAL_MONGO",matches="true")
class DirectMessageMongoTest {
 @Test void concurrentRetryRestartConflictAndScopedCompensation() throws Exception {
  String db="gomate_dm_verify_"+UUID.randomUUID().toString().replace("-","");
  try(var client=MongoClients.create(com.mongodb.MongoClientSettings.builder()
   .applyConnectionString(new com.mongodb.ConnectionString(System.getenv("GOMATE_P4_MONGO_URI")))
   .uuidRepresentation(org.bson.UuidRepresentation.JAVA_LEGACY).build())) {
   var messages=new MessageMongoService(new MongoTemplate(client,db));
   var pool=Executors.newFixedThreadPool(6);
   UUID chat=UUID.randomUUID(),sender=UUID.randomUUID(),key=UUID.randomUUID();String scope="DIRECT:"+UUID.randomUUID();
   try {
    var work=new ArrayList<Callable<String>>();
    for(int i=0;i<12;i++) work.add(()->messages.saveText(chat,sender,"Hello",Map.of("b",2,"a",1),key,scope).messageId());
    var ids=new HashSet<String>();for(var task:pool.invokeAll(work)) ids.add(task.get());
    assertEquals(1,ids.size());assertEquals(1,messages.count(chat));
    var restarted=new MessageMongoService(new MongoTemplate(client,db));
    assertEquals(ids.iterator().next(),restarted.saveText(chat,sender,"Hello",Map.of("a",1,"b",2),key,scope).messageId());
    assertEquals(409,assertThrows(ApiException.class,()->restarted.saveText(chat,sender,"Changed",null,key,scope)).status);
    assertEquals(Map.of("a",1,"b",2),restarted.list(chat,20,null).get(0).context());
    assertFalse(restarted.list(chat,20,null).get(0).toString().contains("requestHash"));
    restarted.removeUncommitted(ids.iterator().next(),chat,UUID.randomUUID());assertEquals(1,restarted.count(chat));
    UUID replacement=UUID.randomUUID();
    String hash=MessageMongoService.textRequestHash("Hello",Map.of("a",1,"b",2));
    restarted.rebindOrphan(ids.iterator().next(),replacement,old->true,hash);assertEquals(1,restarted.count(chat));
    assertThrows(ApiException.class,()->restarted.rebindOrphan(ids.iterator().next(),replacement,old->false,"wrong"));
    assertEquals(1,restarted.count(chat));
    restarted.rebindOrphan(ids.iterator().next(),replacement,old->false,hash);assertEquals(0,restarted.count(chat));
    assertEquals(ids.iterator().next(),restarted.saveText(replacement,sender,"Hello",Map.of("a",1,"b",2),key,scope).messageId());
    restarted.removeUncommitted(ids.iterator().next(),replacement,sender);assertEquals(0,restarted.count(replacement));
   } finally {pool.shutdownNow();client.getDatabase(db).drop();}
  }
 }
}

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

/** Explicitly opt in against a dedicated scratch database, never the app database. */
@EnabledIfEnvironmentVariable(named="GOMATE_P4_REAL_MONGO",matches="true")
class PostShareMongoTest {
    @Test void durableConcurrentRetryLostAckAndConflictingPayload() throws Exception {
        String name="gomate_p4_share_verify_"+UUID.randomUUID().toString().replace("-","");
        try(var client=MongoClients.create(com.mongodb.MongoClientSettings.builder()
            .applyConnectionString(new com.mongodb.ConnectionString(System.getenv("GOMATE_P4_MONGO_URI")))
            .uuidRepresentation(org.bson.UuidRepresentation.JAVA_LEGACY).build())) {
            var mongo=new MongoTemplate(client,name);
            var messages=new MessageMongoService(mongo);
            UUID chat=UUID.randomUUID(),user=UUID.randomUUID(),request=UUID.randomUUID();
            var pool=Executors.newFixedThreadPool(6);
            try {
                var work=new ArrayList<Callable<String>>();
                for(int i=0;i<12;i++) work.add(()->messages.savePostReference(chat,user,42,request,"USER:recipient","hello").messageId());
                var ids=new HashSet<String>();
                for(var task:pool.invokeAll(work)) ids.add(task.get());
                assertEquals(1,ids.size());assertEquals(1,messages.count(chat));
                var afterRestart=new MessageMongoService(new MongoTemplate(client,name));
                assertEquals(ids.iterator().next(),afterRestart.savePostReference(chat,user,42,request,"USER:recipient","hello").messageId());
                var read=afterRestart.list(chat,20,null).get(0);
                assertEquals(Map.of("postId",42L),read.context());assertEquals("POST_SHARE",read.type());
                var error=assertThrows(ApiException.class,()->afterRestart.savePostReference(chat,user,43,request,"USER:recipient","hello"));
                assertEquals(409,error.status);assertEquals(1,messages.count(chat));
                assertFalse(read.toString().contains("cloudinary"));assertFalse(read.toString().contains("requestHash"));
            } finally {
                pool.shutdownNow();
                client.getDatabase(name).drop();
            }
        }
    }
}

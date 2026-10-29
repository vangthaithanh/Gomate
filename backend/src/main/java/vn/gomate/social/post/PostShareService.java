package vn.gomate.social.post;

import java.util.*;
import org.springframework.stereotype.Service;
import vn.gomate.common.ApiException;
import vn.gomate.message.service.ConversationService;
import static vn.gomate.social.post.PostShareDtos.*;

@Service
public class PostShareService {
    private final ConversationService conversations;
    private final PostService posts;
    public PostShareService(ConversationService conversations,PostService posts) {this.conversations=conversations;this.posts=posts;}
    public List<Map<String,Object>> targets(UUID viewer,long postId,String query) {return conversations.shareTargets(viewer,postId,query);}
    public List<Result> send(UUID viewer,long postId,Share request) {
        posts.authorize(viewer,postId);
        if(new HashSet<>(request.targets()).size()!=request.targets().size()) throw ApiException.bad("Đích gửi bị trùng.");
        var results=new ArrayList<Result>();
        for(var target:request.targets()) try {
            conversations.preparePostShare(viewer,postId,target.type(),target.targetId());
            var message=conversations.sharePost(viewer,postId,target.type(),target.targetId(),request.clientRequestId(),request.message()==null?"":request.message().trim());
            results.add(new Result(target.type(),target.targetId(),true,message.messageId(),null,null));
        } catch(ApiException e) {results.add(new Result(target.type(),target.targetId(),false,null,e.code,e.getMessage()));}
        catch(org.springframework.dao.DataAccessException e) {results.add(new Result(target.type(),target.targetId(),false,null,"SHARE_RETRY_REQUIRED","Chưa xác nhận được đích gửi. Hãy thử lại."));}
        return results;

    }
}

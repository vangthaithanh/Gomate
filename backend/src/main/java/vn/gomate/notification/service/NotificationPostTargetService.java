package vn.gomate.notification.service;

import java.util.UUID;
import org.springframework.stereotype.Service;
import vn.gomate.common.ApiException;
import vn.gomate.notification.dto.NotificationDtos;
import vn.gomate.social.comment.CommentService;
import vn.gomate.social.post.PostService;

/** A notification is a reference, never a grant of access to its content. */
@Service
public class NotificationPostTargetService {
 private final NotificationService inbox;
 private final PostService posts;
 private final CommentService comments;
 public NotificationPostTargetService(NotificationService inbox,PostService posts,CommentService comments) {
  this.inbox=inbox;this.posts=posts;this.comments=comments;
 }
 public NotificationDtos.PostTarget resolve(UUID viewer,UUID id) {
  var notice=inbox.detail(viewer,id);
  if(notice.postId()==null) throw ApiException.notFound();
  posts.authorize(viewer,notice.postId());
  Long root=null;boolean available=false;
  if(notice.commentId()!=null) {
   try {
    var comment=comments.authorize(viewer,notice.commentId());
    if(((Number)comment.get("postId")).longValue()!=notice.postId()) throw ApiException.notFound();
    root=comment.get("parentCommentId")==null?notice.commentId():((Number)comment.get("parentCommentId")).longValue();
    available=true;
   } catch(ApiException missing) {
    if(missing.status!=404) throw missing;
   }
  }
  posts.authorize(viewer,notice.postId());
  return new NotificationDtos.PostTarget(notice.postId(),notice.commentId(),root,available);
 }
}

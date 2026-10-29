package vn.gomate.social.comment;

import java.util.*;
import jakarta.validation.constraints.*;

public final class CommentDtos {
 private CommentDtos() {}
 public record Create(@NotNull UUID clientRequestId,@NotNull String body,Long parentId,@NotNull @Size(max=6) List<@NotNull UUID> mediaIds) {}
 public record Page(List<Map<String,Object>> items,String nextCursor) {}
}

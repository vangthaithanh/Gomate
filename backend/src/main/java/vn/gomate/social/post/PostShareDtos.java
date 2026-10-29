package vn.gomate.social.post;

import java.util.*;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;

public final class PostShareDtos {
    private PostShareDtos() {}
    public record Target(@NotBlank String type,@NotNull UUID targetId) {}
    public record Share(@NotNull UUID clientRequestId,@NotNull @Size(min=1,max=50) List<@Valid @NotNull Target> targets,@Size(max=4000) String message) {}
    public record Result(String type,UUID targetId,boolean success,String messageId,String code,String message) {}
}

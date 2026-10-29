package vn.gomate.media.dto;

import vn.gomate.media.model.MediaResourceType;

public record MediaUploadResult(
    String secureUrl,
    String publicId,
    MediaResourceType resourceType,
    String format,
    Integer width,
    Integer height,
    Long bytes,
    Double durationSeconds
) {}

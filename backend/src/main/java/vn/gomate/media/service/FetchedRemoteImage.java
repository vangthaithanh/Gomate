package vn.gomate.media.service;

public record FetchedRemoteImage(
    byte[] bytes,
    String contentType,
    String sourceUrl
) {}

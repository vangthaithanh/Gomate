String cloudinaryMapThumbnailUrl(String url) {
  return _cloudinaryVariant(url, 'f_auto,q_auto,w_180,h_180,c_fill');
}

String cloudinaryPlaceHeroUrl(String url) {
  return _cloudinaryVariant(url, 'f_auto,q_auto,w_1080,c_limit');
}

String _cloudinaryVariant(String url, String transformation) {
  const marker = '/image/upload/';
  if (!url.contains('res.cloudinary.com') || !url.contains(marker)) {
    return url;
  }

  final markerIndex = url.indexOf(marker);
  final afterUpload = url.substring(markerIndex + marker.length);
  if (!afterUpload.startsWith('v')) {
    return url;
  }

  return url.replaceFirst(marker, '$marker$transformation/');
}

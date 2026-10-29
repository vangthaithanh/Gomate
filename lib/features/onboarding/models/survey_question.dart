class SurveyQuestion {
  final String title;

  // Ảnh mặc định khi chưa có option có ảnh nào được chọn
  final String defaultImage;

  final List<String> options;

  // Option nào có ảnh thì khai báo ở đây.
  // "Khác" không khai báo => không ảnh.
  final Map<String, String> optionImages;

  const SurveyQuestion({
    required this.title,
    required this.defaultImage,
    required this.options,
    required this.optionImages,
  });
}
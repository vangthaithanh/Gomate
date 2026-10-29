import 'package:unorm_dart/unorm_dart.dart' as unicode;

enum GoMatePostAudience {
  everyone('Mọi người'),
  followers('Người theo dõi'),
  friends('Bạn bè'),
  onlyMe('Chỉ mình tôi');

  const GoMatePostAudience(this.label);
  final String label;
}

/// Selection metadata only; PostVideoExporter must produce the actual clip.
class GoMatePostTrimRange {
  final int startMs;
  final int endMs;
  const GoMatePostTrimRange({required this.startMs, required this.endMs});
  int get durationMs => endMs - startMs;
}

/// Mirrors Spring's NFC, leading-# removal and case-insensitive identity.
String normalizePostHashtag(String raw) =>
    unicode.nfc(raw.trim()).replaceFirst(RegExp(r'^#+'), '').toLowerCase();

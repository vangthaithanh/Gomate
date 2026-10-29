import 'package:flutter/material.dart';
import 'package:flutter_twemoji/flutter_twemoji.dart';

enum GoMateEmojiType {
  heart('❤️'),
  laugh('😂'),
  wow('😮'),
  fire('🔥'),
  clap('👏'),
  loveEyes('😍'),
  sad('😢'),
  angry('😡');

  final String symbol;

  const GoMateEmojiType(this.symbol);
}

class GoMateEmojiIcon extends StatelessWidget {
  final GoMateEmojiType emoji;
  final double size;

  const GoMateEmojiIcon({
    super.key,
    required this.emoji,
    this.size = 22,
  });

  @override
  Widget build(BuildContext context) {
    return Twemoji(
      emoji: emoji.symbol,
      width: size,
      height: size,
    );
  }
}

class GoMateEmojiCatalog {
  const GoMateEmojiCatalog._();

  static const List<GoMateEmojiType> defaults = [
    GoMateEmojiType.heart,
    GoMateEmojiType.laugh,
    GoMateEmojiType.wow,
  ];

  static const List<GoMateEmojiType> all = GoMateEmojiType.values;
}

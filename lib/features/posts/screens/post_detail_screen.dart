import 'package:flutter/material.dart';
import '../../profile/screens/profile_post_feed_screen.dart';
import '../data/post_repository.dart';

/// Publish and Profile use the same approved GoMate viewer.
class PostDetailScreen extends StatelessWidget {
  final int postId;
  final PostRepository? repository;
  const PostDetailScreen({super.key, required this.postId, this.repository});
  @override
  Widget build(BuildContext context) => GoMateProfilePostFeedScreen(
    posts: const [],
    postId: postId,
    remote: true,
    repository: repository,
  );
}

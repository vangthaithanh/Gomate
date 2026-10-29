import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/network/api_exception.dart';
import '../models/post_compose_models.dart';
import 'post_interaction_changes.dart';

String newPostRequestId() {
  final r = Random.secure();
  final bytes = List.generate(16, (_) => r.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

class PostRepository {
  final AuthService auth;
  PostRepository({AuthService? auth}) : auth = auth ?? AuthService.instance;
  Future<Map<String, dynamic>> upload(String path, String kind, String id) =>
      auth.multipartRequest(
        '/posts/media',
        fileField: 'file',
        filePath: path,
        fields: {'kind': kind, 'uploadId': id},
        timeout: const Duration(minutes: 3),
      );
  Future<Map<String, dynamic>> publish(Map<String, dynamic> body) =>
      auth.request('POST', '/posts', body: body);
  Future<Map<String, dynamic>> feed({String? cursor}) => auth.request(
    'GET',
    '/feed?size=20${cursor == null ? '' : '&cursor=${Uri.encodeQueryComponent(cursor)}'}',
  );
  Future<Map<String, dynamic>> engagement(
    int id,
    String kind,
    bool value,
  ) async {
    if (kind != 'like' && kind != 'save') throw ArgumentError.value(kind);
    final actor = auth.user?['id'];
    final result = await auth.request(
      value ? 'PUT' : 'DELETE',
      '/posts/$id/$kind',
    );
    if (actor == null || actor != auth.user?['id']) {
      throw StateError('Tài khoản đã thay đổi');
    }
    PostInteractionChanges.acknowledged(
      PostInteractionChange(
        auth: auth,
        actor: actor,
        postId: id,
        kind: kind,
        engagement: result,
        removed: !value,
      ),
    );
    return result;
  }

  Future<Map<String, dynamic>> report(
    int id,
    String key,
    String reason,
    String description,
  ) => auth.request(
    'POST',
    '/posts/$id/reports',
    body: {
      'clientRequestId': key,
      'reasonCode': reason,
      'description': description,
    },
  );
  Future<Map<String, dynamic>> reports({String? cursor}) => auth.request(
    'GET',
    '/me/reports${cursor == null ? '' : '?cursor=${Uri.encodeQueryComponent(cursor)}'}',
  );
  Future<Map<String, dynamic>> detail(int id) =>
      auth.request('GET', '/posts/$id');
  Future<Map<String, dynamic>> likers(int id, {String? cursor}) async {
    final actor = auth.user?['id'];
    final result = await auth.request(
      'GET',
      '/posts/$id/likes?size=20${cursor == null ? '' : '&cursor=${Uri.encodeQueryComponent(cursor)}'}',
    );
    if (actor == null || actor != auth.user?['id']) {
      throw StateError('Tài khoản đã thay đổi');
    }
    return result;
  }

  Future<Map<String, dynamic>> activity(String kind, {String? cursor}) {
    if (!const ['liked-posts', 'saved-posts', 'comments'].contains(kind)) {
      throw ArgumentError.value(kind);
    }
    return auth.request(
      'GET',
      '/me/$kind?size=20${cursor == null ? '' : '&cursor=${Uri.encodeQueryComponent(cursor)}'}',
    );
  }

  Future<Map<String, dynamic>> profile(
    String author, {
    String? cursor,
  }) => auth.request(
    'GET',
    '/users/$author/posts?size=20${cursor == null ? '' : '&cursor=${Uri.encodeQueryComponent(cursor)}'}',
  );
  Future<Map<String, dynamic>> pin(int id, bool value) async {
    final result = await auth.request(
      value ? 'PUT' : 'DELETE',
      '/posts/$id/pin',
    );
    PostChanges.changed(id: id);
    return result;
  }

  Future<Map<String, dynamic>> audience(int id, String audience) async {
    final result = await auth.request(
      'PATCH',
      '/posts/$id/audience',
      body: {'audience': audience},
    );
    PostChanges.changed(id: id);
    return result;
  }

  Future<void> delete(int id) async {
    await auth.request('DELETE', '/posts/$id');
    PostChanges.changed(id: id, removed: true);
  }
}

/// Invalidation signal only: never holds Post data or private media bytes.
class PostChanges {
  static final revision = ValueNotifier<int>(0);
  static int? postId;
  static bool deleted = false;
  static void changed({int? id, bool removed = false}) {
    postId = id;
    deleted = removed;
    revision.value++;
  }
}

class PostVideoExporter {
  static const _channel = MethodChannel('gomate/post_video');
  Future<String> export(String path, GoMatePostTrimRange range) async {
    final result = await _channel.invokeMapMethod<String, dynamic>('export', {
      'path': path,
      'startMs': range.startMs,
      'endMs': range.endMs,
    });
    if (result == null ||
        (result['durationMs'] as num).toInt() <= 0 ||
        (result['durationMs'] as num).toInt() > 30000) {
      throw StateError('Không xuất được video hợp lệ dưới 30 giây');
    }
    return result['path'] as String;
  }
}

/// One compose session owns its stable upload IDs and uncertain publish retry.
class PostPublisher extends ChangeNotifier {
  final PostRepository repository;
  final PostVideoExporter exporter;
  PostPublisher({PostRepository? repository, PostVideoExporter? exporter})
    : repository = repository ?? PostRepository(),
      exporter = exporter ?? PostVideoExporter();
  String? _draftOwner;
  bool _ownerCaptured = false;
  final _uploadIds = <String, String>{};
  final _uploaded = <String, String>{};
  final _exports = <String, String>{};
  Map<String, dynamic>? _submitted;
  bool busy = false;
  String phase = '';
  bool get commitPending => _submitted != null;

  Future<int> submit({
    required List<String> sources,
    required Map<String, GoMatePostTrimRange> ranges,
    required String caption,
    required GoMatePostAudience audience,
    required List<String> hashtags,
    required List<String> taggedUserIds,
    int? placeId,
  }) async {
    if (busy) throw StateError('Đang đăng bài');
    if (sources.isEmpty || sources.length > 12) {
      throw StateError('Chọn từ 1 đến 12 media');
    }
    final actor = repository.auth.user?['id'];
    if (!_ownerCaptured) {
      _draftOwner = actor?.toString();
      _ownerCaptured = true;
    }
    if (_draftOwner != actor?.toString())
      throw StateError('Tài khoản đã thay đổi');
    void checkActor() {
      if (actor != repository.auth.user?['id'])
        throw StateError('Tài khoản đã thay đổi');
    }

    busy = true;
    notifyListeners();
    try {
      if (_submitted == null) {
        final ids = <String>[];
        for (var i = 0; i < sources.length; i++) {
          final source = sources[i];
          final video = source.startsWith('video-file:');
          String path = video
              ? source.substring(11)
              : File.fromUri(Uri.parse(source)).path;
          final range = ranges[source];
          final key = '$source:${range?.startMs}:${range?.endMs}';
          if (!_uploaded.containsKey(key)) {
            phase = 'Chuẩn bị ${i + 1}/${sources.length}';
            notifyListeners();
            if (video) {
              if (range == null ||
                  range.durationMs <= 0 ||
                  range.durationMs > 30000) {
                throw StateError('Thiếu đoạn video hợp lệ');
              }
              path = _exports[key] ??= await exporter.export(path, range);
            }
            if (await File(path).length() > (video ? 100000000 : 10000000)) {
              throw StateError(
                video ? 'Video tối đa 100 MB' : 'Ảnh tối đa 10 MB',
              );
            }
            checkActor();
            phase = 'Tải media ${i + 1}/${sources.length}';
            notifyListeners();
            final result = await repository.upload(
              path,
              video ? 'VIDEO' : 'IMAGE',
              _uploadIds.putIfAbsent(key, newPostRequestId),
            );
            checkActor();
            _uploaded[key] = result['mediaId'] as String;
          }
          ids.add(_uploaded[key]!);
        }
        _submitted = {
          'clientRequestId': newPostRequestId(),
          'caption': caption,
          'audience': switch (audience) {
            GoMatePostAudience.everyone => 'EVERYONE',
            GoMatePostAudience.followers => 'FOLLOWERS',
            GoMatePostAudience.friends => 'FRIENDS',
            GoMatePostAudience.onlyMe => 'ONLY_ME',
          },
          'mediaIds': ids,
          'hashtags': hashtags.map(normalizePostHashtag).toSet().toList(),
          'taggedUserIds': taggedUserIds,
          'placeId': placeId,
        };
      }
      phase = 'Đang xác nhận bài viết';
      notifyListeners();
      checkActor();
      final result = await repository.publish(_submitted!);
      if (actor != repository.auth.user?['id']) {
        throw StateError('Tài khoản đã thay đổi');
      }
      PostChanges.changed();
      return (result['id'] as num).toInt();
    } on ApiException catch (e) {
      if (e.status >= 400 && e.status < 500 && e.status != 408) {
        _submitted = null;
      }
      rethrow;
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> clearExports() async {
    for (final path in _exports.values) {
      try {
        await File(path).delete();
      } catch (_) {}
    }
    _exports.clear();
  }
}

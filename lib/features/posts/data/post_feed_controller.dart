import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/services/content_access_changes.dart';
import 'post_repository.dart';
import 'post_interaction_changes.dart';

/// Metadata/permission state, independent of Home's bounded media resources.
class PostFeedController extends ChangeNotifier {
  // Re-entering Home starts a new recommendation snapshot so current follow,
  // friendship and block relationships are read again by the backend.
  static const absenceTtl = Duration.zero;
  final PostRepository repository;
  final DateTime Function() now;
  List<Map<String, dynamic>> items = [];
  String? cursor, error;
  bool loading = false, revalidating = false;
  bool permissionDenied = false;
  bool _disposed = false, _visible = true;
  int _request = 0;
  Object? _actor;
  String? _privacy;
  DateTime? _away;
  Future<void>? _refreshing;
  final _details = <int, Future<void>>{};
  late final StreamSubscription<PostInteractionChange> _interactions;
  PostFeedController(this.repository, {DateTime Function()? now})
    : now = now ?? DateTime.now {
    _actor = repository.auth.user?['id'];
    _privacy = '${repository.auth.user?['isPrivate']}';
    repository.auth.addListener(_session);
    PostChanges.revision.addListener(_changed);
    ContentAccessChanges.revision.addListener(_accessChanged);
    _interactions = PostInteractionChanges.stream.listen((change) {
      if (change.belongsTo(repository.auth) && change.engagement != null) {
        patchEngagement(change.postId, change.engagement!);
      }
    });
  }
  void _session() {
    final actor = repository.auth.user?['id'];
    final privacy = '${repository.auth.user?['isPrivate']}';
    if (actor != _actor) {
      _request++;
      _refreshing = null;
      _details.clear();
      items = [];
      cursor = null;
      _actor = actor;
      unawaited(refresh());
    } else if (privacy != _privacy) {
      _accessChanged();
    }
    _privacy = privacy;
  }

  void _accessChanged() {
    _request++;
    _refreshing = null;
    unawaited(refresh());
  }

  void _changed() {
    final id = PostChanges.postId;
    if (id == null) {
      unawaited(refresh());
    } else if (PostChanges.deleted) {
      remove(id);
    } else {
      unawaited(reconcile(id));
    }
  }

  Future<void> setVisible(bool visible) async {
    if (_disposed || _visible == visible) return;
    _visible = visible;
    if (!visible) {
      _away = now();
      return;
    }
    final away = _away;
    _away = null;
    if (away != null && now().difference(away) >= absenceTtl) await refresh();
  }

  void remove(int id) {
    if (_disposed) return;
    items = items.where((p) => p['id'] != id).toList();
    notifyListeners();
  }

  void patchEngagement(int id, Map<String, dynamic> data) {
    if (_disposed) return;
    final counters = <String, dynamic>{
      for (final field in [
        'likeCount',
        'likedByMe',
        'savedByMe',
        'commentCount',
      ])
        if (data.containsKey(field)) field: data[field],
    };
    items = items.map((p) => p['id'] == id ? {...p, ...counters} : p).toList();
    notifyListeners();
  }

  Future<void> reconcile(int id) =>
      _details[id] ??= _detail(id).whenComplete(() => _details.remove(id));
  Future<void> _detail(int id) async {
    final actor = _actor, request = _request;
    if (!items.any((p) => p['id'] == id)) return;
    try {
      final data = await repository.detail(id);
      if (_disposed || actor != _actor || request != _request) return;
      items = items.map((p) => p['id'] == id ? data : p).toList();
      notifyListeners();
    } catch (e) {
      if (_disposed || actor != _actor || request != _request) return;
      if (e is ApiException && [401, 403, 404].contains(e.status)) remove(id);
    }
  }

  Future<void> refresh() {
    if (_refreshing != null) return _refreshing!;
    final completion = Completer<void>();
    final future = completion.future;
    _refreshing = future;
    _load(reset: true).then(
      (_) {
        if (identical(_refreshing, future)) _refreshing = null;
        completion.complete();
      },
      onError: (Object e, StackTrace st) {
        if (identical(_refreshing, future)) _refreshing = null;
        completion.completeError(e, st);
      },
    );
    return future;
  }

  Future<void> load({bool reset = false}) =>
      reset ? refresh() : _load(reset: false);
  Future<void> _load({required bool reset}) async {
    if (_disposed || (!reset && (loading || cursor == null))) return;
    final actor = repository.auth.user?['id'];
    final request = ++_request;
    if (actor != _actor || actor == null) items = [];
    _actor = actor;
    if (reset) {
      cursor = null;
      revalidating = true;
    }
    error = null;
    permissionDenied = false;
    if (actor == null) {
      loading = revalidating = false;
      notifyListeners();
      return;
    }
    loading = true;
    notifyListeners();
    try {
      final page = await repository.feed(cursor: reset ? null : cursor);
      if (_disposed ||
          request != _request ||
          actor != repository.auth.user?['id']) {
        return;
      }
      final previous = reset ? <Map<String, dynamic>>[] : items;
      final ids = previous.map((p) => p['id']).toSet();
      items = [
        ...previous,
        ...(page['items'] as List)
            .map((p) => Map<String, dynamic>.from(p))
            .where((p) => ids.add(p['id'])),
      ];
      cursor = page['nextCursor'] as String?;
    } catch (e) {
      if (!_disposed && request == _request) {
        permissionDenied =
            e is ApiException && [401, 403, 404].contains(e.status);
        // Unconfirmed permissions stay hidden. RAM may be reused after retry ACK.
        if (reset) items = [];
        error = 'Không tải được bài viết. Thử lại';
      }
    } finally {
      if (!_disposed && request == _request) {
        loading = revalidating = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_interactions.cancel());
    _request++;
    repository.auth.removeListener(_session);
    PostChanges.revision.removeListener(_changed);
    ContentAccessChanges.revision.removeListener(_accessChanged);
    super.dispose();
  }
}

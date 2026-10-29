import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:gomate/core/services/auth_service.dart';
import 'package:gomate/core/services/content_access_changes.dart';
import 'package:gomate/features/posts/data/home_post_media_store.dart';
import 'package:gomate/features/posts/data/post_feed_controller.dart';
import 'package:gomate/features/posts/data/post_repository.dart';
import 'package:gomate/features/posts/widgets/protected_post_media.dart';
import 'profile_posts_test.dart' as fixture;

class _Feed extends PostRepository {
  _Feed(AuthService auth) : super(auth: auth);
  int reads = 0, details = 0;
  Completer<Map<String, dynamic>>? hold;
  @override
  Future<Map<String, dynamic>> feed({String? cursor}) async {
    reads++;
    if (hold != null) return hold!.future;
    return {
      'items': [fixture.post(1)],
      'nextCursor': null,
    };
  }

  @override
  Future<Map<String, dynamic>> detail(int id) async {
    details++;
    return {...fixture.post(id), 'commentCount': 7};
  }
}

class _Native extends VideoPlayerPlatform {
  int creates = 0;
  final disposed = <int>[];
  final playing = <int>{};
  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async =>
      ++creates;
  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => Stream.value(
    VideoEvent(
      eventType: VideoEventType.initialized,
      duration: const Duration(seconds: 30),
      size: const Size(900, 1600),
    ),
  );
  @override
  Future<void> dispose(int playerId) async {
    disposed.add(playerId);
    playing.remove(playerId);
  }

  @override
  Future<void> play(int playerId) async {
    playing.add(playerId);
  }

  @override
  Future<void> pause(int playerId) async {
    playing.remove(playerId);
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> setVolume(int playerId, double volume) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<void> seekTo(int playerId, Duration position) async {}
  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;
  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const ColoredBox(color: Colors.red);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  String path(int id) =>
      '/posts/$id/media/00000000-0000-4000-8000-000000000001';
  test(
    'short tab/resume preserves metadata; >=5min away refreshes once; no timer polling',
    () async {
      final auth = await fixture.auth();
      final repo = _Feed(auth);
      var now = DateTime.utc(2026, 10, 23);
      final feed = PostFeedController(repo, now: () => now);
      await feed.refresh();
      await feed.setVisible(false);
      now = now.add(const Duration(seconds: 29));
      await feed.setVisible(true);
      await auth
          .loadProfile(); // Unchanged self profile is not a permission event.
      expect(repo.reads, 1);
      await feed.setVisible(false);
      now = now.add(const Duration(minutes: 5));
      await feed.setVisible(true);
      await feed.setVisible(true);
      expect(repo.reads, 2);
      repo.hold = Completer();
      final a = feed.refresh(), b = feed.refresh();
      expect(identical(a, b), true);
      expect(repo.reads, 3);
      repo.hold!.complete({
        'items': [fixture.post(1)],
        'nextCursor': null,
      });
      await Future.wait([a, b]);
      feed.patchEngagement(1, {'likeCount': 5, 'likedByMe': true});
      expect(feed.items.single['likeCount'], 5);
      PostChanges.changed(id: 1);
      await Future<void>.delayed(Duration.zero);
      expect(repo.details, 1);
      expect(repo.reads, 3);
      expect(feed.items.single['commentCount'], 7);
      repo.hold = null;
      ContentAccessChanges.changed();
      await Future<void>.delayed(Duration.zero);
      expect(repo.reads, 4);
      feed.dispose();
      auth.dispose();
    },
  );

  test(
    'Home owns bounded decoded images across tile leases; version/revoke/logout purge',
    () async {
      int downloads = 0;
      final auth = await fixture.auth(onMedia: () => downloads++);
      var now = DateTime.utc(2026, 10, 23);
      final store = HomePostMediaStore(
        auth: auth,
        maxEntries: 5,
        now: () => now,
      );
      final entry = store.acquire(path(1), false, '${path(1)}/thumbnail', 'v1');
      await entry.loadImage();
      expect(entry.image, isNotNull);
      expect(entry.image!.width, lessThanOrEqualTo(600));
      expect(
        entry.image!.width * entry.image!.height,
        lessThanOrEqualTo(1002000),
      );
      expect(
        store.acquire(path(1), false, '${path(1)}/thumbnail', 'v1'),
        same(entry),
      );
      await entry.loadImage();
      expect(downloads, 1);
      now = now.add(const Duration(minutes: 16));
      store.prune();
      expect(entry.released, true);
      expect(entry.image, isNull);
      final changed = store.acquire(
        path(1),
        false,
        '${path(1)}/thumbnail',
        'v2',
      );
      store.revoke(1);
      expect(changed.released, true);
      for (var id = 1; id <= 8; id++) {
        store.acquire(path(id), false, null, '');
      }
      expect(store.length, 5);
      await auth.clearLocal();
      expect(store.length, 0);
      store.dispose();
      auth.dispose();
    },
  );

  test(
    'three native players retained by stable ID, exclusive audio, bounded eviction and pause',
    () async {
      final old = VideoPlayerPlatform.instance, native = _Native();
      VideoPlayerPlatform.instance = native;
      final auth = await fixture.auth();
      final store = HomePostMediaStore(auth: auth);
      try {
        final entries = [
          for (var id = 1; id <= 4; id++)
            store.acquire(path(id), true, '${path(id)}/thumbnail', ''),
        ];
        for (final e in entries.take(3)) {
          e.visible = true;
          await e.prepare(warm: false);
        }
        expect(native.creates, 3);
        expect(native.playing.length, 1);
        final first = entries.first.player;
        await entries.first.toggle();
        expect(entries.first.player, same(first));
        expect(native.creates, 3);
        expect(native.playing.length, 1);
        entries.last.visible = true;
        await entries.last
            .prepare(); // No prefetch eviction of existing buffers.
        expect(native.creates, 3);
        await entries.last.prepare(warm: false);
        expect(native.creates, 4);
        expect(store.playerCount, 3);
        expect(native.disposed.length, 1);
        store.setEnabled(false);
        await Future<void>.delayed(Duration.zero);
        expect(native.playing, isEmpty);
        store.clear();
        await Future<void>.delayed(const Duration(milliseconds: 30));
        expect(store.playerCount, 0);
        expect(native.disposed.length, 4);
      } finally {
        store.dispose();
        auth.dispose();
        VideoPlayerPlatform.instance = old;
      }
    },
  );

  testWidgets(
    'disposing/remounting a media tile retains Home image, player and playback position',
    (t) async {
      final old = VideoPlayerPlatform.instance, native = _Native();
      VideoPlayerPlatform.instance = native;
      final auth = (await t.runAsync(() => fixture.auth()))!;
      final store = HomePostMediaStore(auth: auth);
      Widget tile() => MaterialApp(
        home: SizedBox(
          width: 400,
          height: 400,
          child: ProtectedPostMedia(
            path: path(1),
            posterPath: '${path(1)}/thumbnail',
            video: true,
            auth: auth,
            homeStore: store,
          ),
        ),
      );
      try {
        await t.pumpWidget(tile());
        await fixture.settleHomeMedia(t);
        final entry = store.acquire(path(1), true, '${path(1)}/thumbnail', '');
        final image = entry.image, player = entry.player;
        expect(image, isNotNull);
        expect(player, isNotNull);
        await player!.seekTo(const Duration(seconds: 7));
        await t.pumpWidget(const SizedBox()); // The card really is disposed.
        await fixture.settleHomeMedia(t);
        expect(native.disposed, isEmpty);
        await t.pumpWidget(tile());
        await fixture.settleHomeMedia(t);
        expect(entry.image, same(image));
        expect(entry.player, same(player));
        expect(player.value.position, const Duration(seconds: 7));
        expect(native.creates, 1);
        store.setEnabled(false);
        store.clear(); // Pressure/revoke never leaves old render handles alive.
        await fixture.settleHomeMedia(t);
        expect(entry.image, isNull);
        expect(entry.player, isNull);
      } finally {
        await t.pumpWidget(const SizedBox());
        store.dispose();
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        auth.dispose();
        VideoPlayerPlatform.instance = old;
      }
    },
  );

  test(
    'late binary ACK cannot repopulate after logout; denied media revokes the entire Post',
    () async {
      final hold = Completer<void>();
      final auth = await fixture.auth(mediaGate: () => hold.future);
      final store = HomePostMediaStore(auth: auth);
      final entry = store.acquire(path(1), false, null, '');
      final pending = entry.loadImage();
      await Future<void>.delayed(Duration.zero);
      await auth.clearLocal();
      hold.complete();
      await pending;
      expect(entry.image, isNull);
      expect(store.length, 0);
      store.dispose();
      auth.dispose();
      final denied = await fixture.auth(mediaStatus: () => 403);
      final missing = <int>[];
      final scoped = HomePostMediaStore(
        auth: denied,
        onUnavailable: missing.add,
      );
      final rejected = scoped.acquire(path(2), false, null, '');
      await rejected.loadImage();
      expect(rejected.image, isNull);
      expect(rejected.released, true);
      expect(missing, [2]);
      expect(scoped.length, 0);
      scoped.dispose();
      denied.dispose();
    },
  );

  test(
    'renewed credentials rebind the native player without losing cover or position',
    () async {
      final old = VideoPlayerPlatform.instance, native = _Native();
      VideoPlayerPlatform.instance = native;
      var token = 'original';
      final auth = await fixture.auth(accessToken: () => token);
      final store = HomePostMediaStore(auth: auth);
      try {
        final e = store.acquire(path(1), true, '${path(1)}/thumbnail', '');
        await e.loadImage();
        final image = e.image;
        e.visible = true;
        await e.prepare();
        await e.player!.seekTo(const Duration(seconds: 7));
        final first = e.player;
        await e.toggle();
        expect(e.player, same(first));
        e.pause();
        token = 'renewed';
        await auth.login(
          email: 'owner@example.com',
          password: 'TestPass123!',
          remember: false,
        );
        await e.toggle();
        expect(native.creates, 2);
        expect(native.disposed, [1]);
        expect(e.image, same(image));
        expect(e.player!.httpHeaders['Authorization'], 'Bearer renewed');
        expect(e.player!.value.position, const Duration(seconds: 7));
      } finally {
        store.dispose();
        await Future<void>.delayed(const Duration(milliseconds: 30));
        auth.dispose();
        VideoPlayerPlatform.instance = old;
      }
    },
  );

  test(
    'decoded byte budget evicts LRU images, not just card estimates',
    () async {
      final auth = await fixture.auth();
      final store = HomePostMediaStore(
        auth: auth,
        maxImageBytes: 3 * 1024 * 1024,
      );
      final first = store.acquire(path(1), false, null, '');
      await first.loadImage();
      expect(first.image, isNotNull);
      final second = store.acquire(path(2), false, null, '');
      await second.loadImage();
      expect(first.released, true);
      expect(first.image, isNull);
      expect(second.image, isNotNull);
      expect(store.imageBytes, lessThanOrEqualTo(store.maxImageBytes));
      store.dispose();
      auth.dispose();
    },
  );

  test(
    'offline retains decoded images without GET and uncached failures can retry',
    () async {
      int status = 200, downloads = 0;
      final auth = await fixture.auth(
        mediaStatus: () => status,
        onMedia: () => downloads++,
      );
      final store = HomePostMediaStore(auth: auth);
      final first = store.acquire(path(1), false, null, '');
      await first.loadImage();
      status = 503;
      final retained = store.acquire(path(1), false, null, '');
      await retained.loadImage();
      expect(retained, same(first));
      expect(retained.image, isNotNull);
      expect(downloads, 1);
      final unavailable = store.acquire(path(2), false, null, '');
      await unavailable.loadImage();
      expect(unavailable.image, isNull);
      expect(unavailable.error, true);
      status = 200;
      unavailable.retryImage();
      await unavailable.loadImage();
      expect(unavailable.image, isNotNull);
      expect(unavailable.error, false);
      expect(downloads, 3);
      store.dispose();
      auth.dispose();
    },
  );

  test(
    'account A resources cannot be reused by account B for the same media path',
    () async {
      var actor = 'account-A';
      int downloads = 0;
      final auth = await fixture.auth(
        accountId: () => actor,
        onMedia: () => downloads++,
      );
      final store = HomePostMediaStore(auth: auth);
      final first = store.acquire(path(1), false, null, '');
      await first.loadImage();
      actor = 'account-B';
      await auth.login(
        email: 'b@example.com',
        password: 'TestPass123!',
        remember: false,
      );
      expect(first.released, true);
      expect(first.image, isNull);
      final other = store.acquire(path(1), false, null, '');
      expect(other, isNot(same(first)));
      expect(other.image, isNull);
      await other.loadImage();
      expect(downloads, 2);
      store.dispose();
      auth.dispose();
    },
  );
}

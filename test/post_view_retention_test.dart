import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:gomate/core/services/auth_service.dart';
import 'package:gomate/features/home/screens/home_screen.dart';
import 'package:gomate/features/posts/data/post_repository.dart';
import 'package:gomate/features/posts/data/post_view_retention.dart';
import 'package:gomate/features/posts/widgets/protected_post_media.dart';
import 'profile_posts_test.dart' as fixture;

class _Repo extends PostRepository {
  _Repo(AuthService auth) : super(auth: auth);
  bool video = false, fail = false, carousel = false;
  int reads = 0;
  List<int> ids = [1, 2, 3, 4, 5];
  Completer<Map<String, dynamic>>? pending;
  @override
  Future<Map<String, dynamic>> feed({String? cursor}) async {
    reads++;
    if (pending != null) return pending!.future;
    if (fail) throw StateError('unavailable');
    return {
      'items': ids
          .map(
            (id) => {
              ...fixture.post(id),
              if (video && id == 1)
                'media': [
                  {
                    ...(fixture.post(id)['media'] as List).first
                        as Map<String, dynamic>,
                    'kind': 'VIDEO',
                    'width': 900,
                    'height': 1600,
                  },
                  if (carousel)
                    {
                      'id': '00000000-0000-4000-8000-000000000002',
                      'kind': 'IMAGE',
                      'url':
                          '/posts/$id/media/00000000-0000-4000-8000-000000000002',
                    },
                ],
            },
          )
          .toList(),
      'nextCursor': null,
    };
  }
}

class _Video extends VideoPlayerPlatform {
  int creates = 0, plays = 0, pauses = 0;
  final disposed = <int>[];
  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async =>
      ++creates;
  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => Stream.value(
    VideoEvent(
      eventType: VideoEventType.initialized,
      duration: const Duration(seconds: 20),
      size: const Size(900, 1600),
    ),
  );
  @override
  Future<void> dispose(int playerId) async {
    disposed.add(playerId);
  }

  @override
  Future<void> play(int playerId) async {
    plays++;
  }

  @override
  Future<void> pause(int playerId) async {
    pauses++;
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
  Future<void> home(WidgetTester t, _Repo repo) async {
    t.view.physicalSize = const Size(400, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(home: HomeScreen(postRepository: repo)));
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await fixture.settleHomeMedia(t);
  }

  ScrollController scroll(WidgetTester t) =>
      t.widget<ListView>(find.byType(ListView).first).controller!;
  Future<void> end(WidgetTester t) async {
    final c = scroll(t);
    for (int i = 0; i < 25 && c.position.extentAfter > 1; i++) {
      c.jumpTo((c.offset + 450).clamp(0, c.position.maxScrollExtent));
      await t.pump();
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await fixture.settleHomeMedia(t);
    }
    expect(c.position.extentAfter, lessThan(2));
  }

  test(
    'retention has bounded entries, estimated memory, videos and pressure clear',
    () {
      final p = PostViewRetention(
        maxPosts: 3,
        maxEstimatedBytes: 100,
        maxVideos: 1,
      );
      p.retain('a', const PostRetentionCost(20, 0));
      p.retain('b', const PostRetentionCost(20, 0));
      p.retain('c', const PostRetentionCost(20, 0));
      p.retain('d', const PostRetentionCost(20, 0));
      expect(p.length, 3);
      expect(p.contains('a'), false);
      p.retain('large', const PostRetentionCost(90, 0));
      expect(p.length, 1);
      p.retain('v1', const PostRetentionCost(5, 1));
      p.retain('v2', const PostRetentionCost(5, 1));
      expect(p.videos, 1);
      expect(p.estimatedBytes, lessThanOrEqualTo(100));
      p.retain('oversized', const PostRetentionCost(101, 0));
      expect(p.contains('oversized'), false);
      p.clear();
      expect(p.length, 0);
      p.dispose();
    },
  );

  test(
    'retention counts source and physical-size decoded images, not video file bytes',
    () {
      final c = PostRetentionCost.fromMedia([
        {'kind': 'IMAGE', 'bytes': 1000, 'width': 800, 'height': 800},
        {'kind': 'VIDEO', 'bytes': 100000000},
      ], 400);
      expect(c.bytes, 1000 + 400 * 400 * 4 + 2 * 1024 * 1024);
      expect(c.videos, 0);
    },
  );

  testWidgets(
    'five Posts survive A to B to A scrolling without new binary or feed GETs',
    (t) async {
      int downloads = 0;
      final a = (await t.runAsync(
        () => fixture.auth(onMedia: () => downloads++),
      ))!;
      final r = _Repo(a);
      await home(t, r);
      await end(t);
      expect(downloads, 5);
      final mounted = t
          .stateList(find.byType(ProtectedPostMedia, skipOffstage: false))
          .toSet();
      scroll(t).jumpTo(0);
      await fixture.settleHomeMedia(t);
      await end(t);
      scroll(t).jumpTo(0);
      await fixture.settleHomeMedia(t);
      expect(downloads, 5);
      expect(r.reads, 1);
      expect(
        t
            .stateList(find.byType(ProtectedPostMedia, skipOffstage: false))
            .toSet(),
        mounted,
      );
      await t.pumpWidget(const SizedBox());
      a.dispose();
    },
  );

  testWidgets(
    'retained offscreen Posts hide during refresh and revoked rows are disposed',
    (t) async {
      int downloads = 0;
      final a = (await t.runAsync(
        () => fixture.auth(onMedia: () => downloads++),
      ))!;
      final r = _Repo(a);
      await home(t, r);
      await end(t);
      expect(downloads, 5);
      r.pending = Completer();
      PostChanges.changed();
      await t.pump();
      final media = find.byType(ProtectedPostMedia, skipOffstage: false);
      final gates = t.widgetList<Visibility>(
        find.ancestor(
          of: media,
          matching: find.byType(Visibility, skipOffstage: false),
        ),
      );
      expect(gates, isNotEmpty);
      expect(gates.every((v) => !v.visible), true);
      r.pending!.complete({'items': [], 'nextCursor': null});
      await fixture.settleHomeMedia(t);
      expect(media, findsNothing);
      scroll(t).jumpTo(0);
      await fixture.settleHomeMedia(t);
      expect(downloads, 5);
      await t.pumpWidget(const SizedBox());
      a.dispose();
    },
  );

  testWidgets('failed refresh and logout clear retained offscreen media', (
    t,
  ) async {
    final a = (await t.runAsync(() => fixture.auth()))!;
    final r = _Repo(a);
    await home(t, r);
    await end(t);
    r.fail = true;
    PostChanges.changed();
    await fixture.settleHomeMedia(t);
    expect(find.byType(ProtectedPostMedia, skipOffstage: false), findsNothing);
    r.fail = false;
    PostChanges.changed();
    await fixture.settleHomeMedia(t);
    await end(t);
    await a.clearLocal();
    await fixture.settleHomeMedia(t);
    expect(find.byType(ProtectedPostMedia, skipOffstage: false), findsNothing);
    await t.pumpWidget(const SizedBox());
    a.dispose();
  });

  testWidgets(
    'long feed evicts older mounted Posts instead of keeping all pages',
    (t) async {
      final a = (await t.runAsync(() => fixture.auth()))!;
      final r = _Repo(a)..ids = List.generate(12, (i) => i + 1);
      await home(t, r);
      await end(t);
      final media = find.byType(ProtectedPostMedia, skipOffstage: false);
      expect(t.widgetList(media).length, lessThanOrEqualTo(7));
      expect(
        find.byWidgetPredicate(
          (w) => w is ProtectedPostMedia && w.path.startsWith('/posts/1/'),
          skipOffstage: false,
        ),
        findsNothing,
      );
      await t.pumpWidget(const SizedBox());
      a.dispose();
    },
  );

  for (final carousel in [false, true]) {
    testWidgets(
      'retained video reuses decoder and pauses: carousel=$carousel',
      (t) async {
        final previous = VideoPlayerPlatform.instance;
        final video = _Video();
        VideoPlayerPlatform.instance = video;
        addTearDown(() => VideoPlayerPlatform.instance = previous);
        final a = (await t.runAsync(() => fixture.auth()))!;
        final r = _Repo(a)
          ..video = true
          ..carousel = carousel;
        await home(t, r);
        expect(video.creates, 1);
        await t.tap(find.byIcon(LucideIcons.play).first);
        await t.pump(const Duration(milliseconds: 400));
        expect(video.plays, greaterThan(0));
        final pauses = video.pauses;
        scroll(t).jumpTo(850);
        await t.pump(const Duration(milliseconds: 400));
        expect(video.pauses, greaterThan(pauses));
        await end(t);
        expect(video.disposed, isEmpty);
        scroll(t).jumpTo(0);
        await fixture.settleHomeMedia(t);
        expect(video.creates, 1);
        final player = t
            .widget<VideoPlayer>(find.byType(VideoPlayer))
            .controller;
        expect(player.value.isPlaying, false);
        await t.tap(find.byIcon(LucideIcons.play).first);
        await t.pump(const Duration(milliseconds: 400));
        await t.pumpWidget(
          MaterialApp(home: HomeScreen(postRepository: r, active: false)),
        );
        await fixture.settleHomeMedia(t);
        expect(player.value.isPlaying, false);
        await t.pumpWidget(const SizedBox());
        await fixture.settleHomeMedia(t);
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        expect(video.disposed, [1]);
        a.dispose();
      },
    );
  }
}

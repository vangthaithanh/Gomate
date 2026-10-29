import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:gomate/features/home/screens/home_screen.dart';
import 'package:gomate/features/moments/widgets/moments_strip.dart';
import 'package:gomate/features/moments/screens/moment_camera_screen.dart';
import 'package:gomate/features/posts/screens/create_post_screen.dart';
import 'package:gomate/features/posts/data/post_repository.dart';
import 'package:gomate/features/posts/widgets/content_mode_selector.dart';
import 'profile_posts_test.dart' as fixture;

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const gallery = MethodChannel('com.fluttercandies/photo_manager');
  const camera = MethodChannel('plugins.flutter.io/camera');
  late List<MethodCall> cameraCalls;
  late List<MethodCall> galleryCalls;
  Completer<List<dynamic>>? cameras;
  setUp(() {
    cameras = null;
    cameraCalls = [];
    galleryCalls = [];
    binding.defaultBinaryMessenger.setMockMethodCallHandler(camera, (
      call,
    ) async {
      cameraCalls.add(call);
      if (call.method == 'availableCameras') {
        return cameras == null ? <dynamic>[] : cameras!.future;
      }
      return null;
    });
    binding.defaultBinaryMessenger.setMockMethodCallHandler(gallery, (
      call,
    ) async {
      galleryCalls.add(call);
      return switch (call.method) {
        'requestPermissionExtend' => PermissionState.authorized.index,
        'getAssetPathList' => {
          'data': [
            {'id': '', 'name': 'Recent', 'assetCount': 1, 'isAll': true},
          ],
        },
        'getAssetListPaged' => {
          'data': [
            {
              'id': '1',
              'type': AssetType.image.index,
              'width': 800,
              'height': 800,
            },
          ],
        },
        'getFullFile' => File('assets/images/checkin.jpg').absolute.path,
        _ => null,
      };
    });
  });
  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(gallery, null);
    binding.defaultBinaryMessenger.setMockMethodCallHandler(camera, null);
  });

  Future<void> proof(WidgetTester t, GlobalKey key, String name) async {
    if (!const bool.fromEnvironment('GOMATE_UI_PROOF')) return;
    final image = await t.runAsync(
      () => (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
          .toImage(),
    );
    final bytes = await t.runAsync(
      () => image!.toByteData(format: ui.ImageByteFormat.png),
    );
    await t.runAsync(
      () => File(
        'backups/p2-pre-v21/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List()),
    );
    image!.dispose();
  }

  for (final size in [const Size(390, 844), const Size(360, 640)]) {
    testWidgets(
      'creation modes preserve gallery state and existing camera at $size',
      (t) async {
        t.view.physicalSize = size;
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final key = GlobalKey();
        await t.pumpWidget(
          MaterialApp(
            home: RepaintBoundary(
              key: key,
              child: const GoMateCreatePostScreen(enableMomentMode: true),
            ),
          ),
        );
        await fixture.settleHomeMedia(t);
        expect(find.text('Bài viết mới'), findsOneWidget);
        expect(find.byType(MomentCameraScreen), findsNothing);
        expect(cameraCalls, isEmpty);
        await t.tap(find.text('Chọn nhiều'));
        await fixture.settleHomeMedia(t);
        expect(find.text('Chọn nhiều: Bật'), findsOneWidget);
        await proof(t, key, 'create-post-${size.width.toInt()}');
        await t.drag(
          find.byKey(const ValueKey('content-mode-selector')),
          const Offset(-200, 0),
        );
        await fixture.settleHomeMedia(t);
        expect(find.byType(MomentCameraScreen), findsOneWidget);
        expect(find.text('Ảnh khoảnh khắc'), findsOneWidget);
        expect(find.byType(GridView), findsNothing);
        expect(
          cameraCalls.where((c) => c.method == 'availableCameras').length,
          1,
        );
        await proof(t, key, 'create-moment-${size.width.toInt()}');
        await t.drag(
          find.byKey(const ValueKey('content-mode-selector')),
          const Offset(200, 0),
        );
        await fixture.settleHomeMedia(t);
        expect(find.byType(MomentCameraScreen), findsNothing);
        expect(find.text('Chọn nhiều: Bật'), findsOneWidget);
        expect(
          galleryCalls.where((c) => c.method == 'getAssetPathList').length,
          1,
        );
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets(
    'switching back while camera discovery is pending creates no hidden camera',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      cameras = Completer();
      await t.pumpWidget(
        const MaterialApp(home: GoMateCreatePostScreen(enableMomentMode: true)),
      );
      await fixture.settleHomeMedia(t);
      await t.tap(find.text('Khoảnh khắc'));
      await t.pump();
      await t.tap(find.text('Bài viết'));
      await fixture.settleHomeMedia(t);
      cameras!.complete([
        {'name': '0', 'lensFacing': 'back', 'sensorOrientation': 90},
      ]);
      await fixture.settleHomeMedia(t);
      expect(cameraCalls.any((c) => c.method == 'create'), false);
      expect(find.text('Bài viết mới'), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Home add entry opens Post first, not the Moment camera', (
    t,
  ) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final a = (await t.runAsync(() => fixture.auth()))!;
    await t.pumpWidget(
      MaterialApp(
        home: HomeScreen(postRepository: PostRepository(auth: a)),
      ),
    );
    await fixture.settleHomeMedia(t);
    t.widget<MomentsStrip>(find.byType(MomentsStrip)).onCreate!();
    await fixture.settleHomeMedia(t);
    expect(find.text('Bài viết mới'), findsOneWidget);
    expect(find.byType(ContentModeSelector), findsOneWidget);
    expect(find.byType(MomentCameraScreen), findsNothing);
    expect(cameraCalls, isEmpty);
    await t.pumpWidget(const SizedBox());
    a.dispose();
  });
}

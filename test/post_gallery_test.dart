import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:gomate/features/posts/screens/create_post_screen.dart';

void main() {
  const channel = MethodChannel('com.fluttercandies/photo_manager');
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
  });

  for (final permission in [
    PermissionState.authorized,
    PermissionState.limited,
  ]) {
    testWidgets(
      'mixed gallery stays ordered across pages with ${permission.name} access',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final calls = <MethodCall>[];
        Map<String, Object> asset(int id, {bool video = false}) => {
          'id': '$id',
          'type': video ? AssetType.video.index : AssetType.image.index,
          'width': 576,
          'height': 1024,
          'duration': video ? 48 : 0,
        };
        binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
          call,
        ) async {
          calls.add(call);
          switch (call.method) {
            case 'requestPermissionExtend':
              return permission.index;
            case 'getAssetPathList':
              return {
                'data': [
                  {'id': '', 'name': 'Recent', 'assetCount': 73, 'isAll': true},
                ],
              };
            case 'getAssetListPaged':
              final args = call.arguments as Map;
              return {
                'data': args['page'] == 0
                    ? List.generate(
                        72,
                        (index) => asset(index, video: index == 0),
                      )
                    : [asset(72, video: true)],
              };
            default:
              return null;
          }
        });
        await tester.pumpWidget(
          const MaterialApp(home: GoMateCreatePostScreen()),
        );
        await tester.pumpAndSettle();
        expect(find.text('0:48'), findsOneWidget);
        expect(find.byKey(const ValueKey('post-camera-cell')), findsOneWidget);
        await tester.drag(find.byType(GridView), const Offset(0, -1800));
        await tester.pumpAndSettle();
        final path =
            calls.singleWhere((c) => c.method == 'getAssetPathList').arguments
                as Map;
        expect(path['type'], RequestType.common.value);
        expect(path['onlyAll'], true);
        final filter = path['option'] as Map;
        final child = filter['child'] as Map;
        expect(
          child['where'],
          '',
        ); // Long/downloaded videos must not be hidden.
        expect((child['orderBy'] as List).first, {
          'column': CustomColumns.base.createDate,
          'isAsc': false,
        });
        final pages = calls
            .where((c) => c.method == 'getAssetListPaged')
            .toList();
        expect(pages.length, 2);
        for (final page in pages) {
          final args = page.arguments as Map;
          expect(args['type'], RequestType.common.value);
          expect(args['option'], filter);
          expect(args['size'], 72);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('denied permission keeps existing permission and camera UI', (
    tester,
  ) async {
    int queries = 0;
    binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      if (call.method == 'requestPermissionExtend') {
        return PermissionState.denied.index;
      }
      if (call.method == 'getAssetPathList') queries++;
      return null;
    });
    await tester.pumpWidget(const MaterialApp(home: GoMateCreatePostScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Mở cài đặt cấp quyền'), findsOneWidget);
    expect(find.byKey(const ValueKey('post-camera-cell')), findsOneWidget);
    expect(queries, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

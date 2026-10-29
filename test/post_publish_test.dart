import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gomate/core/network/api_exception.dart';
import 'package:gomate/core/services/auth_service.dart';
import 'package:gomate/core/services/session_store.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:gomate/features/posts/data/post_repository.dart';
import 'package:gomate/features/posts/ui_preview/post_ui_demo_store.dart';
import 'package:gomate/features/posts/widgets/post_audience_content.dart';

class _Repo extends PostRepository {
  final uploads = <String>[];
  final keys = <String>[];
  final bodies = <Map<String, dynamic>>[];
  bool failUpload = false;
  bool failAck = false;
  bool failValidation = false;
  @override
  Future<Map<String, dynamic>> upload(
    String path,
    String kind,
    String id,
  ) async {
    uploads.add(path);
    keys.add(id);
    if (failUpload) {
      failUpload = false;
      throw const ApiException(503, 'FAILED', 'Upload failed');
    }
    return {'mediaId': id};
  }

  @override
  Future<Map<String, dynamic>> publish(Map<String, dynamic> body) async {
    bodies.add(Map.of(body));
    if (failAck) {
      failAck = false;
      throw const ApiException(0, 'NETWORK_ERROR', 'ACK lost');
    }
    if (failValidation) {
      failValidation = false;
      throw const ApiException(422, 'INVALID_POST_AUDIENCE', 'Changed privacy');
    }
    return {'id': 19};
  }
}

class _SessionStore implements SessionStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String text) async {
    value = text;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

void main() {
  for (final path in ['/users/owner/posts?size=20', '/feed?size=20']) {
    test('Post media keeps the API candidate that served $path', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final service = AuthService(
        store: _SessionStore(),
        client: MockClient((request) async {
          if (request.url.host == '127.0.0.1')
            throw http.ClientException('Candidate unavailable');
          return http.Response(
            jsonEncode(
              request.url.path.endsWith('/login')
                  ? {
                      'accessToken': 'access',
                      'refreshToken': 'refresh',
                      'user': {'id': 'owner'},
                    }
                  : {'items': [], 'nextCursor': null},
            ),
            200,
          );
        }),
      );
      await service.login(
        email: 'owner@example.com',
        password: 'TestPass123!',
        remember: false,
      );
      await service.request('GET', path);
      final media = await service.postMediaAccess(
        '/posts/1/media/00000000-0000-4000-8000-000000000001',
      );
      expect(media.uri.host, '10.0.2.2');
      service.dispose();
    });
  }
  test('protected Post media always requests fresh authorized bytes', () async {
    var mediaRequests = 0;
    var denied = false;
    final auth = AuthService(
      store: _SessionStore(),
      baseUrl: 'http://localhost:8081/api/v1',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/login')) {
          return http.Response(
            jsonEncode({
              'accessToken': 'test-access',
              'refreshToken': 'test-refresh',
              'user': {'id': 'viewer', 'onboardingCompleted': true},
            }),
            200,
          );
        }
        expect(
          request.url.path,
          '/api/v1/posts/19/media/00000000-0000-4000-8000-000000000019',
        );
        expect(request.headers['Authorization'], 'Bearer test-access');
        expect(request.headers['Cache-Control'], 'no-store');
        mediaRequests++;
        return denied
            ? http.Response('{}', 404)
            : http.Response.bytes([1, 2], 200);
      }),
    );
    await auth.login(
      email: 'test@example.com',
      password: 'TestPass123!',
      remember: false,
    );
    const path = '/posts/19/media/00000000-0000-4000-8000-000000000019';
    expect(await auth.postImage(path), [1, 2]);
    denied = true;
    await expectLater(auth.postImage(path), throwsA(isA<ApiException>()));
    expect(mediaRequests, 2);
    auth.dispose();
  });
  test('protected media path cannot send JWT to an external URL', () async {
    var calls = 0;
    final auth = AuthService(
      store: _SessionStore(),
      client: MockClient((_) async {
        calls++;
        return http.Response('{}', 200);
      }),
    );
    await expectLater(
      auth.postMediaAccess('https://external.example/image'),
      throwsArgumentError,
    );
    await expectLater(auth.postMediaAccess('/users/me'), throwsArgumentError);
    expect(calls, 0);
    auth.dispose();
  });
  test('hashtag identity matches Spring NFC and case normalization', () {
    expect(normalizePostHashtag(' ##ĐÀLẠT '), 'đàlạt');
    expect(normalizePostHashtag('#Ho\u0302\u0300'), 'hồ');
    expect(normalizePostHashtag('hồ'), normalizePostHashtag('#HỒ'));
  });
  late Directory temp;
  late List<String> sources;
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('gomate-post-test-');
    sources = [];
    for (int i = 0; i < 12; i++) {
      final file = File('${temp.path}/$i.png');
      await file.writeAsBytes([1, 2, 3]);
      sources.add(file.uri.toString());
    }
  });
  tearDown(() async {
    await temp.delete(recursive: true);
  });
  Future<int> publish(
    PostPublisher p,
    List<String> order, {
    String caption = 'Đà Lạt 🌸\nDòng hai',
  }) => p.submit(
    sources: order,
    ranges: {},
    caption: caption,
    audience: GoMatePostAudience.everyone,
    hashtags: ['#hồ'],
    taggedUserIds: [],
  );
  test(
    '12 mixed selections preserve final order and upload failure can retry',
    () async {
      final repo = _Repo()..failUpload = true;
      final p = PostPublisher(repository: repo);
      await expectLater(publish(p, sources), throwsA(isA<ApiException>()));
      expect(p.commitPending, false);
      expect(p.busy, false);
      final reversed = sources.reversed.toList();
      expect(await publish(p, reversed), 19);
      expect(repo.bodies.single['caption'], 'Đà Lạt 🌸\nDòng hai');
      expect(repo.bodies.single['mediaIds'], repo.keys.sublist(1));
      p.dispose();
    },
  );
  test(
    'lost commit ACK retries same payload/key without reuploading or duplicating',
    () async {
      final repo = _Repo()..failAck = true;
      final p = PostPublisher(repository: repo);
      await expectLater(
        publish(p, sources.take(1).toList()),
        throwsA(isA<ApiException>()),
      );
      expect(p.commitPending, true);
      expect(await publish(p, sources.take(1).toList()), 19);
      expect(repo.uploads.length, 1);
      expect(repo.bodies[0], repo.bodies[1]);
      p.dispose();
    },
  );
  test(
    'server validation preserves uploaded media but unlocks form for correction',
    () async {
      final repo = _Repo()..failValidation = true;
      final p = PostPublisher(repository: repo);
      await expectLater(
        publish(p, sources.take(1).toList()),
        throwsA(isA<ApiException>()),
      );
      expect(p.commitPending, false);
      expect(
        await publish(p, sources.take(1).toList(), caption: 'Sửa chú thích'),
        19,
      );
      expect(repo.uploads.length, 1);
      expect(
        repo.bodies[0]['clientRequestId'],
        isNot(repo.bodies[1]['clientRequestId']),
      );
      p.dispose();
    },
  );
  test('0/13 media never upload or publish', () async {
    final repo = _Repo();
    final p = PostPublisher(repository: repo);
    await expectLater(publish(p, []), throwsStateError);
    await expectLater(
      publish(p, [...sources, sources.first]),
      throwsStateError,
    );
    expect(repo.uploads, isEmpty);
    expect(repo.bodies, isEmpty);
    p.dispose();
  });
  test(
    'native export result is a real output path; overlong output is rejected',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      final target = File('${temp.path}/cut.mp4');
      await target.writeAsBytes([4, 5, 6]);
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('gomate/post_video'), (
            call,
          ) async {
            calls.add(call);
            return {'path': target.path, 'durationMs': 29000};
          });
      final exporter = PostVideoExporter();
      expect(
        await exporter.export(
          '/source.mp4',
          const GoMatePostTrimRange(startMs: 1000, endMs: 30000),
        ),
        target.path,
      );
      expect((calls.single.arguments as Map)['startMs'], 1000);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('gomate/post_video'),
            (_) async => {'path': target.path, 'durationMs': 30001},
          );
      await expectLater(
        exporter.export(
          '/source.mp4',
          const GoMatePostTrimRange(startMs: 0, endMs: 30000),
        ),
        throwsStateError,
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('gomate/post_video'),
            null,
          );
    },
  );
  for (final private in [true, false]) {
    testWidgets('audience choices match server privacy private=$private', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GoMatePostAudienceContent(
              initial: private
                  ? GoMatePostAudience.followers
                  : GoMatePostAudience.everyone,
              isPrivate: private,
            ),
          ),
        ),
      );
      expect(find.text('Bạn bè'), findsOneWidget);
      expect(find.text('Chỉ mình tôi'), findsOneWidget);
      expect(find.text('Mọi người'), private ? findsNothing : findsOneWidget);
      expect(
        find.text('Người theo dõi'),
        private ? findsOneWidget : findsNothing,
      );
    });
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gomate/core/services/auth_service.dart';
import 'package:gomate/core/services/content_access_changes.dart';
import 'package:gomate/features/profile/data/user_block_repository.dart';
import 'package:gomate/features/profile/screens/blocked_users_content.dart';
import 'package:gomate/features/messages/widgets/blocked_group_members_content.dart';

class _Auth extends AuthService {
  String? owner = 'a';
  int generation = 0;
  Completer<void>? gate;
  bool fail = false;
  final calls = <String>[];
  final blocked = <String>{'b', 'c'};
  @override
  Map<String, dynamic>? get user => owner == null ? null : {'id': owner};
  @override
  bool get signedIn => owner != null;
  @override
  int get sessionGeneration => generation;
  @override
  Future<void> loadProfile() async {}
  @override
  Future<Map<String, dynamic>> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    calls.add('$method $path');
    if (path.startsWith('/users/me/blocked'))
      return {
        'items': [
          for (final id in blocked)
            {
              'userId': id,
              'displayName': id == 'b' ? 'Xuân Thu' : 'Thanh',
              'nickname': id,
            },
        ],
        'total': blocked.length,
      };
    await gate?.future;
    if (fail) throw StateError('Không thể lưu');
    final id = path.split('/')[2];
    if (method == 'DELETE') {
      blocked.remove(id);
    } else {
      blocked.add(id);
    }
    return {};
  }
}

const people = [
  BlockedUser(id: 'b', name: 'Xuân Thu'),
  BlockedUser(id: 'c', name: 'Thanh'),
];
Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  test(
    'Global API ACK gates invalidation; actor is never in request',
    () async {
      final auth = _Auth()..gate = Completer<void>();
      final repo = UserBlockRepository(auth: auth);
      final before = ContentAccessChanges.revision.value;
      final result = repo.setBlocked('b', false);
      expect(ContentAccessChanges.revision.value, before);
      expect(auth.blocked, contains('b'));
      auth.gate!.complete();
      await result;
      expect(ContentAccessChanges.revision.value, before + 1);
      expect(auth.blocked, isNot(contains('b')));
      expect(auth.calls.single, 'DELETE /users/b/block');
      repo.dispose();
    },
  );
  test('Failed mutation does not claim success or invalidate', () async {
    final auth = _Auth()..fail = true;
    final repo = UserBlockRepository(auth: auth);
    final before = ContentAccessChanges.revision.value;
    await expectLater(repo.setBlocked('b', false), throwsStateError);
    expect(ContentAccessChanges.revision.value, before);
    expect(auth.blocked, contains('b'));
    repo.dispose();
  });
  test('Late ACK from old login cannot update new account UI', () async {
    final auth = _Auth()..gate = Completer<void>();
    final repo = UserBlockRepository(auth: auth);
    final before = ContentAccessChanges.revision.value;
    final result = repo.setBlocked('b', true);
    auth.owner = 'new';
    auth.generation++;
    auth.gate!.complete();
    await expectLater(result, throwsStateError);
    expect(ContentAccessChanges.revision.value, before);
    repo.dispose();
  });
  testWidgets(
    'Group multi unblock targets one user and waits ACK; Close has no mutation',
    (tester) async {
      final auth = _Auth()..gate = Completer<void>();
      final repo = UserBlockRepository(auth: auth);
      await tester.pumpWidget(
        host(BlockedGroupMembersContent(members: people, repository: repo)),
      );
      expect(find.text('Bạn đã chặn các thành viên'), findsOneWidget);
      await tester.tap(find.text('Bỏ chặn').first);
      await tester.pump();
      expect(find.text('Xuân Thu'), findsOneWidget);
      expect(find.text('Đang lưu…'), findsOneWidget);
      auth.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Xuân Thu'), findsNothing);
      expect(find.text('Bạn đã chặn thành viên Thanh'), findsOneWidget);
      expect(auth.calls.single, 'DELETE /users/b/block');
      await tester.tap(find.text('Đóng'));
      await tester.pumpAndSettle();
      expect(auth.calls.length, 1);
      await tester.pumpWidget(const SizedBox());
      repo.dispose();
    },
  );
  testWidgets('Group failed unblock retains user and retry action', (
    tester,
  ) async {
    final auth = _Auth()..fail = true;
    final repo = UserBlockRepository(auth: auth);
    await tester.pumpWidget(
      host(
        BlockedGroupMembersContent(members: [people.first], repository: repo),
      ),
    );
    await tester.tap(find.text('Bỏ chặn'));
    await tester.pumpAndSettle();
    expect(find.text('Bạn đã chặn thành viên Xuân Thu'), findsOneWidget);
    expect(find.text('Bỏ chặn'), findsOneWidget);
    expect(find.textContaining('Không thể lưu'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    repo.dispose();
  });
  testWidgets(
    'Settings list is API backed and removes only acknowledged target',
    (tester) async {
      final auth = _Auth();
      final repo = UserBlockRepository(auth: auth);
      await tester.pumpWidget(host(BlockedUsersContent(repository: repo)));
      await tester.pumpAndSettle();
      expect(find.text('Xuân Thu'), findsOneWidget);
      expect(find.text('Thanh'), findsOneWidget);
      auth.gate = Completer<void>();
      await tester.tap(find.text('Bỏ chặn').first);
      await tester.pump();
      expect(find.text('Xuân Thu'), findsOneWidget);
      auth.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Xuân Thu'), findsNothing);
      expect(find.text('Thanh'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      repo.dispose();
    },
  );
}

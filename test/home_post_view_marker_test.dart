import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gomate/features/posts/widgets/home_post_view_marker.dart';

Widget _harness({
  required ScrollController controller,
  required Future<void> Function(int) onViewed,
  bool active = true,
  double cardHeight = 200,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: 400,
          height: 400,
          child: ListView(
            controller: controller,
            padding: EdgeInsets.zero,
            children: [
              const SizedBox(height: 500),
              HomePostViewMarker(
                postId: 42,
                active: active,
                scrollController: controller,
                onViewed: onViewed,
                child: SizedBox(height: cardHeight),
              ),
              const SizedBox(height: 500),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() {
  test('tall cards use the visible viewport-sized region as denominator', () {
    const viewport = Rect.fromLTWH(0, 0, 400, 400);
    expect(
      homePostVisibleRatio(const Rect.fromLTWH(0, 200, 400, 800), viewport),
      .5,
    );
    expect(
      homePostVisibleRatio(const Rect.fromLTWH(0, 300, 400, 800), viewport),
      .25,
    );
  });

  testWidgets('API-loaded or briefly visible posts are not recorded', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    var calls = 0;
    await tester.pumpWidget(
      _harness(
        controller: controller,
        onViewed: (_) async {
          calls++;
        },
      ),
    );

    await tester.pump(const Duration(seconds: 3));
    expect(calls, 0, reason: 'the loaded card is still outside the viewport');

    controller.jumpTo(200); // Exactly 50% of the 200px card is visible.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1900));
    expect(calls, 0);
    controller.jumpTo(150); // Drops to 25%, resetting the continuous dwell.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    controller.jumpTo(200);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1999));
    expect(calls, 0);
    await tester.pump(const Duration(milliseconds: 1));
    expect(calls, 1);
    await tester.pump(const Duration(seconds: 3));
    expect(calls, 1, reason: 'one visible exposure sends at most once');
  });

  testWidgets('foreground gate and tall-card threshold are enforced', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    var calls = 0;
    Future<void> viewed(int _) async {
      calls++;
    }

    await tester.pumpWidget(
      _harness(
        controller: controller,
        onViewed: viewed,
        active: false,
        cardHeight: 800,
      ),
    );
    controller.jumpTo(300); // 200px = 50% of the 400px viewport reference.
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(calls, 0);

    await tester.pumpWidget(
      _harness(controller: controller, onViewed: viewed, cardHeight: 800),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(calls, 1);
  });

  testWidgets('failed recording retries only after a new visible exposure', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    var calls = 0;
    await tester.pumpWidget(
      _harness(
        controller: controller,
        onViewed: (_) async {
          calls++;
          if (calls == 1) throw StateError('network unavailable');
        },
      ),
    );
    controller.jumpTo(350);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(calls, 1);
    await tester.pump(const Duration(seconds: 3));
    expect(calls, 1, reason: 'failure must not create a request loop');

    controller.jumpTo(0);
    await tester.pump();
    controller.jumpTo(350);
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(calls, 2);
    await tester.pump(const Duration(seconds: 3));
    expect(calls, 2, reason: 'the successful retry is acknowledged locally');
  });
}

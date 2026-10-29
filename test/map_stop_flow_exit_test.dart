import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gomate/features/map/widgets/map_add_place_flow_panel.dart';
import 'package:gomate/features/trip/models/trip_ui_models.dart';

const _trip = TripUi(
  id: 'old-trip',
  title: 'Lịch trình cũ',
  days: 2,
  destination: 'Test',
);

void main() {
  // The same panel is used by Add and Edit: every step must have an independent
  // escape, even when validation blocks Continue or a request is still pending.
  for (final step in GoMateMapAddPlaceStep.values) {
    for (final state in ['normal', 'past', 'interval', 'network', 'saving']) {
      testWidgets('$step / $state: Close never submits, skips or clears time', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final events = <String>[];
        final error = switch (state) {
          'past' =>
            'Ngày địa điểm đã qua. Hãy sửa ngày lịch trình trước khi đặt giờ mới.',
          'interval' => 'Giờ kết thúc phải sau giờ bắt đầu trong cùng ngày.',
          'network' => 'Không kết nối được máy chủ.',
          _ => null,
        };
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: GoMateMapAddPlaceFlowPanel(
                  trip: _trip,
                  step: step,
                  selectedDay: 1,
                  selectedTime: '10:02',
                  errorText: error,
                  saving: state == 'saving',
                  timeAllowed: state == 'past' ? (_) => false : null,
                  onClose: () => events.add('close'),
                  onSkip: () => events.add('skip'),
                  onContinue: () => events.add('save'),
                  onDayChanged: (_) => events.add('day'),
                  onTimeChanged: (_) => events.add('time'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(events, isEmpty);
        expect(find.text('Đóng'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('map-stop-flow-close')));
        await tester.pump();
        expect(events, ['close']);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
    'Back dismisses a dialog first, then editor, then page; draft is not submitted',
    (tester) async {
      final navigator = GlobalKey<NavigatorState>();
      var active = true;
      var closed = 0;
      var submitted = 0;
      await tester.pumpWidget(
        MaterialApp(navigatorKey: navigator, home: const Text('Root')),
      );
      navigator.currentState!.push(
        MaterialPageRoute<void>(
          builder: (context) => StatefulBuilder(
            builder: (context, setState) => GoMateMapStopFlowBackScope(
              active: active,
              visible: true,
              onClose: () => setState(() {
                closed++;
                active = false;
              }),
              child: Scaffold(
                body: active
                    ? Column(
                        children: [
                          TextButton(
                            onPressed: () => showDialog<void>(
                              context: context,
                              builder: (_) =>
                                  const AlertDialog(content: Text('Dialog')),
                            ),
                            child: const Text('Open dialog'),
                          ),
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: GoMateMapAddPlaceFlowPanel(
                                trip: _trip,
                                step: GoMateMapAddPlaceStep.endTime,
                                selectedDay: 1,
                                selectedTime: '09:00',
                                errorText: 'Giờ kết thúc phải sau giờ bắt đầu.',
                                onClose: () => setState(() {
                                  closed++;
                                  active = false;
                                }),
                                onSkip: () => submitted++,
                                onContinue: () => submitted++,
                                onDayChanged: (_) {},
                                onTimeChanged: (_) {},
                              ),
                            ),
                          ),
                        ],
                      )
                    : const Text('Map remains open'),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open dialog'));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Dialog'), findsNothing);
      expect(closed, 0);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(closed, 1);
      expect(submitted, 0);
      expect(find.text('Map remains open'), findsOneWidget);
      expect(navigator.currentState!.canPop(), isTrue);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Root'), findsOneWidget);
      expect(closed, 1);
    },
  );

  for (final visible in [false, true]) {
    testWidgets(
      'Hidden Map or inactive editor does not steal Back: visible=$visible',
      (tester) async {
        final navigator = GlobalKey<NavigatorState>();
        var closed = 0;
        await tester.pumpWidget(
          MaterialApp(navigatorKey: navigator, home: const Text('Root')),
        );
        navigator.currentState!.push(
          MaterialPageRoute<void>(
            builder: (_) => Scaffold(
              body: IndexedStack(
                index: visible ? 0 : 1,
                children: [
                  GoMateMapStopFlowBackScope(
                    active: !visible,
                    visible: visible,
                    onClose: () => closed++,
                    child: const Text('Map'),
                  ),
                  const Text('Another tab'),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.text('Root'), findsOneWidget);
        expect(closed, 0);
      },
    );
  }
}

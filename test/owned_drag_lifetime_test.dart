import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter_test/flutter_test.dart';

const _child = ValueKey('owned-drag-child');
const _start = ValueKey('owned-start');
const _end = ValueKey('owned-end');

Future<SlidableController> _pump(
  WidgetTester tester, {
  Future<bool> Function()? confirmDismiss,
  VoidCallback? onDismissed,
}) async {
  late SlidableController controller;
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 400,
          height: 80,
          child: Slidable(
            key: const ValueKey('owned-slidable'),
            startActionPane: const ActionPane(
              key: _start,
              motion: BehindMotion(),
              children: [Expanded(child: SizedBox.expand())],
            ),
            endActionPane: ActionPane(
              key: _end,
              motion: const BehindMotion(),
              dismissible: onDismissed == null
                  ? null
                  : DismissiblePane(
                      confirmDismiss: confirmDismiss,
                      onDismissed: onDismissed,
                    ),
              children: const [Expanded(child: SizedBox.expand())],
            ),
            child: Builder(
              builder: (context) {
                controller = Slidable.of(context)!;
                return const SizedBox.expand(key: _child);
              },
            ),
          ),
        ),
      ),
    ),
  );
  return controller;
}

void main() {
  testWidgets('an interrupted neutral settle admits the next real drag', (
    tester,
  ) async {
    final controller = await _pump(tester);
    final first = await tester.startGesture(
      tester.getCenter(find.byKey(_child)),
    );
    await first.moveBy(const Offset(-160, 0));
    await tester.pump();
    await first.moveBy(const Offset(220, 0));
    await tester.pump();
    await first.up();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final second = await tester.startGesture(
      tester.getCenter(find.byKey(_child)),
    );
    await second.moveBy(const Offset(-120, 0));
    await tester.pump();
    expect(controller.ratio, lessThan(0));
    expect(find.byKey(_end), findsOneWidget);
    await second.up();
    await tester.pumpAndSettle();
    controller.openStartActionPane();
    await tester.pumpAndSettle();
    expect(controller.ratio, greaterThan(0));
    expect(controller.closing, isFalse);
  });

  testWidgets(
    'a fling toward the locked drawer still settles from past neutral',
    (tester) async {
      final controller = await _pump(tester);
      final gesture = await tester.startGesture(
        tester.getCenter(find.byKey(_child)),
      );
      await gesture.moveBy(
        const Offset(-160, 0),
        timeStamp: const Duration(milliseconds: 100),
      );
      await tester.pump();
      await gesture.moveBy(
        const Offset(240, 0),
        timeStamp: const Duration(milliseconds: 200),
      );
      await tester.pump();
      await gesture.moveBy(
        const Offset(-10, 0),
        timeStamp: const Duration(milliseconds: 205),
      );
      await tester.pump();
      expect(controller.movementRatio, greaterThan(0));
      await gesture.up(timeStamp: const Duration(milliseconds: 206));
      await tester.pumpAndSettle();
      expect(controller.ratio, 0);
      expect(controller.movementRatio, 0);
      expect(find.byKey(_start), findsNothing);
      expect(find.byKey(_end), findsNothing);
    },
  );

  testWidgets(
    'removing a row while confirmation waits finishes without effects',
    (tester) async {
      final confirmation = Completer<bool>();
      var dismissed = false;
      await _pump(
        tester,
        confirmDismiss: () => confirmation.future,
        onDismissed: () => dismissed = true,
      );
      await tester.timedDrag(
        find.byKey(_child),
        const Offset(-340, 0),
        const Duration(milliseconds: 400),
      );
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      confirmation.complete(true);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(dismissed, isFalse);
    },
  );
}

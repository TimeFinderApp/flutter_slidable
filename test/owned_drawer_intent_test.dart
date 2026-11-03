import 'package:flutter_slidable/src/action_pane_motions.dart';
import 'package:flutter_slidable/src/actions.dart';
import 'package:flutter_slidable/src/controller.dart';
import 'package:flutter_slidable/src/slidable.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  testWidgets(
    'supports controllers created from SingleTickerProviderStateMixin',
    (tester) async {
      await tester.pumpWidget(const _SingleTickerHost());

      expect(tester.takeException(), isNull);
      expect(find.byType(Slidable), findsOneWidget);
    },
  );

  testWidgets(
    'locks drawer direction and rubber bands during one horizontal drag',
    (tester) async {
      await _pumpDirectionalLockSlidable(tester);
      final child = find.byKey(_childKey);
      final initialLeft = tester.getTopLeft(child).dx;

      final gesture = await tester.startGesture(tester.getCenter(child));
      await gesture.moveBy(const Offset(-160, 0));
      await tester.pump();

      expect(find.byKey(_endPaneKey), findsOneWidget);
      expect(find.byKey(_startPaneKey), findsNothing);

      await gesture.moveBy(const Offset(220, 0));
      await tester.pump();

      final overdrag = tester.getTopLeft(child).dx - initialLeft;
      expect(find.byKey(_endPaneKey), findsOneWidget);
      expect(find.byKey(_startPaneKey), findsNothing);
      expect(overdrag, greaterThan(0));
      expect(overdrag, lessThanOrEqualTo(_maxRubberBandExtent));

      await gesture.up();
      expect(tester.getTopLeft(child).dx - initialLeft, closeTo(overdrag, 0.1));

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      final settlingOverdrag = tester.getTopLeft(child).dx - initialLeft;
      expect(settlingOverdrag, greaterThan(0));
      expect(settlingOverdrag, lessThan(overdrag));

      await tester.pumpAndSettle();

      expect(tester.getTopLeft(child).dx, closeTo(initialLeft, 0.1));
      expect(find.byKey(_endPaneKey), findsNothing);
      expect(find.byKey(_startPaneKey), findsNothing);
    },
  );

  testWidgets('can infer the opposite drawer after settling neutral', (
    tester,
  ) async {
    await _pumpDirectionalLockSlidable(tester);
    final child = find.byKey(_childKey);
    final initialLeft = tester.getTopLeft(child).dx;

    final firstGesture = await tester.startGesture(tester.getCenter(child));
    await firstGesture.moveBy(const Offset(-160, 0));
    await tester.pump();
    await firstGesture.moveBy(const Offset(220, 0));
    await tester.pump();
    await firstGesture.up();
    await tester.pumpAndSettle();

    final secondGesture = await tester.startGesture(tester.getCenter(child));
    await secondGesture.moveBy(const Offset(120, 0));
    await tester.pump();

    expect(find.byKey(_startPaneKey), findsOneWidget);
    expect(find.byKey(_endPaneKey), findsNothing);
    expect(tester.getTopLeft(child).dx, greaterThan(initialLeft));

    await secondGesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('keeps an already-open drawer locked while dragging closed', (
    tester,
  ) async {
    await _pumpDirectionalLockSlidable(tester, childOpensEndPane: true);
    final child = find.byKey(_childKey);
    final initialLeft = tester.getTopLeft(child).dx;

    await tester.tap(child);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(child).dx, lessThan(initialLeft));
    expect(find.byKey(_endPaneKey), findsOneWidget);

    final gesture = await tester.startGesture(tester.getCenter(child));
    await gesture.moveBy(const Offset(260, 0));
    await tester.pump();

    final overdrag = tester.getTopLeft(child).dx - initialLeft;
    expect(find.byKey(_endPaneKey), findsOneWidget);
    expect(find.byKey(_startPaneKey), findsNothing);
    expect(overdrag, greaterThan(0));
    expect(overdrag, lessThanOrEqualTo(_maxRubberBandExtent));

    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets('locks drawer intent using text direction in RTL', (
    tester,
  ) async {
    await _pumpDirectionalLockSlidable(
      tester,
      textDirection: TextDirection.rtl,
    );
    final child = find.byKey(_childKey);
    final initialLeft = tester.getTopLeft(child).dx;

    final gesture = await tester.startGesture(tester.getCenter(child));
    await gesture.moveBy(const Offset(-160, 0));
    await tester.pump();

    expect(find.byKey(_startPaneKey), findsOneWidget);
    expect(find.byKey(_endPaneKey), findsNothing);

    await gesture.moveBy(const Offset(220, 0));
    await tester.pump();

    final overdrag = tester.getTopLeft(child).dx - initialLeft;
    expect(find.byKey(_startPaneKey), findsOneWidget);
    expect(find.byKey(_endPaneKey), findsNothing);
    expect(overdrag, greaterThan(0));
    expect(overdrag, lessThanOrEqualTo(_maxRubberBandExtent));

    await gesture.up();
    await tester.pumpAndSettle();
  });
}

class _SingleTickerHost extends StatefulWidget {
  const _SingleTickerHost();

  @override
  State<_SingleTickerHost> createState() => _SingleTickerHostState();
}

class _SingleTickerHostState extends State<_SingleTickerHost>
    with SingleTickerProviderStateMixin {
  late final SlidableController controller;

  @override
  void initState() {
    super.initState();
    controller = SlidableController(this);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Slidable(
        controller: controller,
        startActionPane: ActionPane(
          motion: const BehindMotion(),
          children: [SlidableAction(onPressed: (_) {}, icon: Icons.check)],
        ),
        endActionPane: ActionPane(
          motion: const BehindMotion(),
          children: [SlidableAction(onPressed: (_) {}, icon: Icons.delete)],
        ),
        child: const SizedBox(width: 100, height: 40),
      ),
    );
  }
}

const _childKey = ValueKey('direction_lock_child');
const _startPaneKey = ValueKey('direction_lock_start_pane');
const _endPaneKey = ValueKey('direction_lock_end_pane');
const _slidableWidth = 400.0;
const _slidableHeight = 80.0;
const _maxRubberBandExtent = _slidableWidth * 0.08;

Future<void> _pumpDirectionalLockSlidable(
  WidgetTester tester, {
  TextDirection textDirection = TextDirection.ltr,
  bool childOpensEndPane = false,
}) async {
  await tester.pumpWidget(
    Directionality(
      textDirection: textDirection,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: _slidableWidth,
          height: _slidableHeight,
          child: Slidable(
            startActionPane: ActionPane(
              key: _startPaneKey,
              motion: const BehindMotion(),
              children: [
                SlidableAction(onPressed: (_) {}, icon: Icons.archive),
              ],
            ),
            endActionPane: ActionPane(
              key: _endPaneKey,
              motion: const BehindMotion(),
              children: [SlidableAction(onPressed: (_) {}, icon: Icons.delete)],
            ),
            child: Builder(
              builder: (context) {
                const content = ColoredBox(
                  color: Colors.white,
                  child: SizedBox.expand(child: Text('Slide me')),
                );
                if (childOpensEndPane) {
                  return GestureDetector(
                    key: _childKey,
                    onTap: () {
                      Slidable.of(context)!
                          .openEndActionPane(duration: Duration.zero);
                    },
                    child: content,
                  );
                }
                return const SizedBox.expand(key: _childKey, child: content);
              },
            ),
          ),
        ),
      ),
    ),
  );
}

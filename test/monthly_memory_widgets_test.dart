import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moodiary/components/monthly_diary/memory_bubble_field.dart';
import 'package:moodiary/components/monthly_diary/month_package_card.dart';

Widget _host(
  Widget child, {
  double textScale = 1,
  bool reduceMotion = true,
  bool accessibleNavigation = false,
  bool ticking = true,
  Brightness brightness = Brightness.light,
}) => MaterialApp(
  theme: ThemeData(colorSchemeSeed: Colors.green, brightness: brightness),
  home: MediaQuery(
    data: MediaQueryData(
      textScaler: TextScaler.linear(textScale),
      disableAnimations: reduceMotion,
      accessibleNavigation: accessibleNavigation,
    ),
    child: TickerMode(
      enabled: ticking,
      child: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: child,
        ),
      ),
    ),
  ),
);

MonthPackageCard _package(
  VoidCallback onTap, {
  List<Widget> photos = const [],
}) => MonthPackageCard(
  month: DateTime(2026, 11),
  title: 'November 2026',
  subtitle: '18 days · 23 entries',
  openLabel: 'Open this month',
  semanticsLabel: 'November 2026, 18 days, 23 entries',
  photos: photos,
  onTap: onTap,
);

MemoryDayBubble _bubble(
  int day,
  VoidCallback onTap, {
  Widget? photo,
  int count = 1,
}) => MemoryDayBubble(
  key: ValueKey('bubble-$day'),
  day: DateTime(2026, 11, day),
  dateLabel: 'November $day',
  excerpt: 'We walked by the river after the rain. The water was quiet.',
  semanticsLabel: 'November $day, $count diary entries',
  entryCount: count,
  photo: photo,
  onTap: onTap,
);

void main() {
  testWidgets('the whole paper package activates and exposes one button', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var opened = 0;
    await tester.pumpWidget(_host(_package(() => opened++)));
    await tester.tap(find.byType(MonthPackageCard));
    expect(opened, 1);
    expect(
      tester.getSemantics(
        find.bySemanticsLabel('November 2026, 18 days, 23 entries'),
      ),
      matchesSemantics(
        label: 'November 2026, 18 days, 23 entries',
        isButton: true,
        isFocusable: true,
        hasTapAction: true,
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(opened, 2);
    semantics.dispose();
  });

  testWidgets(
    'only two photos peek out and photos cannot swallow package taps',
    (tester) async {
      var opened = 0;
      var photoOpened = 0;
      await tester.pumpWidget(
        _host(
          _package(
            () => opened++,
            photos: List.generate(
              3,
              (index) => GestureDetector(
                onTap: () => photoOpened++,
                child: ColoredBox(
                  key: ValueKey('package-photo-$index'),
                  color: Colors.green,
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('package-photo-2')), findsNothing);
      final photoRect = tester.getRect(
        find.byKey(const ValueKey('package-photo-0')),
      );
      await tester.tapAt(Offset(photoRect.center.dx, photoRect.top + 12));
      expect(opened, 1);
      expect(photoOpened, 0);
    },
  );

  for (final hasPhoto in [false, true]) {
    testWidgets(
      'day button activates with photo=$hasPhoto and a readable label',
      (tester) async {
        final semantics = tester.ensureSemantics();
        var opened = 0;
        var photoOpened = 0;
        await tester.pumpWidget(
          _host(
            SizedBox(
              width: 220,
              child: _bubble(
                9,
                () => opened++,
                count: 3,
                photo: hasPhoto
                    ? GestureDetector(
                        onTap: () => photoOpened++,
                        child: const ColoredBox(color: Colors.teal),
                      )
                    : null,
              ),
            ),
          ),
        );
        await tester.tap(find.byType(MemoryDayBubble));
        expect(opened, 1);
        expect(photoOpened, 0);
        expect(find.text('November 9'), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
        expect(
          tester.getSemantics(
            find.bySemanticsLabel('November 9, 3 diary entries'),
          ),
          matchesSemantics(
            label: 'November 9, 3 diary entries',
            isButton: true,
            isFocusable: true,
            hasTapAction: true,
          ),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        expect(opened, 2);
        semantics.dispose();
      },
    );
  }

  for (final width in [320.0, 390.0, 1100.0]) {
    for (final textScale in [1.0, 2.2]) {
      testWidgets(
        '31 days are contained, disjoint and reachable at $width/$textScale',
        (tester) async {
          tester.view.physicalSize = Size(width, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final opened = <int>[];
          await tester.pumpWidget(
            _host(
              MemoryBubbleField(
                children: List.generate(
                  31,
                  (index) => _bubble(
                    index + 1,
                    () => opened.add(index + 1),
                    photo: index.isEven
                        ? const ColoredBox(color: Colors.teal)
                        : null,
                  ),
                ),
              ),
              textScale: textScale,
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          final fieldRect = tester.getRect(find.byType(MemoryBubbleField));
          final rects = List.generate(
            31,
            (index) =>
                tester.getRect(find.byKey(ValueKey('bubble-${index + 1}'))),
          );
          for (var index = 0; index < rects.length; index++) {
            final rect = rects[index];
            expect(rect.left, greaterThanOrEqualTo(fieldRect.left));
            expect(rect.right, lessThanOrEqualTo(fieldRect.right + .01));
            expect(rect.top, greaterThanOrEqualTo(fieldRect.top));
            expect(rect.bottom, lessThanOrEqualTo(fieldRect.bottom + .01));
            expect(rect.width, greaterThanOrEqualTo(48));
            expect(rect.height, greaterThanOrEqualTo(48));
            for (var other = index + 1; other < rects.length; other++) {
              expect(
                rect.overlaps(rects[other]),
                isFalse,
                reason: 'Day ${index + 1} covers day ${other + 1}',
              );
            }
          }
          final positions = rects.map((rect) => rect.topLeft).toList();
          await tester.pump();
          expect(
            List.generate(
              31,
              (index) => tester.getTopLeft(
                find.byKey(ValueKey('bubble-${index + 1}')),
              ),
            ),
            positions,
          );
          for (final day in [1, 16, 31]) {
            final target = find.byKey(ValueKey('bubble-$day'));
            await tester.ensureVisible(target);
            await tester.pumpAndSettle();
            await tester.tap(target);
          }
          expect(opened, [1, 16, 31]);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('package reflows at 320 pixels with large text in both themes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(
        _host(_package(() {}), textScale: 2.2, brightness: brightness),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('November 2026'), findsOneWidget);
      expect(find.text('18 days · 23 entries'), findsOneWidget);
      expect(find.text('Open this month'), findsOneWidget);
    }
  });

  testWidgets(
    'reduced motion and off-route tickers leave no running animation',
    (tester) async {
      for (final reduceMotion in [true, false]) {
        await tester.pumpWidget(
          _host(
            Column(children: [_package(() {}), _bubble(1, () {})]),
            reduceMotion: reduceMotion,
            ticking: reduceMotion,
          ),
        );
        final gesture = await tester.startGesture(
          tester.getCenter(find.byType(MonthPackageCard)),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          tester
              .widget<AnimatedScale>(
                find.descendant(
                  of: find.byType(MonthPackageCard),
                  matching: find.byType(AnimatedScale),
                ),
              )
              .scale,
          1,
        );
        await gesture.up();
        await tester.pumpAndSettle();
        expect(tester.binding.transientCallbackCount, 0);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('disabled first mount releases motion resources on disposal', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_bubble(1, () {})));
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets(
    'ambient art moves gently while its date and tap area stay fixed',
    (tester) async {
      await tester.pumpWidget(
        _host(
          SizedBox(
            width: 220,
            child: _bubble(
              1,
              () {},
              photo: const ColoredBox(
                key: ValueKey('moving-photo'),
                color: Colors.teal,
              ),
            ),
          ),
          reduceMotion: false,
        ),
      );
      final initialArt = tester.getTopLeft(
        find.byKey(const ValueKey('moving-photo')),
      );
      final initialDate = tester.getTopLeft(find.text('November 1'));
      final initialTarget = tester.getRect(find.byType(MemoryDayBubble));
      await tester.pump(const Duration(milliseconds: 1500));
      final movedArt = tester.getTopLeft(
        find.byKey(const ValueKey('moving-photo')),
      );
      expect((movedArt - initialArt).distance, greaterThan(.1));
      expect((movedArt - initialArt).distance, lessThanOrEqualTo(4.1));
      expect(tester.getTopLeft(find.text('November 1')), initialDate);
      expect(tester.getRect(find.byType(MemoryDayBubble)), initialTarget);

      for (final policy in [
        (reduce: true, accessible: false, ticking: true),
        (reduce: false, accessible: true, ticking: true),
        (reduce: false, accessible: false, ticking: false),
      ]) {
        await tester.pumpWidget(
          _host(
            SizedBox(
              width: 220,
              child: _bubble(
                1,
                () {},
                photo: const ColoredBox(
                  key: ValueKey('moving-photo'),
                  color: Colors.teal,
                ),
              ),
            ),
            reduceMotion: policy.reduce,
            accessibleNavigation: policy.accessible,
            ticking: policy.ticking,
          ),
        );
        await tester.pumpAndSettle();
        final restingArt = tester.getTopLeft(
          find.byKey(const ValueKey('moving-photo')),
        );
        await tester.pump(const Duration(seconds: 2));
        expect(
          tester.getTopLeft(find.byKey(const ValueKey('moving-photo'))),
          restingArt,
        );
        expect(tester.binding.transientCallbackCount, 0);
      }
    },
  );
}

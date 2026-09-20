import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:overwatch_mystery_heroes/board_view.dart';

void main() {
  const tanks = ['Reinhardt', 'Zarya', 'Sigma'];
  const damage = ['Ashe', 'Genji'];

  Widget wrap({
    required Set<String> completed,
    void Function(String hero)? onToggle,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: HeroBoard(
          title: 'Mystery Heroes',
          columns: const [
            BoardColumn(label: 'TANKS', heroes: tanks, tilesPerRow: 3),
            BoardColumn(label: 'DPS', heroes: damage, tilesPerRow: 2),
          ],
          completedHeroes: completed,
          onToggleHero: onToggle ?? (_) {},
          // Real portraits aren't bundled into the test asset manifest, so the
          // tiles fall back to their initial — harmless for these assertions.
          assetPathFor: (hero) => 'assets/missing.webp',
        ),
      ),
    );
  }

  testWidgets('shows the completed tally out of the full roster',
      (tester) async {
    await tester.pumpWidget(wrap(completed: {'Zarya', 'Genji'}));

    expect(find.text('2/5'), findsOneWidget);
  });

  testWidgets('counts only heroes that are on the board', (tester) async {
    await tester.pumpWidget(wrap(completed: {'Zarya', 'Sombra'}));

    expect(find.text('1/5'), findsOneWidget);
  });

  testWidgets('renders a label per role and a tile per hero', (tester) async {
    await tester.pumpWidget(wrap(completed: const {}));

    expect(find.text('TANKS'), findsOneWidget);
    expect(find.text('DPS'), findsOneWidget);
    expect(find.byType(Tooltip), findsNWidgets(tanks.length + damage.length));
  });

  testWidgets('tapping a hero reports that hero', (tester) async {
    final toggled = <String>[];
    await tester.pumpWidget(wrap(completed: const {}, onToggle: toggled.add));

    await tester.tap(find.byTooltip('Genji'));
    await tester.pump();

    expect(toggled, ['Genji']);
  });
}

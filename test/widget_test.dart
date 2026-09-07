import 'package:flutter_test/flutter_test.dart';
import 'package:holy_bible/app/app.dart';
import 'package:holy_bible/app/data/repository.dart';
import 'package:holy_bible/app/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('first run shows the onboarding tour, then the home shell',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(BibleRepository());
    await store.load();

    await tester.pumpWidget(SelahApp(store: store));
    await tester.pump();
    expect(find.text('The whole Bible, offline'), findsOneWidget);

    // Skip the tour; the app swaps to the home shell.
    await tester.tap(find.text('Skip'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('Selah boots and shows the home shell', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(BibleRepository());
    await store.load();
    store.setOnboarded();

    await tester.pumpWidget(SelahApp(store: store));
    await tester.pump();

    // The brand and navigation destinations render immediately.
    expect(find.text('SELAH'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Reader'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Plans'), findsOneWidget);

    // Home quick actions (scroll them into view first).
    await tester.pump(const Duration(milliseconds: 50));
    await tester.scrollUntilVisible(find.text('Random chapter'), 200);
    expect(find.text('Random chapter'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Memorize'), 200);
    expect(find.text('Memorize'), findsOneWidget);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:holy_bible/app/app.dart';
import 'package:holy_bible/app/data/repository.dart';
import 'package:holy_bible/app/store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('Selah boots and shows the home shell', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore(BibleRepository());
    await store.load();

    await tester.pumpWidget(SelahApp(store: store));
    await tester.pump();

    // The brand and navigation destinations render immediately.
    expect(find.text('SELAH'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Reader'), findsOneWidget);
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);
    expect(find.text('Plans'), findsOneWidget);

    // Home quick actions.
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Random chapter'), findsOneWidget);
    expect(find.text('Memorize'), findsOneWidget);
  });
}

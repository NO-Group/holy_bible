import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/data/repository.dart';
import 'app/store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = AppStore(BibleRepository());
  await store.load();
  runApp(SelahApp(store: store));
}

/// Root application widget: theme wiring, app scope and home shell.
library;

import 'package:flutter/material.dart';

import 'store.dart';
import 'theme.dart';
import 'ui/home_shell.dart';
import 'ui/intro_page.dart';
import 'ui/scope.dart';

class SelahApp extends StatelessWidget {
  final AppStore store;

  const SelahApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) {
    return AppScope(
      store: store,
      child: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final theme = resolveThemeId(
            store.themeId,
            WidgetsBinding.instance.platformDispatcher.platformBrightness,
          );
          return MaterialApp(
            key: ValueKey(store.onboarded),
            title: 'Selah — Holy Bible',
            debugShowCheckedModeBanner: false,
            theme: theme.build(),
            home: store.onboarded
                ? const HomeShell()
                : const IntroPage(),
          );
        },
      ),
    );
  }
}

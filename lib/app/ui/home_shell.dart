/// Bottom-navigation shell hosting Home, Library, Reader, Search and more
/// (Settings & Stats are pushed from Home; Plans & Quiz are separate tabs
/// via the expandable "More" section).
library;

import 'package:flutter/material.dart';

import 'scope.dart';
import 'home_page.dart';
import 'library_page.dart';
import 'plans_page.dart';
import 'quiz_page.dart';
import 'reader_page.dart';
import 'search_page.dart';

class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      body: IndexedStack(
        index: app.navIndex,
        children: const [
          HomePage(),
          LibraryPage(),
          ReaderTabView(),
          SearchPage(),
          PlansPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: app.navIndex,
        onDestinationSelected: (i) => app.goTo(i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view),
            label: 'Library',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_stories_outlined),
            selectedIcon: Icon(Icons.auto_stories),
            label: 'Reader',
          ),
          NavigationDestination(
            icon: Icon(Icons.search),
            selectedIcon: Icon(Icons.search),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.track_changes),
            selectedIcon: Icon(Icons.track_changes),
            label: 'Plans',
          ),
        ],
      ),
    );
  }
}

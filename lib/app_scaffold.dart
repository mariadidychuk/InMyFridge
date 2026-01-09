import 'package:flutter/material.dart';

// App tab screens (BottomNavigationBar destinations)
import 'screens/recipes_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/bookmarks_screen.dart';
import 'screens/fridge_screen.dart';

/// Root scaffold for the application.
/// Hosts the BottomNavigationBar and keeps tab state using [IndexedStack].
class AppScaffold extends StatefulWidget {
  const AppScaffold({super.key});

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  /// Current selected tab index (default: Fridge).
  int _index = 3;

  /// Tab pages. Stored as const to avoid unnecessary rebuilds.
  final _screens = const [
    RecipesScreen(),
    CalendarScreen(),
    BookmarksScreen(),
    FridgeScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF6F2),

      // Keeps inactive tabs mounted (e.g., calendar selection is not reset)
      body: IndexedStack(
        index: _index,
        children: _screens,
      ),

      // Custom-styled bottom navigation container (rounded + shadow)
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BottomNavigationBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              type: BottomNavigationBarType.fixed,
              currentIndex: _index,
              onTap: (i) => setState(() => _index = i),
              selectedItemColor: const Color(0xFFD87C5A),
              unselectedItemColor: const Color(0xFF8C8C8C),
              selectedLabelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              showUnselectedLabels: true,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.restaurant_menu),
                  label: 'Recipes',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.calendar_month),
                  label: 'Calendar',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.bookmark),
                  label: 'Bookmarks',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.kitchen),
                  label: 'Fridge',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

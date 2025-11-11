import 'package:flutter/material.dart';

// Import the screen files
import 'screens/recipes_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/bookmarks_screen.dart';
import 'screens/fridge_screen.dart';

/// Root widget that holds the bottom navigation bar and all main screens.
/// This file defines the app "skeleton" — one shared Scaffold for all tabs.
/// Once created, you won't need to modify main.dart again.
class AppScaffold extends StatefulWidget {
  const AppScaffold({super.key});

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  // Keeps track of the current tab index (0–3)
  int _index = 3; // start on Fridge tab (index 3)

  // List of screens displayed for each tab
  final _screens = const [
    RecipesScreen(),
    CalendarScreen(),
    BookmarksScreen(),
    FridgeScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Background matches Figma color palette
      backgroundColor: const Color(0xFFFFF6F2),

      // Display the current screen
      body: _screens[_index],

      // Custom rounded bottom navigation bar
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
        child: Container(
          height: 64,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              // soft floating shadow like in the mockup
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 12,
                offset: Offset(0, 4),
              ),
            ],
          ),

          // ClipRRect keeps the bottom bar fully rounded
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BottomNavigationBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              type: BottomNavigationBarType.fixed,
              currentIndex: _index,

              // Update index when user taps a tab
              onTap: (i) => setState(() => _index = i),

              // Colors & styles to match your Figma design
              selectedItemColor: const Color(0xFFD87C5A), // active orange
              unselectedItemColor: const Color(0xFF8C8C8C), // muted gray
              selectedLabelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              showUnselectedLabels: true,

              // Bottom navigation items
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
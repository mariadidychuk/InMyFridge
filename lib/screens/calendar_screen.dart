import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/recipe.dart';
import 'recipe_details_screen.dart';

/// CalendarScreen (MVP):
/// - User selects a day and plans recipes for that date
/// - Persisted locally via Hive:
///   calendarBox[ "YYYY-MM-DD" ] = JSON string of List<String> recipeIds
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  // App colors (match the rest of the UI / Figma)
  static const _bg = Color(0xFFFFF6F2);
  static const _accent = Color(0xFFD87C5A);

  /// Currently selected date (used for the "Planned recipes" list)
  late DateTime _selectedDate;

  /// Currently visible month/day in the calendar (used for month navigation)
  late DateTime _focusedDay;

  /// We keep month-only view for MVP (simpler and looks "finished")
  final CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();

    // Important: we store dates without time, so day comparisons and Hive keys are stable
    _selectedDate = _stripTime(DateTime.now());
    _focusedDay = _selectedDate;
  }

  /// Removes time component (00:00) to avoid bugs like:
  /// "same day but different hour" => different Hive keys / selection mismatch.
  DateTime _stripTime(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Converts date into a stable Hive key: "YYYY-MM-DD"
  /// Example: 2026-01-07
  String _dateKey(DateTime d) =>
      "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  /// Month label for our custom header (TableCalendar header is hidden)
  /// NOTE: Name says "De", but list is English -> acceptable for MVP; can be localized later.
  String _monthNameDe(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  /// Adds/subtracts months while keeping day valid (e.g., Jan 31 -> Feb 28/29)
  DateTime _addMonths(DateTime date, int months) {
    final y = date.year + ((date.month - 1 + months) ~/ 12);
    final m = ((date.month - 1 + months) % 12) + 1;
    final lastDay = DateTime(y, m + 1, 0).day;
    final d = date.day > lastDay ? lastDay : date.day;
    return DateTime(y, m, d);
  }

  /// Reads planned recipe IDs for a date from Hive.
  /// Stored format: jsonEncode(List<String>)
  List<String> _getPlannedIds(Box<String> calendarBox, DateTime date) {
    final raw = calendarBox.get(_dateKey(date));
    if (raw == null || raw.isEmpty) return [];

    // Decode JSON string -> List<dynamic> -> List<String>
    final decoded = jsonDecode(raw);
    return (decoded as List).map((e) => e.toString()).toList();
  }

  /// Writes planned recipe IDs back to Hive (persistent storage).
  Future<void> _setPlannedIds(
    Box<String> calendarBox,
    DateTime date,
    List<String> ids,
  ) async {
    await calendarBox.put(_dateKey(date), jsonEncode(ids));
  }

  /// Toggle behavior:
  /// - if recipe is already planned for this day -> remove it
  /// - otherwise -> add it
  ///
  /// Implementation detail: we use Set to prevent duplicates.
  Future<void> _togglePlanned(
    Box<String> calendarBox,
    DateTime date,
    String recipeId,
  ) async {
    final set = _getPlannedIds(calendarBox, date).toSet();

    if (set.contains(recipeId)) {
      set.remove(recipeId);
    } else {
      set.add(recipeId);
    }

    await _setPlannedIds(calendarBox, date, set.toList());
  }

  /// Loads all recipes from Hive recipesBox, parses JSON, sorts by name.
  /// Used for the "Add recipe" bottom sheet.
  List<Recipe> _loadAllRecipes(Box<String> recipesBox) {
    final out = <Recipe>[];

    for (final raw in recipesBox.values) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        out.add(Recipe.fromMap(map));
      } catch (_) {
        // If one entry is corrupted, we ignore it to keep UI stable (no crash).
      }
    }

    out.sort((a, b) => a.name.compareTo(b.name));
    return out;
  }

  /// Builds a lookup map {recipeId -> Recipe} for fast resolving:
  /// plannedIds (strings) -> full Recipe objects for UI.
  Map<String, Recipe> _recipesById(Box<String> recipesBox) {
    final m = <String, Recipe>{};

    for (final entry in recipesBox.toMap().entries) {
      try {
        final map = jsonDecode(entry.value) as Map<String, dynamic>;
        final r = Recipe.fromMap(map);
        m[r.id] = r;
      } catch (_) {
        // Ignore invalid entries to prevent crashes.
      }
    }

    return m;
  }

  /// Opens a bottom sheet:
  /// - shows Bookmarks (favorites) first
  /// - then shows All recipes
  ///
  /// When user taps a recipe, it is toggled for the selected day and stored in Hive.
  Future<void> _openAddRecipeSheet() async {
    final recipesBox = Hive.box<String>('recipesBox');
    final favoritesBox = Hive.box<String>('favoritesBox');

    // Full list (sorted)
    final all = _loadAllRecipes(recipesBox);

    // Favorites are stored as IDs in favoritesBox (values)
    final favIds = favoritesBox.values.toSet();
    final favorites = all.where((r) => favIds.contains(r.id)).toList();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: _bg,
      builder: (sheetContext) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.7,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Add recipe to selected day',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView(
                      children: [
                        if (favorites.isNotEmpty) ...[
                          _sectionTitle('Bookmarks'),
                          const SizedBox(height: 8),
                          ...favorites.map((r) => _pickTile(sheetContext, r)),
                          const SizedBox(height: 12),
                        ],
                        _sectionTitle('All recipes'),
                        const SizedBox(height: 8),
                        ...all.map((r) => _pickTile(sheetContext, r)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Small UI helper for section titles in the bottom sheet
  Widget _sectionTitle(String text) {
    return Row(
      children: [
        Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      ],
    );
  }

  /// Tile inside bottom sheet:
  /// - tap => toggles recipe for the selected date (Hive write)
  /// - then closes the sheet
  Widget _pickTile(BuildContext sheetContext, Recipe recipe) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(recipe.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('${recipe.timeMinutes} min'),
      trailing: const Icon(Icons.add_circle_outline, color: _accent),
      onTap: () async {
        final calendarBox = Hive.box<String>('calendarBox');

        // Persist change: add/remove the recipe id for the selected date
        await _togglePlanned(calendarBox, _selectedDate, recipe.id);

        // Safety: avoid calling Navigator if widget already disposed
        if (!mounted) return;

        Navigator.pop(sheetContext);
      },
    );
  }

  /// Custom calendar day cell:
  /// - accent background for selected day
  /// - grey background for today
  Widget _dayCell({
    required DateTime day,
    required bool isSelected,
    required bool isToday,
  }) {
    final bg = isSelected ? _accent : (isToday ? const Color(0xFFE6E6E6) : null);
    final textColor = isSelected ? Colors.white : Colors.black87;

    return Center(
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
        ),
        child: Text(
          '${day.day}',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Hive boxes used by this screen:
    // - calendarBox: dateKey -> JSON list of recipeIds
    // - recipesBox: recipe data as JSON strings
    final calendarBox = Hive.box<String>('calendarBox');
    final recipesBox = Hive.box<String>('recipesBox');

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,

        // This is a tab screen, so we remove the back arrow (no nested navigation)
        automaticallyImplyLeading: false,
        leading: null,

        title: const Text('Calendar', style: TextStyle(fontWeight: FontWeight.w600)),
        centerTitle: true,

        // "Today" button: quick reset to current date
        actions: [
          TextButton(
            onPressed: () {
              final today = _stripTime(DateTime.now());
              setState(() {
                _selectedDate = today;
                _focusedDay = today;
              });
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.black87,
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Text('Today', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),

      /// ValueListenableBuilder makes this screen reactive to Hive changes:
      /// - when calendarBox changes (put/delete), UI rebuilds automatically
      /// - planned list and markers update without manual refresh
      body: ValueListenableBuilder(
        valueListenable: calendarBox.listenable(),
        builder: (_, __, ___) {
          // 1) Read planned recipe ids for selected date
          final plannedIds = _getPlannedIds(calendarBox, _selectedDate);

          // 2) Resolve ids -> full Recipe objects using a lookup map
          final byId = _recipesById(recipesBox);
          final plannedRecipes =
              plannedIds.map((id) => byId[id]).whereType<Recipe>().toList();

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Custom month header + navigation (instead of TableCalendar header)
                Row(
                  children: [
                    Text(
                      _monthNameDe(_focusedDay.month),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                        color: _accent,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.chevron_left, color: _accent),
                      onPressed: () {
                        setState(() {
                          _focusedDay = _stripTime(_addMonths(_focusedDay, -1));
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right, color: _accent),
                      onPressed: () {
                        setState(() {
                          _focusedDay = _stripTime(_addMonths(_focusedDay, 1));
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Calendar UI
                TableCalendar(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2035, 12, 31),
                  focusedDay: _focusedDay,
                  calendarFormat: _calendarFormat,
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  headerVisible: false,

                  // Defines which day is shown as selected
                  selectedDayPredicate: (day) => isSameDay(day, _selectedDate),

                  // User selects a day -> update state (UI + planned list)
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDate = _stripTime(selectedDay);
                      _focusedDay = _stripTime(focusedDay);
                    });
                  },

                  // When user swipes months, we update focusedDay
                  // (setState is not required for internal calendar animation,
                  // but we need focusedDay for our custom header)
                  onPageChanged: (focusedDay) {
                    _focusedDay = _stripTime(focusedDay);
                  },

                  // Provides "events" per day: here it's list of planned recipe IDs
                  // Used by markerBuilder to show dots on days with planned recipes
                  eventLoader: (day) => _getPlannedIds(calendarBox, _stripTime(day)),

                  calendarStyle: const CalendarStyle(
                    outsideDaysVisible: false,
                    markersMaxCount: 0, // we draw markers manually
                    defaultTextStyle: TextStyle(color: Colors.black87),
                    weekendTextStyle: TextStyle(color: Colors.black87),
                  ),

                  calendarBuilders: CalendarBuilders(
                    defaultBuilder: (context, day, focusedDay) => _dayCell(
                      day: day,
                      isSelected: isSameDay(day, _selectedDate),
                      isToday: isSameDay(day, DateTime.now()),
                    ),
                    todayBuilder: (context, day, focusedDay) => _dayCell(
                      day: day,
                      isSelected: isSameDay(day, _selectedDate),
                      isToday: true,
                    ),
                    selectedBuilder: (context, day, focusedDay) => _dayCell(
                      day: day,
                      isSelected: true,
                      isToday: isSameDay(day, DateTime.now()),
                    ),

                    // Dots under a day: indicates planned recipes count (max 3 dots)
                    markerBuilder: (context, day, events) {
                      if (events.isEmpty) return const SizedBox.shrink();
                      final dots = events.length >= 3 ? 3 : events.length;

                      return Positioned(
                        bottom: 6,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(dots, (_) {
                            return Container(
                              width: 5,
                              height: 5,
                              margin: const EdgeInsets.symmetric(horizontal: 1.2),
                              decoration: const BoxDecoration(
                                color: _accent,
                                shape: BoxShape.circle,
                              ),
                            );
                          }),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // Planned list header + Add button
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Planned recipes',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _openAddRecipeSheet,
                      icon: const Icon(Icons.add, color: _accent),
                      label: const Text('Add', style: TextStyle(color: _accent)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Planned recipes list for the selected date
                Expanded(
                  child: plannedRecipes.isEmpty
                      ? _emptyState()
                      : ListView.separated(
                          itemCount: plannedRecipes.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (_, i) => _plannedCard(plannedRecipes[i]),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Empty state shown when no recipes are planned for selected day
  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black12),
      ),
      child: const Text(
        'No recipes planned for this day.\nTap "Add" to plan a meal.',
        style: TextStyle(color: Colors.black54),
      ),
    );
  }

  /// Card in "Planned recipes" list:
  /// - tap card => open RecipeDetailsScreen
  /// - tap trash icon => remove this recipe from selected day (Hive update)
  Widget _plannedCard(Recipe recipe) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RecipeDetailsScreen(
              recipe: recipe,

              // For MVP we don't compute have/missing here
              // (details screen can still display recipe normally)
              haveIngredientsLower: const [],
              missingIngredientsLower: const [],
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black12),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEFE8),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.restaurant_menu, color: _accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(recipe.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text('${recipe.timeMinutes} min', style: const TextStyle(color: Colors.black54)),
                ],
              ),
            ),

            // Removes recipe from the selected day (toggle)
            IconButton(
              onPressed: () async {
                final calendarBox = Hive.box<String>('calendarBox');
                await _togglePlanned(calendarBox, _selectedDate, recipe.id);
              },
              icon: const Icon(Icons.delete_outline, color: Colors.black54),
              tooltip: 'Remove from day',
            ),
          ],
        ),
      ),
    );
  }
}
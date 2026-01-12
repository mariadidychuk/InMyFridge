import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:table_calendar/table_calendar.dart';

import '../models/recipe.dart';
import 'recipe_details_screen.dart';

/// Calendar screen (MVP)
/// The user can assign recipes to specific dates.
/// Data is stored locally in Hive:
/// calendarBox["YYYY-MM-DD"] = JSON encoded List<String> (recipeIds)
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  // Basic app colors (same palette as other screens)
  static const _bg = Color(0xFFFFF6F2);
  static const _accent = Color(0xFFD87C5A);

  // Selected day (used for the list below the calendar)
  late DateTime _selectedDate;

  // Month currently shown in the calendar (used for custom header)
  late DateTime _focusedDay;

  // Keep month view only (sufficient for MVP)
  final CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();

    // Dates are saved without time (00:00) to keep Hive keys stable
    _selectedDate = _stripTime(DateTime.now());
    _focusedDay = _selectedDate;
  }

  // Returns the date without time part (00:00)
  DateTime _stripTime(DateTime d) => DateTime(d.year, d.month, d.day);

  // Converts a date into a stable key used in Hive (YYYY-MM-DD)
  String _dateKey(DateTime d) =>
      "${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  // Month name for the custom header (English for now; can be localized later)
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

  // Adds/subtracts months and keeps the day valid (e.g. 31 -> 28/29)
  DateTime _addMonths(DateTime date, int months) {
    final y = date.year + ((date.month - 1 + months) ~/ 12);
    final m = ((date.month - 1 + months) % 12) + 1;
    final lastDay = DateTime(y, m + 1, 0).day;
    final d = date.day > lastDay ? lastDay : date.day;
    return DateTime(y, m, d);
  }

  // Reads the planned recipe IDs for one date from Hive
  List<String> _getPlannedIds(Box<String> calendarBox, DateTime date) {
    final raw = calendarBox.get(_dateKey(date));
    if (raw == null || raw.isEmpty) return [];

    final decoded = jsonDecode(raw);
    return (decoded as List).map((e) => e.toString()).toList();
  }

  // Writes the planned recipe IDs for one date back to Hive
  Future<void> _setPlannedIds(
    Box<String> calendarBox,
    DateTime date,
    List<String> ids,
  ) async {
    await calendarBox.put(_dateKey(date), jsonEncode(ids));
  }

  // Adds/removes one recipe ID for a selected date
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

  // Loads all recipes from recipesBox and sorts them by name (used in bottom sheet)
  List<Recipe> _loadAllRecipes(Box<String> recipesBox) {
    final out = <Recipe>[];

    for (final raw in recipesBox.values) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        out.add(Recipe.fromMap(map));
      } catch (_) {
        // Ignore invalid entries to avoid breaking the UI
      }
    }

    out.sort((a, b) => a.name.compareTo(b.name));
    return out;
  }

  // Builds a map for quick access: { recipeId -> Recipe }
  Map<String, Recipe> _recipesById(Box<String> recipesBox) {
    final m = <String, Recipe>{};

    for (final entry in recipesBox.toMap().entries) {
      try {
        final map = jsonDecode(entry.value) as Map<String, dynamic>;
        final r = Recipe.fromMap(map);
        m[r.id] = r;
      } catch (_) {
        // Skip invalid entries
      }
    }

    return m;
  }

  // Bottom sheet for selecting a recipe and adding it to the selected day
  Future<void> _openAddRecipeSheet() async {
    final recipesBox = Hive.box<String>('recipesBox');
    final favoritesBox = Hive.box<String>('favoritesBox');

    final all = _loadAllRecipes(recipesBox);

    // favoritesBox stores recipe IDs
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

  // Section header text for the bottom sheet
  Widget _sectionTitle(String text) {
    return Row(
      children: [
        Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
      ],
    );
  }

  // One row in the bottom sheet (tap = toggle planned recipe for the selected day)
  Widget _pickTile(BuildContext sheetContext, Recipe recipe) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(recipe.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('${recipe.timeMinutes} min'),
      trailing: const Icon(Icons.add_circle_outline, color: _accent),
      onTap: () async {
        final calendarBox = Hive.box<String>('calendarBox');

        await _togglePlanned(calendarBox, _selectedDate, recipe.id);

        if (!mounted) return;
        Navigator.pop(sheetContext);
      },
    );
  }

  // Day cell used for default/today/selected builders
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
    // calendarBox: dateKey -> JSON list of recipeIds
    // recipesBox: recipe JSON data
    final calendarBox = Hive.box<String>('calendarBox');
    final recipesBox = Hive.box<String>('recipesBox');

    return Scaffold(
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,

        // This screen is opened via bottom navigation, so no back button here
        automaticallyImplyLeading: false,
        leading: null,

        title: const Text('Calendar'),
        centerTitle: true,

        // Quick jump to today
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

      // Rebuild the screen when calendarBox changes (add/remove planned recipes)
      body: ValueListenableBuilder(
        valueListenable: calendarBox.listenable(),
        builder: (_, __, ___) {
          final plannedIds = _getPlannedIds(calendarBox, _selectedDate);

          final byId = _recipesById(recipesBox);
          final plannedRecipes =
              plannedIds.map((id) => byId[id]).whereType<Recipe>().toList();

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Custom month header (TableCalendar header is disabled)
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

                TableCalendar(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2035, 12, 31),
                  focusedDay: _focusedDay,
                  calendarFormat: _calendarFormat,
                  startingDayOfWeek: StartingDayOfWeek.monday,
                  headerVisible: false,

                  selectedDayPredicate: (day) => isSameDay(day, _selectedDate),

                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDate = _stripTime(selectedDay);
                      _focusedDay = _stripTime(focusedDay);
                    });
                  },

                  // Update focused month when user swipes
                  onPageChanged: (focusedDay) {
                    _focusedDay = _stripTime(focusedDay);
                  },

                  // Used for marker dots
                  eventLoader: (day) => _getPlannedIds(calendarBox, _stripTime(day)),

                  calendarStyle: const CalendarStyle(
                    outsideDaysVisible: false,
                    markersMaxCount: 0,
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

                    // Dots under the day number (max 3)
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

  // Shown when there are no planned recipes for the selected day
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

  // One card in the planned list (tap opens details, trash removes from this date)
  Widget _plannedCard(Recipe recipe) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RecipeDetailsScreen(
              recipe: recipe,

              // In this screen we keep it simple and do not calculate matching
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

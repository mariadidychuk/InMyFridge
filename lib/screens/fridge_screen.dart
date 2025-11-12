import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'recipes_screen.dart';

/// Colors to match your Figma
const _bg = Color(0xFFFFF6F2);
const _accent = Color(0xFFD87C5A);
const _muted = Color(0xFF8C8C8C);

/// Hive box names
const _ingredientsBoxName = 'ingredientsBox';
const _uiBoxName = 'uiBox'; // stores small UI flags, e.g., 'assumptionDismissed'

class FridgeScreen extends StatefulWidget {
  const FridgeScreen({super.key});

  @override
  State<FridgeScreen> createState() => _FridgeScreenState();
}

class _FridgeScreenState extends State<FridgeScreen> {
  late final Box<String> _ingredientsBox;
  Box? _uiBox;

  final TextEditingController _search = TextEditingController();
  bool _assumptionDismissed = false;

  // Edit mode state
  bool _editMode = false;
  final Set<int> _selectedIndexes = <int>{};

  // NOTE: Placeholder dictionary for suggestions.
  // Later you can generate it from recipes data and cache in Hive.
  static const List<String> _ingredientDictionary = [
    'butter',
    'buttermilk',
    'peanut butter',
    'banana',
    'basil',
    'beef',
    'bread',
    'broccoli',
    'milk',
    'potato',
    'pepper',
    'salt',
    'water',
  ];

  @override
  void initState() {
    super.initState();
    _ingredientsBox = Hive.box<String>(_ingredientsBoxName);
    _openUiBox();
  }

  Future<void> _openUiBox() async {
    _uiBox = await Hive.openBox(_uiBoxName);
    setState(() {
      _assumptionDismissed = _uiBox?.get('assumptionDismissed', defaultValue: false) == true;
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  // ---------- Suggestions logic ----------

  /// Returns filtered, alphabetically sorted suggestions.
  /// Rule:
  ///  - If input "q" is non-empty, show items that start with q
  ///    OR contain q (case-insensitive).
  List<String> _filteredSuggestions(String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) return const <String>[];

    final starts = <String>[];
    final contains = <String>[];

    for (final item in _ingredientDictionary) {
      final lower = item.toLowerCase();
      if (lower.startsWith(query)) {
        starts.add(item);
      } else if (lower.contains(query)) {
        contains.add(item);
      }
    }

    starts.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    contains.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return [...starts, ...contains];
  }

  bool _alreadyAdded(String name) {
    // case-insensitive contains check
    final lower = name.toLowerCase();
    for (var i = 0; i < _ingredientsBox.length; i++) {
      final v = _ingredientsBox.getAt(i) ?? '';
      if (v.toLowerCase() == lower) return true;
    }
    return false;
  }

  void _addIngredient(String name) {
    if (name.trim().isEmpty) return;
    if (_alreadyAdded(name)) return; // duplicates not allowed
    _ingredientsBox.add(name.trim());
    _search.clear();
    setState(() {}); // rebuild to refresh suggestions
  }

  void _removeIngredientByName(String name) {
    final lower = name.toLowerCase();
    for (var i = 0; i < _ingredientsBox.length; i++) {
      final v = _ingredientsBox.getAt(i) ?? '';
      if (v.toLowerCase() == lower) {
        _ingredientsBox.deleteAt(i);
        break;
      }
    }
    setState(() {});
  }

  // ---------- Edit mode operations ----------
  void _toggleEditMode() {
    setState(() {
      _editMode = !_editMode;
      _selectedIndexes.clear();
    });
  }

  void _toggleSelect(int index) {
    setState(() {
      if (_selectedIndexes.contains(index)) {
        _selectedIndexes.remove(index);
      } else {
        _selectedIndexes.add(index);
      }
    });
  }

  void _deleteSelected() {
    // Delete from the end to keep indexes valid
    final toDelete = _selectedIndexes.toList()..sort((a, b) => b.compareTo(a));
    for (final i in toDelete) {
      _ingredientsBox.deleteAt(i);
    }
    setState(() {
      _selectedIndexes.clear();
      _editMode = false;
    });
  }

  void _deleteAll() {
    _ingredientsBox.clear();
    setState(() {
      _selectedIndexes.clear();
      _editMode = false;
    });
  }

  // ---------- UI helpers ----------

  /// Returns an alphabetically sorted list of current ingredients.
  List<MapEntry<int, String>> _sortedEntries(Box<String> box) {
    final entries = <MapEntry<int, String>>[];
    for (var i = 0; i < box.length; i++) {
      entries.add(MapEntry(i, box.getAt(i) ?? ''));
    }
    entries.sort((a, b) => a.value.toLowerCase().compareTo(b.value.toLowerCase()));
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        title: const Text('Fridge'),
        backgroundColor: _bg,
        elevation: 0,
        actions: [
          // Edit / Delete actions reside inside the Available Ingredients card
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // ---------- Search + suggestions ----------
            _SearchField(
              controller: _search,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            _SuggestionList(
              suggestions: _filteredSuggestions(_search.text),
              alreadyAdded: _alreadyAdded,
              onTapRow: _addIngredient, // add when tapping row
              onTapPlus: _addIngredient, // add when tapping leading "+"
              onTapTrash: _removeIngredientByName, // remove when already exists
            ),
            const SizedBox(height: 12),

            // ---------- Assumption chip ----------
            if (!_assumptionDismissed)
              _AssumptionChip(
                onClose: () {
                  _uiBox?.put('assumptionDismissed', true);
                  setState(() => _assumptionDismissed = true);
                },
              ),

            const SizedBox(height: 12),

            // ---------- Available ingredients block ----------
            Expanded(
              child: ValueListenableBuilder(
                valueListenable: _ingredientsBox.listenable(),
                builder: (context, Box<String> box, _) {
                  final entries = _sortedEntries(box);
                  return _AvailableIngredientsCard(
                    entries: entries,
                    editMode: _editMode,
                    selected: _selectedIndexes,
                    onToggleSelect: _toggleSelect,
                    onToggleEditMode: _toggleEditMode,
                    onDeleteSelected: _deleteSelected,
                    onDeleteAll: _deleteAll,
                  );
                },
              ),
            ),

            // ---------- See Recipes ----------
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    // Navigate to Recipes; Recipes will read from ingredientsBox
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const RecipesScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    shape: const StadiumBorder(),
                  ),
                  child: const Text(
                    'See Recipes',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ====================== WIDGETS ======================

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Search',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _SuggestionList extends StatelessWidget {
  const _SuggestionList({
    required this.suggestions,
    required this.alreadyAdded,
    required this.onTapRow,
    required this.onTapPlus,
    required this.onTapTrash,
  });

  final List<String> suggestions;
  final bool Function(String) alreadyAdded;
  final void Function(String) onTapRow;
  final void Function(String) onTapPlus;
  final void Function(String) onTapTrash;

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: suggestions.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, i) {
          final name = suggestions[i];
          final exists = alreadyAdded(name);
          return ListTile(
            dense: true,
            onTap: () => exists ? onTapTrash(name) : onTapRow(name), // add by tapping row; delete if exists
            leading: IconButton(
              icon: Icon(exists ? Icons.delete_outline : Icons.add),
              color: exists ? Colors.redAccent : _accent,
              onPressed: () => exists ? onTapTrash(name) : onTapPlus(name),
              tooltip: exists ? 'Remove' : 'Add',
            ),
            title: Text(name),
          );
        },
      ),
    );
  }
}

class _AssumptionChip extends StatelessWidget {
  const _AssumptionChip({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'We assume that you have salt, pepper and water',
              style: TextStyle(fontSize: 14),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: onClose,
            tooltip: 'Dismiss',
          ),
        ],
      ),
    );
  }
}

class _AvailableIngredientsCard extends StatelessWidget {
  const _AvailableIngredientsCard({
    required this.entries,
    required this.editMode,
    required this.selected,
    required this.onToggleSelect,
    required this.onToggleEditMode,
    required this.onDeleteSelected,
    required this.onDeleteAll,
  });

  final List<MapEntry<int, String>> entries;
  final bool editMode;
  final Set<int> selected;
  final void Function(int index) onToggleSelect;
  final VoidCallback onToggleEditMode;
  final VoidCallback onDeleteSelected;
  final VoidCallback onDeleteAll;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Column(
        children: [
          // Header row: title + actions
          Row(
            children: [
              const Expanded(
                child: Text('Available Ingredients',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              if (!editMode)
                IconButton(
                  tooltip: 'Edit',
                  icon: const Icon(Icons.edit),
                  onPressed: onToggleEditMode,
                )
              else
                TextButton(
                  onPressed: selected.isEmpty ? onDeleteAll : onDeleteSelected,
                  child: Text(selected.isEmpty ? 'Delete all' : 'Delete'),
                ),
            ],
          ),
          const SizedBox(height: 6),

          // Items list
          Expanded(
            child: entries.isEmpty
                ? const Center(child: Text('No ingredients yet'))
                : ListView.builder(
                    itemCount: entries.length,
                    itemBuilder: (context, i) {
                      final idx = entries[i].key;
                      final name = entries[i].value;

                      if (!editMode) {
                        // Read-only row with bullet
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              const Text('•  '),
                              Expanded(child: Text(name)),
                            ],
                          ),
                        );
                      }

                      // Edit mode row with selectable circle
                      final isSel = selected.contains(idx);
                      return InkWell(
                        onTap: () => onToggleSelect(idx),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              // Circle checkbox style
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: _muted, width: 1.6),
                                  color: isSel ? _accent : Colors.white,
                                ),
                                child: isSel
                                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                                    : null,
                              ),
                              const SizedBox(width: 10),
                              Expanded(child: Text(name)),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}


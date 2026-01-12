import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'recipes_screen.dart';

// Basic palette used in the app UI
const _bg = Color(0xFFFFF6F2);
const _accent = Color(0xFFD87C5A);
const _muted = Color(0xFF8C8C8C);

// Hive box names used on this screen
const _ingredientsBoxName = 'ingredientsBox';
const _uiBoxName = 'uiBox';       // small UI flags (e.g., dismissed hints)
const _recipesBoxName = 'recipesBox'; // source for suggestion list

// Fridge screen: manages user ingredients and writes them to Hive.
class FridgeScreen extends StatefulWidget {
  const FridgeScreen({super.key});

  @override
  State<FridgeScreen> createState() => _FridgeScreenState();
}

class _FridgeScreenState extends State<FridgeScreen> {
  late final Box<String> _ingredientsBox;
  late final Box<String> _recipesBox;
  Box? _uiBox;

  // Search field controller
  final TextEditingController _search = TextEditingController();

  // UI state for the dismissible hint card
  bool _assumptionDismissed = false;

  // Edit mode: multi-select and delete
  bool _editMode = false;
  final Set<int> _selectedIndexes = <int>{};

  // Ingredient suggestions built from recipe data (recipesBox)
  List<String> _ingredientDictionary = const [];

  @override
  void initState() {
    super.initState();
    _ingredientsBox = Hive.box<String>(_ingredientsBoxName);
    _recipesBox = Hive.box<String>(_recipesBoxName);

    _openUiBox();

    // Initial build of suggestions
    _rebuildIngredientDictionary();

    // Update suggestions when recipes change
    _recipesBox.listenable().addListener(_onRecipesBoxChanged);
  }

  @override
  void dispose() {
    _recipesBox.listenable().removeListener(_onRecipesBoxChanged);
    _search.dispose();
    super.dispose();
  }

  Future<void> _openUiBox() async {
    _uiBox = await Hive.openBox(_uiBoxName);
    if (!mounted) return;
    setState(() {
      _assumptionDismissed =
          _uiBox?.get('assumptionDismissed', defaultValue: false) == true;
    });
  }

  void _onRecipesBoxChanged() {
    _rebuildIngredientDictionary();
  }

  String _normalize(String s) => s.trim().toLowerCase();

  void _rebuildIngredientDictionary() {
    final set = <String>{};

    for (final raw in _recipesBox.values) {
      if (raw.trim().isEmpty) continue;

      final map = jsonDecode(raw) as Map<String, dynamic>;
      final ingredients = (map['ingredients'] as List?) ?? const [];

      for (final ing in ingredients) {
        if (ing is! Map) continue;
        final name = ing['name']?.toString() ?? '';
        final n = _normalize(name);
        if (n.isEmpty) continue;
        set.add(n);
      }
    }

    final list = set.toList()..sort();

    // Avoid setState if nothing changed (prevents unnecessary rebuilds)
    if (_ingredientDictionary.length == list.length) {
      var same = true;
      for (var i = 0; i < list.length; i++) {
        if (_ingredientDictionary[i] != list[i]) {
          same = false;
          break;
        }
      }
      if (same) return;
    }

    if (!mounted) return;
    setState(() => _ingredientDictionary = list);
  }

  // ---------------- Suggestions ----------------

  // Filters suggestions by:
  // - startsWith(query) first
  // - contains(query) second
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

  // Case-insensitive check to prevent duplicates
  bool _alreadyAdded(String name) {
    final lower = name.toLowerCase();
    for (var i = 0; i < _ingredientsBox.length; i++) {
      final v = _ingredientsBox.getAt(i) ?? '';
      if (v.toLowerCase() == lower) return true;
    }
    return false;
  }

  void _addIngredient(String name) {
    if (name.trim().isEmpty) return;
    if (_alreadyAdded(name)) return;
    _ingredientsBox.add(name.trim());
    _search.clear();
    setState(() {});
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

  // ---------------- Edit mode ----------------

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

  // Sort ingredients alphabetically for display
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
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _SearchField(
              controller: _search,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),

            // Suggestion list: height-limited + scrollable to avoid overflow
            _SuggestionList(
              suggestions: _filteredSuggestions(_search.text),
              alreadyAdded: _alreadyAdded,
              onTapRow: _addIngredient,
              onTapPlus: _addIngredient,
              onTapTrash: _removeIngredientByName,
            ),

            const SizedBox(height: 12),

            if (!_assumptionDismissed)
              _AssumptionChip(
                onClose: () {
                  _uiBox?.put('assumptionDismissed', true);
                  setState(() => _assumptionDismissed = true);
                },
              ),

            const SizedBox(height: 12),

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

            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const RecipesScreen(filterByFridge: true),
                      ),
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

// ---------------- UI widgets ----------------

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
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: SizedBox(
        height: 220,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 6),
          itemCount: suggestions.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final name = suggestions[i];
            final exists = alreadyAdded(name);

            return ListTile(
              dense: true,
              onTap: () => exists ? onTapTrash(name) : onTapRow(name),
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
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
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
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Available Ingredients',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
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
          Expanded(
            child: entries.isEmpty
                ? const Center(child: Text('No ingredients yet'))
                : ListView.builder(
                    itemCount: entries.length,
                    itemBuilder: (context, i) {
                      final idx = entries[i].key;
                      final name = entries[i].value;

                      if (!editMode) {
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

                      final isSel = selected.contains(idx);
                      return InkWell(
                        onTap: () => onToggleSelect(idx),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
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

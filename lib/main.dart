import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

const String kBoxName = 'ingredientsBox';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1) Init Hive before runApp
  await Hive.initFlutter();

  // 2) Open a box (key-value store). If it doesn't exist, Hive creates it.
  await Hive.openBox(kBoxName);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hive Smoke Test',
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal)),
      home: const HiveSmokeTestPage(),
    );
  }
}

class HiveSmokeTestPage extends StatefulWidget {
  const HiveSmokeTestPage({super.key});

  @override
  State<HiveSmokeTestPage> createState() => _HiveSmokeTestPageState();
}

class _HiveSmokeTestPageState extends State<HiveSmokeTestPage> {
  late final Box _box;
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _box = Hive.box(kBoxName);
  }

  // Writes a simple string under incremental keys: item_0, item_1, ...
  Future<void> _addItem() async {
    // key = 'item_{length}' to keep it simple for the smoke test
    final key = 'item_${_box.length}';
    final value = _controller.text.trim().isEmpty ? 'Tomato' : _controller.text.trim();
    await _box.put(key, value);
    setState(() {}); // refresh UI
  }

  Future<void> _clearAll() async {
    await _box.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final keys = _box.keys.toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Hive Smoke Test')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Input field
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Ingredient name',
                hintText: 'e.g., Tomato',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _addItem(),
            ),
            const SizedBox(height: 12),

            // Buttons
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _addItem,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _clearAll,
                  icon: const Icon(Icons.delete_forever),
                  label: const Text('Clear all'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // List of saved items
            Expanded(
              child: keys.isEmpty
                  ? const Center(child: Text('No items yet — add something!'))
                  : ListView.separated(
                      itemCount: keys.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final key = keys[index];
                        final value = _box.get(key);
                        return ListTile(
                          title: Text('$value'),
                          subtitle: Text('key: $key'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              await _box.delete(key);
                              setState(() {});
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
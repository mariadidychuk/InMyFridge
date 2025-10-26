import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

Future<void> main() async {
  // --- 1. Ensure Flutter bindings are initialized ---
  WidgetsFlutterBinding.ensureInitialized();

  // --- 2. Initialize Hive before runApp() ---
  await Hive.initFlutter();

  // --- 3. Open Hive box for ingredients ---
  await Hive.openBox('ingredientsBox'); // This box will store ingredients data

  // --- 4. Run the main app ---
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'InMyFridge',
      theme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: const HiveTestPage(),
    );
  }
}

class HiveTestPage extends StatelessWidget {
  const HiveTestPage({super.key});

  @override
  Widget build(BuildContext context) {
    final box = Hive.box('ingredientsBox');

    return Scaffold(
      appBar: AppBar(title: const Text('Hive Initialization Test')),
      body: Center(
        child: ValueListenableBuilder(
          valueListenable: box.listenable(),
          builder: (context, Box b, _) {
            final ingredients = b.values.toList();
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Ingredients stored in Hive:', style: TextStyle(fontSize: 18)),
                const SizedBox(height: 16),
                if (ingredients.isEmpty)
                  const Text('No ingredients yet', style: TextStyle(color: Colors.grey))
                else
                  for (var i in ingredients)
                    Text(i.toString(), style: const TextStyle(fontSize: 16)),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // --- Example write operation (for testing) ---
          final time = DateTime.now().toIso8601String();
          box.put(time, 'Ingredient added at $time');
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/database.dart';
import 'data/repository.dart';
import 'features/home_shell.dart';
import 'features/shop_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final db = await AppDatabase.open();
    runApp(
      ChangeNotifierProvider(
        create: (_) => ShopController(ShopRepository(db))..refresh(),
        child: const ShopApp(),
      ),
    );
  } catch (e) {
    runApp(const DbErrorApp());
  }
}

class DbErrorApp extends StatelessWidget {
  const DbErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Could not open the local database. '
              'Check storage space and restart the app.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class ShopApp extends StatelessWidget {
  const ShopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Shop Stock',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blueGrey,
      ),
      home: const HomeShell(),
    );
  }
}

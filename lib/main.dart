import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:pocket_app/providers/auth_provider.dart';
import 'package:pocket_app/providers/transaction_provider.dart';
import 'package:pocket_app/providers/budget_provider.dart';
import 'package:pocket_app/providers/theme_provider.dart';
import 'package:pocket_app/screens/login_screen.dart';
import 'package:pocket_app/screens/main_navigation.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // Enable offline-first: data saves to local cache immediately,
  // then syncs to cloud when connected to internet.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  runApp(const PocketApp());
}

class PocketApp extends StatelessWidget {
  const PocketApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, TransactionProvider>(
          create: (_) => TransactionProvider(),
          update: (_, auth, tx) {
            tx ??= TransactionProvider();
            tx.resetForUser(auth.userId);
            return tx;
          },
        ),
        ChangeNotifierProxyProvider<AuthProvider, BudgetProvider>(
          create: (_) => BudgetProvider(),
          update: (_, auth, budget) {
            budget ??= BudgetProvider();
            budget.resetForUser(auth.userId);
            return budget;
          },
        ),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Pocket App',
            themeMode:
            themeProvider.isDarkMode ? ThemeMode.dark : ThemeMode.light,

            //  Light Theme
            theme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.light,
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blue,
                brightness: Brightness.light,
              ),
              bottomNavigationBarTheme: const BottomNavigationBarThemeData(
                backgroundColor: Colors.white,
                selectedItemColor: Colors.blue,
                unselectedItemColor: Colors.grey,
              ),
            ),

            //  Dark Theme
            darkTheme: ThemeData(
              useMaterial3: true,
              brightness: Brightness.dark,
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blue,
                brightness: Brightness.dark,
              ),
              bottomNavigationBarTheme: const BottomNavigationBarThemeData(
                backgroundColor: Color(0xFF121212),
                selectedItemColor: Colors.lightBlueAccent,
                unselectedItemColor: Colors.grey,
              ),
            ),

            home: Consumer<AuthProvider>(
              builder: (context, authProvider, child) {
                return authProvider.isLoggedIn
                    ? const MainNavigation()
                    : const LoginScreen();
              },
            ),
            debugShowCheckedModeBanner: false,
          );
        },
      ),
    );
  }
}

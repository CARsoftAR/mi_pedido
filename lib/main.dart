import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pizzeria/configuracion_page.dart';
import 'package:pizzeria/product_list_screen.dart';
import 'package:pizzeria/orders_screen.dart';
import 'package:pizzeria/login_screen.dart';
import 'package:pizzeria/client_carta_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase Error: $e");
  }
  
  final prefs = await SharedPreferences.getInstance();
  final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
  
  runApp(MiPedidoApp(isLoggedIn: isLoggedIn));
}

class MiPedidoApp extends StatelessWidget {
  final bool isLoggedIn;
  const MiPedidoApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pizzería Miguel Angel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.montserratTextTheme(),
        scaffoldBackgroundColor: const Color(0xFFF9F9F9),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF7F50)),
      ),
      home: isLoggedIn ? const ClientCartaScreen() : const LoginScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/carta': (context) => const ClientCartaScreen(),
      },
    );
  }
}

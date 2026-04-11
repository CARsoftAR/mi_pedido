import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'splash_screen.dart'; // IMPORT DEL SPLASH
import 'login_screen.dart';
import 'client_carta_screen.dart';
import 'profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase Error: $e");
  }
  
  runApp(const ClientApp());
}

class ClientApp extends StatelessWidget {
  const ClientApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pizzería Miguel Angel',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.montserratTextTheme(),
        scaffoldBackgroundColor: const Color(0xFF1A1A1A), // Fondo oscuro para que combine con el splash
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF7F50),
          brightness: Brightness.dark,
        ),
      ),
      home: const SplashScreen(), // EL PUNTO DE ENTRADA AHORA ES EL SPLASH
      routes: {
        '/login': (context) => const LoginScreen(),
        '/carta': (context) => const ClientCartaScreen(),
        '/perfil': (context) => const ProfileScreen(),
      },
    );
  }
}

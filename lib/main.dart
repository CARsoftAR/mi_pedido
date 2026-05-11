import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Imports de Cliente
import 'package:pizzeria/splash_screen.dart';
import 'package:pizzeria/login_screen.dart';
import 'package:pizzeria/client_carta_screen.dart';
import 'package:pizzeria/profile_screen.dart';

// Imports de Admin
import 'package:pizzeria/configuracion_page.dart';
import 'package:pizzeria/product_list_screen.dart';
import 'package:pizzeria/orders_screen.dart';

final localNotifications = FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicialización de notificaciones
  const initializationSettings = InitializationSettings(
    android: AndroidInitializationSettings('@mipmap/ic_launcher'),
  );
  await localNotifications.initialize(initializationSettings);

  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint("Firebase Error: $e");
  }

  // Detectamos el flavor desde el entorno de compilación
  if (appFlavor == 'admin') {
    runApp(const AdminApp());
  } else {
    runApp(const ClientApp());
  }
}

// ----------------------------------------------------
// APP DEL CLIENTE
// ----------------------------------------------------
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
        scaffoldBackgroundColor: const Color(0xFF1A1A1A),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF7F50),
          brightness: Brightness.dark,
        ),
      ),
      home: const SplashScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/carta': (context) => const ClientCartaScreen(),
        '/perfil': (context) => const ProfileScreen(),
      },
    );
  }
}

// ----------------------------------------------------
// APP DEL ADMINISTRADOR (NEGOCIO)
// ----------------------------------------------------
class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Admin Gonzalo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.montserratTextTheme(),
        scaffoldBackgroundColor: const Color(0xFFF4F6F9),
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF6B35)), // Naranja Vibrante
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          foregroundColor: Colors.black87,
        ),
      ),
      home: const AdminMainWrapper(),
    );
  }
}

class AdminMainWrapper extends StatefulWidget {
  const AdminMainWrapper({super.key});

  @override
  State<AdminMainWrapper> createState() => _AdminMainWrapperState();
}

class _AdminMainWrapperState extends State<AdminMainWrapper> {
  int _index = 0;
  final _pages = [
    const OrdersScreen(),
    const ProductListScreen(),
    const ConfiguracionPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        onTap: (i) => setState(() => _index = i),
        selectedItemColor: const Color(0xFFFF7F50),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.list_alt_rounded), label: 'Pedidos'),
          BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu), label: 'Carta'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Ajustes'),
        ],
      ),
    );
  }
}

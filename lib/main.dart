import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pizzeria/configuracion_page.dart';
import 'package:pizzeria/product_list_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp();
    debugPrint("Firebase inicializado correctamente");
  } catch (e) {
    debugPrint("ERROR al inicializar Firebase: $e");
  }
  
  runApp(const MiPedidoApp());
}

class MiPedidoApp extends StatelessWidget {
  const MiPedidoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mi Pedido - Pizzería Gonzalo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.montserratTextTheme(), // Montserrat como pidió el usuario
        scaffoldBackgroundColor: const Color(0xFFF9F9F9),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFF7F50), // Rojo Coral Premium
          primary: const Color(0xFFFF7F50),
        ),
      ),
      home: const MainWrapper(),
    );
  }
}

class MainWrapper extends StatefulWidget {
  const MainWrapper({super.key});

  @override
  State<MainWrapper> createState() => _MainWrapperState();
}

class _MainWrapperState extends State<MainWrapper> {
  int _index = 0;
  final _pages = [
    const ProductListScreen(),
    const ConfiguracionPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, -5)),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _index,
          onTap: (i) => setState(() => _index = i),
          selectedItemColor: const Color(0xFFFF7F50), // Rojo Coral
          unselectedItemColor: Colors.grey[400],
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedLabelStyle: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 13),
          unselectedLabelStyle: GoogleFonts.montserrat(fontWeight: FontWeight.w500, fontSize: 12),
          items: const [
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.restaurant_menu_rounded),
              ), 
              label: 'Mi Carta'
            ),
            BottomNavigationBarItem(
              icon: Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Icon(Icons.settings_suggest_rounded),
              ), 
              label: 'Ajustes'
            ),
          ],
        ),
      ),
    );
  }
}

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import 'client_carta_screen.dart';
import 'order_status_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _controller.forward();

    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    // Esperamos 4 segundos exactos
    await Future.delayed(const Duration(milliseconds: 4000));
    
    final prefs = await SharedPreferences.getInstance();
    final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    if (!isLoggedIn) {
       if (mounted) {
         Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const LoginScreen()));
       }
       return;
    }

    // SI ESTÁ LOGUEADO, CHEQUEAMOS SI TIENE PEDIDO ACTIVO
    final String? lastOrderId = prefs.getString('lastOrderId');
    if (lastOrderId != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('pedidos').doc(lastOrderId).get();
        if (doc.exists) {
          final String estado = doc.data()?['estado'] ?? '';
          // ESTADOS ACTIVOS: Pendiente, modificando, En Preparación, Despachado
          if (estado == 'Pendiente' || estado == 'modificando' || estado == 'En Preparación' || estado == 'Despachado') {
             if (mounted) {
               Navigator.of(context).pushReplacement(
                 MaterialPageRoute(builder: (context) => OrderStatusScreen(orderId: lastOrderId))
               );
               return;
             }
          }
        }
      } catch (e) {
        debugPrint("Error checking active order on splash: $e");
      }
    }

    // SI NO TIENE PEDIDO O YA TERMINÓ, VA A LA CARTA
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const ClientCartaScreen()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121417), // El gris profundo de tu logo
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.2),
            radius: 1.2,
            colors: [
              Color(0xFF1E2024),
              Color(0xFF121417),
            ],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _animation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ShaderMask(
                  shaderCallback: (rect) {
                    return const RadialGradient(
                      center: Alignment.center,
                      radius: 0.5,
                      colors: [Colors.black, Colors.transparent],
                      stops: [0.75, 1.0],
                    ).createShader(rect);
                  },
                  blendMode: BlendMode.dstIn,
                  child: Image.asset(
                    'assets/logo_cliente.png',
                    width: MediaQuery.of(context).size.width * 0.85,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 50),
                const CircularProgressIndicator(
                  color: Color(0xFFFF7F50),
                  strokeWidth: 2.5,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'client_carta_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _detailsController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passController = TextEditingController();
  
  bool _isLoading = false;
  bool _isRegistering = true;

  Future<void> _handleAuth() async {
    if (_nameController.text.isEmpty || _addressController.text.isEmpty || _phoneController.text.isEmpty || _passController.text.isEmpty) {
      _showError("Por favor completa todos los campos obligatorios.");
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (_isRegistering) {
        // Registro
        final userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(_phoneController.text.trim()).get();
        if (userDoc.exists) {
          _showError("Este número de celular ya está registrado.");
          setState(() => _isLoading = false);
          return;
        }

        await FirebaseFirestore.instance.collection('usuarios').doc(_phoneController.text.trim()).set({
          'nombre': _nameController.text.trim(),
          'direccion': _addressController.text.trim(),
          'detalles_direccion': _detailsController.text.trim(),
          'celular': _phoneController.text.trim(),
          'password': _passController.text.trim(), // En una app real usaríamos Firebase Auth, pero seguimos el flujo pedido
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Login Simple
        final userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(_phoneController.text.trim()).get();
        if (!userDoc.exists || userDoc.data()?['password'] != _passController.text.trim()) {
          _showError("Celular o contraseña incorrectos.");
          setState(() => _isLoading = false);
          return;
        }
      }

      // Persistencia
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userPhone', _phoneController.text.trim());
      await prefs.setString('userName', _nameController.text.trim());

      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const ClientCartaScreen()));
      }
    } catch (e) {
      _showError("Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF5F2), Colors.white],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30),
            child: Column(
              children: [
                const SizedBox(height: 40),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: const Color(0xFFFF7F50).withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))],
                  ),
                  child: const Icon(Icons.local_pizza_rounded, size: 60, color: Color(0xFFFF7F50)),
                ),
                const SizedBox(height: 25),
                GestureDetector(
                  onLongPress: () => Navigator.pushNamed(context, '/admin'),
                  child: Text("Pizzería Gonzalo", style: GoogleFonts.montserrat(fontSize: 28, fontWeight: FontWeight.w900, color: const Color(0xFF2D2D2D))),
                ),
                Text(_isRegistering ? "Creá tu cuenta para pedir" : "¡Qué bueno verte de nuevo!", style: GoogleFonts.montserrat(fontSize: 14, color: Colors.grey[600])),
                const SizedBox(height: 40),
                
                if (_isRegistering) ...[
                  _buildInput("Nombre Completo", _nameController, Icons.person_outline),
                  _buildInput("Dirección de Entrega", _addressController, Icons.location_on_outlined),
                  _buildInput("Departamento / Casa / Detalles", _detailsController, Icons.maps_home_work_outlined),
                ],
                _buildInput("Celular (Usuario)", _phoneController, Icons.phone_android_outlined, isPhone: true),
                _buildInput("Contraseña", _passController, Icons.lock_outline, isPass: true),
                
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleAuth,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7F50),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 5,
                    shadowColor: const Color(0xFFFF7F50).withOpacity(0.4),
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : Text(_isRegistering ? "REGISTRARME" : "INGRESAR", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                const SizedBox(height: 15),
                TextButton(
                  onPressed: () => setState(() => _isRegistering = !_isRegistering),
                  child: Text(_isRegistering ? "¿Ya tenés cuenta? Ingresá acá" : "¿Sos nuevo? Creá tu cuenta", style: GoogleFonts.montserrat(color: const Color(0xFFFF7F50), fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInput(String label, TextEditingController controller, IconData icon, {bool isPass = false, bool isPhone = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: TextField(
        controller: controller,
        obscureText: isPass,
        keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
        style: GoogleFonts.montserrat(fontSize: 14),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFFFF7F50).withOpacity(0.7), size: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }
}

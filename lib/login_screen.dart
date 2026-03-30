import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      String userPhone = _phoneController.text.trim();
      String userName = _nameController.text.trim();
      String userAddress = _addressController.text.trim();

      if (_isRegistering) {
        // Registro
        final userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(userPhone).get();
        if (userDoc.exists) {
          _showError("Este número ya tiene una cuenta. Por favor, iniciá sesión.");
          setState(() => _isLoading = false);
          return;
        }

        await FirebaseFirestore.instance.collection('usuarios').doc(userPhone).set({
          'nombre': userName,
          'direccion': userAddress,
          'detalles_direccion': _detailsController.text.trim(),
          'celular': userPhone,
          'password': _passController.text.trim(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Login Simple
        final userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(userPhone).get();
        if (!userDoc.exists || userDoc.data()?['password'] != _passController.text.trim()) {
          _showError("Celular o contraseña incorrectos.");
          setState(() => _isLoading = false);
          return;
        }
        // Recuperar datos para persistencia
        userName = userDoc.data()?['nombre'] ?? '';
        userAddress = userDoc.data()?['direccion'] ?? '';
      }

      // Persistencia Real
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      await prefs.setString('userPhone', userPhone);
      await prefs.setString('userName', userName);
      await prefs.setString('userAddress', userAddress);

      if (mounted) {
        Navigator.pushReplacementNamed(context, '/carta');
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
                const SizedBox(height: 35),
                
                // Selector Dual
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isRegistering = false),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: !_isRegistering ? const Color(0xFFFF7F50) : Colors.transparent,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Center(child: Text("INGRESAR", style: GoogleFonts.montserrat(color: !_isRegistering ? Colors.white : Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 12))),
                          ),
                        ),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _isRegistering = true),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: _isRegistering ? const Color(0xFFFF7F50) : Colors.transparent,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Center(child: Text("REGISTRARME", style: GoogleFonts.montserrat(color: _isRegistering ? Colors.white : Colors.grey[600], fontWeight: FontWeight.bold, fontSize: 12))),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                
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
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/admin'),
                  child: Text("Acceso Administrativo", style: GoogleFonts.montserrat(color: Colors.grey, fontSize: 11)),
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

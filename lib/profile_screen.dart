import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _detailsController = TextEditingController();
  String? _userPhone;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    _userPhone = prefs.getString('userPhone');
    
    if (_userPhone != null) {
      final doc = await FirebaseFirestore.instance.collection('usuarios').doc(_userPhone).get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _nameController.text = data['nombre'] ?? '';
          _addressController.text = data['direccion'] ?? '';
          _detailsController.text = data['detalles_direccion'] ?? '';
          _isLoading = false;
        });
        return;
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _saveChanges() async {
    if (_nameController.text.isEmpty || _addressController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Nombre y Dirección no pueden estar vacíos")),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final String newName = _nameController.text.trim();
      final String newAddress = _addressController.text.trim();
      final String newDetails = _detailsController.text.trim();

      await FirebaseFirestore.instance.collection('usuarios').doc(_userPhone).update({
        'nombre': newName,
        'direccion': newAddress,
        'detalles_direccion': newDetails,
      });

      // Actualizar SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userName', newName);
      await prefs.setString('userAddress', newAddress);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Perfil actualizado correctamente"), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al guardar: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Mi Perfil", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF7F50)))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF7F50).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person, size: 60, color: Color(0xFFFF7F50)),
                  ),
                ),
                const SizedBox(height: 30),
                Text("Celu/Usuario: $_userPhone", style: GoogleFonts.montserrat(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 20),
                _buildInput("Nombre", _nameController, Icons.person_outline),
                _buildInput("Dirección Habitual", _addressController, Icons.location_on_outlined),
                _buildInput("Detalles (Piso, Casa, etc)", _detailsController, Icons.home_work_outlined),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: _isSaving ? null : _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7F50),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 0,
                  ),
                  child: _isSaving 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text("GUARDAR CAMBIOS", style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, letterSpacing: 1.1)),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildInput(String label, TextEditingController controller, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: GoogleFonts.montserrat(fontSize: 14),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: const Color(0xFFFF7F50)),
            filled: true,
            fillColor: Colors.grey[50],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.all(15),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

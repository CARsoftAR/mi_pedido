import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class ConfiguracionPage extends StatefulWidget {
  const ConfiguracionPage({super.key});

  @override
  State<ConfiguracionPage> createState() => _ConfiguracionPageState();
}

class _ConfiguracionPageState extends State<ConfiguracionPage> {
  // Datos del Local
  final TextEditingController _nombreController = TextEditingController(text: 'Pizzería Gonzalo');
  final TextEditingController _direccionController = TextEditingController();

  // Central de Precios
  final TextEditingController _unidadComunController = TextEditingController();
  final TextEditingController _docenaComunController = TextEditingController();
  final TextEditingController _unidadEspecialController = TextEditingController();
  final TextEditingController _docenaEspecialController = TextEditingController();

  // Logística
  final TextEditingController _demoraController = TextEditingController();
  final TextEditingController _deliveryController = TextEditingController();

  bool _isSaving = false;

  void _guardarConfiguracion() async {
    setState(() => _isSaving = true);
    
    try {
      final Map<String, dynamic> data = {
        'nombre': _nombreController.text.trim(),
        'direccion': _direccionController.text.trim(),
        'unidad_comun': double.tryParse(_unidadComunController.text) ?? 0,
        'docena_comun': double.tryParse(_docenaComunController.text) ?? 0,
        'unidad_especial': double.tryParse(_unidadEspecialController.text) ?? 0,
        'docena_especial': double.tryParse(_docenaEspecialController.text) ?? 0,
        'tiempo_demora': int.tryParse(_demoraController.text) ?? 0,
        'precio_delivery': double.tryParse(_deliveryController.text) ?? 0,
        'updated_at': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('configuracion_local')
          .doc('precios')
          .set(data, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Configuración guardada exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          'Configuración Local',
          style: GoogleFonts.outfit(
            color: const Color(0xFFD32F2F),
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sección Datos del Local
            _buildSectionTitle('Datos del Local'),
            _buildCard([
              _buildTextField('Nombre del Negocio', _nombreController, Icons.store),
              _buildTextField('Dirección del Local', _direccionController, Icons.location_on),
            ]),

            const SizedBox(height: 25),

            // Sección Central de Precios
            _buildSectionTitle('Central de Precios de Empanadas'),
            _buildCard([
              Row(
                children: [
                  Expanded(child: _buildTextField('Unidad Común', _unidadComunController, Icons.attach_money, isNumeric: true)),
                  const SizedBox(width: 15),
                  Expanded(child: _buildTextField('Docena Común', _docenaComunController, Icons.shopping_basket, isNumeric: true)),
                ],
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(child: _buildTextField('Unidad Especial', _unidadEspecialController, Icons.star, isNumeric: true)),
                  const SizedBox(width: 15),
                  Expanded(child: _buildTextField('Docena Especial', _docenaEspecialController, Icons.star_border_outlined, isNumeric: true)),
                ],
              ),
            ]),

            const SizedBox(height: 25),

            // Sección Logística
            _buildSectionTitle('Logística de Entrega'),
            _buildCard([
              Row(
                children: [
                  Expanded(child: _buildTextField('Demora (min)', _demoraController, Icons.timer, isNumeric: true)),
                  const SizedBox(width: 15),
                  Expanded(child: _buildTextField('Delivery (\$)', _deliveryController, Icons.delivery_dining, isNumeric: true)),
                ],
              ),
            ]),

            const SizedBox(height: 40),

            // Botón Guardar
            ElevatedButton(
              onPressed: _isSaving ? null : _guardarConfiguracion,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 3,
              ),
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      'GUARDAR CONFIGURACIÓN',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15, left: 5),
      child: Text(
        title.toUpperCase(),
        style: GoogleFonts.outfit(
          color: const Color(0xFFD32F2F),
          fontWeight: FontWeight.bold,
          fontSize: 16,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 4),
            blurRadius: 15,
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {bool isNumeric = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.grey[600]),
          labelStyle: GoogleFonts.outfit(color: Colors.grey[700]),
          filled: true,
          fillColor: Colors.grey[50],
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey[200]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 1.5),
          ),
        ),
      ),
    );
  }
}

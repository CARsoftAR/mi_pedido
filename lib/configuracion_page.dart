import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class ConfiguracionPage extends StatefulWidget {
  const ConfiguracionPage({super.key});

  @override
  State<ConfiguracionPage> createState() => _ConfiguracionPageState();
}

class _ConfiguracionPageState extends State<ConfiguracionPage> {
  final TextEditingController _nombreController = TextEditingController(text: 'Pizzería Gonzalo');
  final TextEditingController _direccionController = TextEditingController();
  final TextEditingController _horarioController = TextEditingController();
  final TextEditingController _demoraController = TextEditingController();
  final TextEditingController _deliveryController = TextEditingController();
  
  final TextEditingController _unidadComunController = TextEditingController();
  final TextEditingController _docenaComunController = TextEditingController();
  final TextEditingController _unidadEspecialController = TextEditingController();
  final TextEditingController _docenaEspecialController = TextEditingController();

  bool _isSaving = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarConfiguracion();
  }

  String _formatPrice(dynamic value) {
    double val = 0;
    if (value is num) {
      val = value.toDouble();
    } else if (value is String) {
      val = double.tryParse(value.replaceAll(',', '.')) ?? 0;
    }
    return val.toStringAsFixed(2).replaceAll('.', ',');
  }

  double _parsePrice(String text) {
    return double.tryParse(text.trim().replaceAll(',', '.')) ?? 0;
  }

  void _cargarConfiguracion() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('configuracion_local').doc('precios').get();
      if (doc.exists) {
        final data = doc.data()!;
        setState(() {
          _nombreController.text = data['nombre'] ?? 'Pizzería Gonzalo';
          _direccionController.text = data['direccion'] ?? '';
          _horarioController.text = data['horario'] ?? '';
          _demoraController.text = data['tiempo_demora'] ?? '';
          _deliveryController.text = _formatPrice(data['precio_delivery']);
          
          _unidadComunController.text = _formatPrice(data['unidad_comun']);
          _docenaComunController.text = _formatPrice(data['docena_comun']);
          _unidadEspecialController.text = _formatPrice(data['unidad_especial']);
          _docenaEspecialController.text = _formatPrice(data['docena_especial']);
        });
      }
    } catch (e) {
      debugPrint("Error al cargar configuración: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _guardarConfiguracion() async {
    setState(() => _isSaving = true);
    try {
      final Map<String, dynamic> data = {
        'nombre': _nombreController.text.trim(),
        'direccion': _direccionController.text.trim(),
        'horario': _horarioController.text.trim(),
        'tiempo_demora': _demoraController.text.trim(),
        'precio_delivery': _parsePrice(_deliveryController.text),
        'unidad_comun': _parsePrice(_unidadComunController.text),
        'docena_comun': _parsePrice(_docenaComunController.text),
        'unidad_especial': _parsePrice(_unidadEspecialController.text),
        'docena_especial': _parsePrice(_docenaEspecialController.text),
        'updated_at': FieldValue.serverTimestamp(),
      };
      await FirebaseFirestore.instance.collection('configuracion_local').doc('precios').set(data, SetOptions(merge: true));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configuración guardada correctamente'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: Text("Ajustes del Negocio", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // DASHBOARD PREMIUM (Cierre de Caja)
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('pedidos').where('estado', isEqualTo: 'Finalizado').snapshots(),
              builder: (context, snapshot) {
                double totalHoy = 0;
                int countHoy = 0;
                if (snapshot.hasData) {
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  for (var doc in snapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final Timestamp? ts = data['updatedAt'];
                    if (ts != null) {
                      final date = ts.toDate();
                      if (date.isAfter(today)) {
                        totalHoy += (data['total'] ?? 0).toDouble();
                        countHoy++;
                      }
                    }
                  }
                }
                return _buildDashboard(totalHoy, countHoy);
              },
            ),
            const SizedBox(height: 25),
            
            _buildSectionTitle("Datos del Local"),
            _buildCard([
              _buildTextField("Nombre", _nombreController, Icons.store),
              _buildTextField("Dirección", _direccionController, Icons.map),
              _buildTextField("Horario de Atención", _horarioController, Icons.access_time),
              Row(
                children: [
                  Expanded(child: _buildTextField("Demora (ej: 40-50 min)", _demoraController, Icons.timer)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildTextField("Delivery \$", _deliveryController, Icons.delivery_dining, isNumeric: true)),
                ],
              ),
            ]),
            
            const SizedBox(height: 25),
            
            _buildSectionTitle("Precios Empanadas Comunes"),
            _buildCard([
              Row(
                children: [
                  Expanded(child: _buildTextField("Unidad \$", _unidadComunController, Icons.attach_money, isNumeric: true)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildTextField("Docena \$", _docenaComunController, Icons.shopping_basket, isNumeric: true)),
                ],
              ),
            ]),

            const SizedBox(height: 25),
            
            _buildSectionTitle("Precios Empanadas Especiales"),
            _buildCard([
              Row(
                children: [
                  Expanded(child: _buildTextField("Unidad \$", _unidadEspecialController, Icons.star_outline, isNumeric: true)),
                  const SizedBox(width: 10),
                  Expanded(child: _buildTextField("Docena \$", _docenaEspecialController, Icons.grade, isNumeric: true)),
                ],
              ),
            ]),
            
            const SizedBox(height: 30),
            
            ElevatedButton(
              onPressed: _isSaving ? null : _guardarConfiguracion,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF7F50),
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 4,
                shadowColor: const Color(0xFFFF7F50).withOpacity(0.4),
              ),
              child: _isSaving 
                ? const SizedBox(width: 25, height: 25, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                : const Text("GUARDAR CAMBIOS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard(double total, int count) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF7F50), Color(0xFFFF4500)],
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        children: [
          Text("VENTAS DE HOY", style: GoogleFonts.montserrat(color: Colors.white.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Text("\$ ${total.toStringAsFixed(2)}", style: GoogleFonts.montserrat(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900)),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 15),
            child: Divider(color: Colors.white24, height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle_outline, color: Colors.white70, size: 18),
              const SizedBox(width: 10),
              Text("Pedidos entregados: $count", style: GoogleFonts.montserrat(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12, left: 5),
        child: Text(
          title.toUpperCase(),
          style: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.grey[700],
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 4),
          )
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
        keyboardType: isNumeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
        style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
          prefixIcon: Icon(icon, size: 20, color: const Color(0xFFFF7F50)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.grey[50],
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}


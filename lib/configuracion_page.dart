import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

class ConfiguracionPage extends StatefulWidget {
  const ConfiguracionPage({super.key});

  @override
  State<ConfiguracionPage> createState() => _ConfiguracionPageState();
}

class _ConfiguracionPageState extends State<ConfiguracionPage> {
  final TextEditingController _nombreController = TextEditingController(text: 'Pizzería Miguel Angel');
  final TextEditingController _sloganController = TextEditingController(text: '¡Pizzería Gourmet!');
  final TextEditingController _direccionController = TextEditingController();
  final TextEditingController _horarioController = TextEditingController();
  final TextEditingController _demoraController = TextEditingController();
  final TextEditingController _deliveryController = TextEditingController(); // Alias para Villa
  final TextEditingController _envioBarrioController = TextEditingController();
  final TextEditingController _envioRetiroController = TextEditingController();
  
  final TextEditingController _unidadComunController = TextEditingController();
  final TextEditingController _docenaComunController = TextEditingController();
  final TextEditingController _unidadEspecialController = TextEditingController();
  final TextEditingController _docenaEspecialController = TextEditingController();
  
  final TextEditingController _aliasController = TextEditingController();
  final TextEditingController _cbuController = TextEditingController();
  final TextEditingController _whatsappController = TextEditingController();
  final TextEditingController _minutosEdicionController = TextEditingController(text: '5');

  // Controlador Mercado Pago
  bool _activarMp = false;

  TimeOfDay _horaApertura = const TimeOfDay(hour: 20, minute: 0);
  TimeOfDay _horaCierre = const TimeOfDay(hour: 4, minute: 0);

  int _estadoControl = 1; // 0=Cerrado, 1=Auto, 2=Abierto
  bool _isSaving = false;
  bool _isLoading = true;
  bool _isClosing = false;
  bool _mostrarEmpanadasMaster = false;
  
  // VARIABLES DE ALARMA
  bool _alarmaEnabled = true;
  String _alarmaTono = 'Corto'; // Sirena, Campana, Corto
  String? _alarmaUri; // URI del tono elegido
  double _alarmaVolumen = 100.0;
  bool _alarmaLoop = false;
  List<dynamic> _systemRingtones = [];
  
  static const _channel = MethodChannel('com.mipedido.pizzeria/sounds');

  @override
  void initState() {
    super.initState();
    _cargarConfiguracion();
    _fetchRingtones();
  }

  void _fetchRingtones() async {
    try {
      final List<dynamic> res = await _channel.invokeMethod('getRingtones');
      setState(() => _systemRingtones = res);
    } catch (e) {
      debugPrint("Error fetching ringtones: $e");
    }
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
      final localDoc = await FirebaseFirestore.instance.collection('config').doc('datos_local').get();
      final mpDoc = await FirebaseFirestore.instance.collection('config').doc('mercado_pago').get();

      if (localDoc.exists) {
        final data = localDoc.data()!;
        final mpData = mpDoc.data() ?? {};
        setState(() {
          _nombreController.text = data['nombre'] ?? 'Pizzería Miguel Angel';
          _sloganController.text = data['slogan'] ?? '¡Pizzería Gourmet!';
          _direccionController.text = data['direccion'] ?? '';
          _horarioController.text = data['horario'] ?? '';
          _demoraController.text = data['tiempo_demora'] ?? '';
          _deliveryController.text = _formatPrice(data['precio_delivery'] ?? 0);
          _envioBarrioController.text = _formatPrice(data['v_envio_barrio'] ?? 0);
          _envioRetiroController.text = _formatPrice(data['v_envio_retiro'] ?? 0);
          _unidadComunController.text = _formatPrice(data['unidad_comun'] ?? 0);
          _docenaComunController.text = _formatPrice(data['docena_comun'] ?? 0);
          _unidadEspecialController.text = _formatPrice(data['unidad_especial'] ?? 0);
          _docenaEspecialController.text = _formatPrice(data['docena_especial'] ?? 0);
          _estadoControl = data['estado_control'] ?? 1;
          _mostrarEmpanadasMaster = data['mostrar_empanadas'] ?? false;
          _minutosEdicionController.text = (data['minutos_edicion'] ?? '5').toString();
          
          if (data['hora_apertura'] != null) {
            final parts = data['hora_apertura'].split(':');
            if (parts.length == 2) _horaApertura = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
          }
          if (data['hora_cierre'] != null) {
            final parts = data['hora_cierre'].split(':');
            if (parts.length == 2) _horaCierre = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
          }

          _aliasController.text = mpData['alias_mp'] ?? '';
          _cbuController.text = mpData['cbu_cvu'] ?? '';
          _whatsappController.text = mpData['whatsapp_comprobantes'] ?? '';
          _activarMp = mpData['activar_mp'] ?? false;
        });
      }

      final alarmaDoc = await FirebaseFirestore.instance.collection('config').doc('alarma').get();
      if (alarmaDoc.exists) {
        final aData = alarmaDoc.data()!;
        setState(() {
          _alarmaEnabled = aData['enabled'] ?? true;
          _alarmaTono = aData['tono'] ?? 'Corto';
          _alarmaUri = aData['uri']; 
          _alarmaVolumen = (aData['volume'] ?? 1.0) * 100.0;
          _alarmaLoop = aData['loop'] ?? false;
        });
      }
    } catch (e) {
      debugPrint("Error al recuperar configuración: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  bool _checkStatus() {
    if (_estadoControl == 0) return false;
    if (_estadoControl == 2) return true;
    
    final now = TimeOfDay.now();
    double nowVal = now.hour + now.minute / 60.0;
    double startVal = _horaApertura.hour + _horaApertura.minute / 60.0;
    double endVal = _horaCierre.hour + _horaCierre.minute / 60.0;
    
    if (startVal > endVal) {
      // Cruzando la medianoche (ej: 20:00 a 04:00)
      return (nowVal >= startVal || nowVal < endVal);
    } else {
      // Horario normal (ej: 10:00 a 20:00)
      return (nowVal >= startVal && nowVal < endVal);
    }
  }

  void _guardarConfiguracion() async {
    setState(() => _isSaving = true);
    try {
      // 1. GUARDAR DATOS DEL LOCAL
      await FirebaseFirestore.instance.collection('config').doc('datos_local').set({
        'nombre': _nombreController.text.trim(),
        'slogan': _sloganController.text.trim(),
        'direccion': _direccionController.text.trim(),
        'horario': '${_horaApertura.hour.toString().padLeft(2, '0')}:${_horaApertura.minute.toString().padLeft(2, '0')} a ${_horaCierre.hour.toString().padLeft(2, '0')}:${_horaCierre.minute.toString().padLeft(2, '0')}',
        'hora_apertura': '${_horaApertura.hour.toString().padLeft(2, '0')}:${_horaApertura.minute.toString().padLeft(2, '0')}',
        'hora_cierre': '${_horaCierre.hour.toString().padLeft(2, '0')}:${_horaCierre.minute.toString().padLeft(2, '0')}',
        'tiempo_demora': _demoraController.text.trim(),
        'precio_delivery': _parsePrice(_deliveryController.text),
        'v_envio_barrio': _parsePrice(_envioBarrioController.text),
        'v_envio_retiro': _parsePrice(_envioRetiroController.text),
        'unidad_comun': _parsePrice(_unidadComunController.text),
        'docena_comun': _parsePrice(_docenaComunController.text),
        'unidad_especial': _parsePrice(_unidadEspecialController.text),
        'docena_especial': _parsePrice(_docenaEspecialController.text),
        'estado_control': _estadoControl,
        'mostrar_empanadas': _mostrarEmpanadasMaster,
        'minutos_edicion': _minutosEdicionController.text.trim(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 2. GUARDAR MERCADO PAGO
      await FirebaseFirestore.instance.collection('config').doc('mercado_pago').set({
        'alias_mp': _aliasController.text.trim(),
        'cbu_cvu': _cbuController.text.trim(),
        'whatsapp_comprobantes': _whatsappController.text.trim(),
        'activar_mp': _activarMp,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 3. GUARDAR ALARMA
      await FirebaseFirestore.instance.collection('config').doc('alarma').set({
        'enabled': _alarmaEnabled,
        'tono': _alarmaTono,
        'uri': _alarmaUri,
        'volume': _alarmaVolumen / 100.0,
        'loop': _alarmaLoop,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 4. ACTUALIZAR ESTADO DINÁMICO
      await FirebaseFirestore.instance.collection('configuracion').doc('local').set({
        'estaAbierto': _checkStatus(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // 5. REGISTRAR NEGOCIO PARA PLATAFORMA ADMIN WINDOWS
      String businessId = _nombreController.text.trim().toLowerCase().replaceAll(' ', '_').replaceAll(RegExp(r'[^\w\s]+'), '');
      if (businessId.isEmpty) businessId = 'negocio_sin_nombre';

      final businessSnap = await FirebaseFirestore.instance.collection('configuracion_negocio').doc(businessId).get();
      
      await FirebaseFirestore.instance.collection('configuracion_negocio').doc(businessId).set({
        'nombre': _nombreController.text.trim(),
        'ultima_actualizacion': FieldValue.serverTimestamp(),
        'activo': businessSnap.exists ? (businessSnap.data()?['activo'] ?? true) : true,
        if (!businessSnap.exists) 'estado_pago': 'Pendiente',
        if (!businessSnap.exists) 'vencimiento': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        if (!businessSnap.exists) 'deuda_acumulada': 0.0,
        if (!businessSnap.exists) 'comision_porcentaje': 5.0,
      }, SetOptions(merge: true));

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configuración guardada correctamente'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _realizarCierreCaja() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirmar Cierre"),
        content: const Text("¿Estás seguro de realizar el cierre de caja? Esto reiniciará el contador de ventas actuales."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCELAR")),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text("CONFIRMAR CIERRE")),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _isClosing = true);
    try {
      final query = await FirebaseFirestore.instance.collection('pedidos').where('estado', isEqualTo: 'Finalizado').get();
      final untrackedDocs = query.docs.where((doc) => (doc.data()['contabilizado'] ?? false) == false).toList();
      if (untrackedDocs.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No hay pedidos nuevos para cerrar')));
        return;
      }
      double totalMonto = 0;
      for (var doc in untrackedDocs) totalMonto += (doc.data()['total'] ?? 0).toDouble();
      await FirebaseFirestore.instance.collection('cierres_caja').add({
        'fecha_cierre': FieldValue.serverTimestamp(),
        'monto_total': totalMonto,
        'total_pedidos': untrackedDocs.length,
      });
      final batch = FirebaseFirestore.instance.batch();
      for (var doc in untrackedDocs) batch.update(doc.reference, {'contabilizado': true});
      await batch.commit();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cierre de caja realizado con éxito'), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error en el cierre: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isClosing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Si quisieran ver una actualización en vivo de Cierres o Ventas, 
    // se podría usar un StreamBuilder. Por ahora, el formulario principal 
    // es estático (Stateful) para evitar perder el foco al tipear.
    
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Ajustes del Negocio", style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 20, color: Colors.black87)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white.withOpacity(0.5),
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
        foregroundColor: Colors.black87,
        actions: [
          IconButton(icon: const Icon(Icons.refresh, color: Color(0xFFFF7F50)), onPressed: () { _cargarConfiguracion(); }),
          IconButton(
            icon: const Icon(Icons.history, color: Color(0xFFFF7F50)),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const Scaffold(body: Center(child: Text("Próximamente..."))))),
          )
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFF0E6), Color(0xFFFFDAB9), Color(0xFFFFF5EE)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              children: [
                _buildDashboard(),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _isClosing ? null : _realizarCierreCaja,
                  icon: const Icon(Icons.lock_outline, size: 20),
                  label: const Text("REALIZAR CIERRE DE CAJA", style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.1)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey[900],
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 55),
                    elevation: 8,
                    shadowColor: Colors.blueGrey.withOpacity(0.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                  ),
                ),
                const SizedBox(height: 25),
                _buildSectionTitle("Control del Local"),
                _buildCard([
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_estadoControl == 0 ? "CERRADO ❌" : (_estadoControl == 2 ? "SIEMPRE ABIERTO ✅" : "MODO AUTO 🔄"), style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 14)),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Expanded(child: _smallStateBtn(0, "CERRAR", Colors.redAccent)),
                          const SizedBox(width: 8),
                          Expanded(child: _smallStateBtn(1, "AUTO", Colors.blueAccent)),
                          const SizedBox(width: 8),
                          Expanded(child: _smallStateBtn(2, "ABRIR", Colors.green)),
                        ],
                      )
                    ],
                  ),
                  if (_estadoControl == 1) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                      ),
                      child: Column(
                        children: [
                          Text("Rango Horario de Atención Automática", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey[800])),
                          const SizedBox(height: 15),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              _buildTimeSelector("Apertura", _horaApertura, (time) => setState(() => _horaApertura = time)),
                              const Icon(Icons.arrow_forward_rounded, color: Colors.blueAccent),
                              _buildTimeSelector("Cierre", _horaCierre, (time) => setState(() => _horaCierre = time)),
                            ],
                          )
                        ],
                      ),
                    ),
                  ],
                ]),
                const SizedBox(height: 25),
                
                _buildSectionTitle("Opciones de Pedidos"),
                _buildCard([
                  _buildTextField("Tiempo de Espera (minutos)", _demoraController, Icons.timer, isNumeric: true),
                  const SizedBox(height: 15),
                  _buildTextField("Minutos para cancelar/editar", _minutosEdicionController, Icons.edit_note, isNumeric: true),
                  const SizedBox(height: 15),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Alerta Sonora de Pedido", style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, color: Colors.black87)),
                      Switch(value: _alarmaEnabled, onChanged: (v) => setState(() => _alarmaEnabled = v), activeColor: const Color(0xFFFF6B35)),
                    ],
                  ),
                  if (_alarmaEnabled) ...[
                    const SizedBox(height: 15),
                    DropdownButtonFormField<String>(
                      value: _alarmaTono,
                      items: ['Corto', 'Campana', 'Sirena'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                      onChanged: (v) => setState(() => _alarmaTono = v!),
                      style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, color: Colors.black87),
                      decoration: InputDecoration(
                        labelText: "Tono de Notificación",
                        prefixIcon: const Icon(Icons.music_note, color: Color(0xFFFF6B35)),
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.6),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                      ),
                    ),
                  ]
                ]),
                const SizedBox(height: 25),

                _buildSectionTitle("Módulo de Mercado Pago"),
                _buildCard([
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Activar Pago Digital", style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, color: Colors.black87)),
                      Switch(value: _activarMp, onChanged: (v) => setState(() => _activarMp = v), activeColor: const Color(0xFFFF6B35)),
                    ],
                  ),
                  const SizedBox(height: 15),
                  _buildTextField("Alias MP", _aliasController, Icons.account_balance_wallet),
                  const SizedBox(height: 15),
                  _buildTextField("CBU / CVU", _cbuController, Icons.credit_card),
                ]),
                const SizedBox(height: 25),

                _buildSectionTitle("Branding"),
                _buildCard([
                  _buildTextField("Nombre", _nombreController, Icons.storefront),
                  const SizedBox(height: 15),
                  _buildTextField("Eslogan", _sloganController, Icons.auto_awesome),
                ]),
                const SizedBox(height: 25),
                 _buildSectionTitle("Envíos"),
                _buildCard([
                  _buildTextField("Al Barrio \$", _envioBarrioController, Icons.local_shipping, isNumeric: true),
                  const SizedBox(height: 15),
                  _buildTextField("A la Villa \$", _deliveryController, Icons.directions_bike, isNumeric: true),
                  const SizedBox(height: 15),
                  _buildTextField("Retiro \$", _envioRetiroController, Icons.store, isNumeric: true),
                ]),
                const SizedBox(height: 35),
                ElevatedButton(
                  onPressed: _isSaving ? null : _guardarConfiguracion,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF6B35), // Naranja vibrante
                    minimumSize: const Size(double.infinity, 60), 
                    elevation: 10,
                    shadowColor: const Color(0xFFFF6B35).withOpacity(0.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                  ),
                  child: _isSaving 
                      ? const CircularProgressIndicator(color: Colors.white) 
                      : Text("GUARDAR CAMBIOS", style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.5)),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _smallStateBtn(int val, String label, Color color) {
    bool sel = _estadoControl == val;
    return GestureDetector(
      onTap: () => setState(() => _estadoControl = val),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: sel ? color : Colors.white.withOpacity(0.5), 
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: sel ? color : Colors.grey.withOpacity(0.3)),
          boxShadow: sel ? [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 2))] : []
        ),
        child: Text(label, style: TextStyle(color: sel ? Colors.white : Colors.black54, fontSize: 10, fontWeight: FontWeight.w900)),
      ),
    );
  }

  Widget _buildDashboard() {
     return StreamBuilder<QuerySnapshot>(
      // Permite mostrar estadísticas reales del negocio en el Panel (si las hubiera)
      stream: FirebaseFirestore.instance.collection('pedidos').where('estado', isEqualTo: 'Finalizado').snapshots(),
      builder: (context, snapshot) {
        int ordenesFinalizadas = snapshot.data?.docs.length ?? 0;
        return Container(
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFF7F50), Color(0xFFFF4500)]
            ),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(color: const Color(0xFFFF4500).withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 8))
            ]
          ),
          child: Center(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.dashboard_customize_rounded, color: Colors.white, size: 28),
                    const SizedBox(width: 15),
                    Text("Panel de Control", style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 1.2)),
                  ],
                ),
                if (ordenesFinalizadas > 0) ...[
                  const SizedBox(height: 10),
                  Text("Órdenes Hoy: $ordenesFinalizadas", style: GoogleFonts.montserrat(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 14)),
                ]
              ],
            )
          ),
        );
      }
    );
  }

  Widget _buildSectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft, 
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12, left: 5), 
        child: Text(
          title.toUpperCase(), 
          style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.blueGrey[800], letterSpacing: 1.2)
        )
      )
    );
  }

  Widget _buildCard(List<Widget> children) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(20), 
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.65), 
            borderRadius: BorderRadius.circular(24), 
            border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, spreadRadius: 5)
            ]
          ), 
          child: Column(children: children)
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {bool isNumeric = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
      style: GoogleFonts.montserrat(fontWeight: FontWeight.w600, color: Colors.black87),
      decoration: InputDecoration(
        labelText: label, 
        labelStyle: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w500),
        prefixIcon: Icon(icon, color: const Color(0xFFFF6B35)), 
        filled: true,
        fillColor: Colors.white.withOpacity(0.6),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Color(0xFFFF6B35), width: 2)),
      ),
    );
  }

  Widget _buildTimeSelector(String label, TimeOfDay time, Function(TimeOfDay) onChanged) {
    return GestureDetector(
      onTap: () async {
        final TimeOfDay? picked = await showTimePicker(
          context: context,
          initialTime: time,
          builder: (context, child) {
            return Theme(
              data: ThemeData.light().copyWith(
                colorScheme: const ColorScheme.light(
                  primary: Color(0xFFFF6B35), 
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: Colors.black87,
                ),
                dialogBackgroundColor: Colors.white,
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          onChanged(picked);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFF6B35).withOpacity(0.5)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
          ]
        ),
        child: Column(
          children: [
            Text(label, style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[600])),
            const SizedBox(height: 5),
            Text(
              "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}",
              style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.w900, color: const Color(0xFFFF6B35)),
            )
          ],
        ),
      ),
    );
  }
}

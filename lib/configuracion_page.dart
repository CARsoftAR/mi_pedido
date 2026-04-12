import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  int _estadoControl = 1; // 0=Cerrado, 1=Auto, 2=Abierto
  bool _isSaving = false;
  bool _isLoading = true;
  bool _isClosing = false;
  bool _mostrarEmpanadasMaster = false;

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
          _nombreController.text = data['nombre'] ?? 'Pizzería Miguel Angel';
          _sloganController.text = data['slogan'] ?? '¡Pizzas con Amor!';
          _direccionController.text = data['direccion'] ?? '';
          _horarioController.text = data['horario'] ?? '';
          _demoraController.text = data['tiempo_demora'] ?? '';
          _deliveryController.text = _formatPrice(data['precio_delivery']);
          _envioBarrioController.text = _formatPrice(data['v_envio_barrio'] ?? 0);
          _envioRetiroController.text = _formatPrice(data['v_envio_retiro'] ?? 0);
          
          _unidadComunController.text = _formatPrice(data['unidad_comun']);
          _docenaComunController.text = _formatPrice(data['docena_comun']);
          _unidadEspecialController.text = _formatPrice(data['unidad_especial']);
          _docenaEspecialController.text = _formatPrice(data['docena_especial']);
          
          _aliasController.text = data['alias_mp'] ?? '';
          _cbuController.text = data['cbu_cvu'] ?? '';
          _mostrarEmpanadasMaster = data['mostrar_empanadas'] ?? false;
          
          if (data.containsKey('estado_control')) {
            _estadoControl = data['estado_control'] ?? 1;
          } else {
            // Migración: si existe el campo viejo, lo mapeamos
            bool viejo = data['local_abierto_manual'] ?? true;
            _estadoControl = viejo ? 1 : 0;
          }
        });
      }

      // Cargar WhatsApp desde configuracion_negocio
      final negocioDoc = await FirebaseFirestore.instance.collection('configuracion_negocio').doc('contacto').get();
      if (negocioDoc.exists) {
        setState(() {
          _whatsappController.text = negocioDoc.data()?['whatsapp_comprobantes'] ?? '';
        });
      }

      // Cargar tiempo de edición desde config/tiempos
      final tiemposDoc = await FirebaseFirestore.instance.collection('config').doc('tiempos').get();
      if (tiemposDoc.exists) {
        setState(() {
          _minutosEdicionController.text = (tiemposDoc.data()?['minutos_edicion'] ?? 5).toString();
        });
      }
    } catch (e) {
      debugPrint("Error al cargar configuración: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  bool _checkStatus() {
    if (_estadoControl == 0) return false;
    if (_estadoControl == 2) return true;
    
    // Modo AUTO (1) - Lógica Dinámica
    try {
      final horario = _horarioController.text.toLowerCase();
      // Buscamos números de 1 o 2 dígitos
      final matches = RegExp(r'(\d{1,2})').allMatches(horario).toList();
      
      if (matches.length >= 2) {
        int start = int.parse(matches[0].group(0)!);
        int end = int.parse(matches[matches.length - 1].group(0)!);
        
        final int now = DateTime.now().hour;
        if (start > end) { // Cruza medianoche
          return (now >= start) || (now < end);
        } else {
          return (now >= start) && (now < end);
        }
      }
    } catch (e) {
      debugPrint("Error parseando horario: $e");
    }

    // Fallback original
    final int hora = DateTime.now().hour;
    return (hora >= 20) || (hora < 4);
  }

  void _guardarConfiguracion() async {
    setState(() => _isSaving = true);
    try {
      final Map<String, dynamic> data = {
        'nombre': _nombreController.text.trim(),
        'slogan': _sloganController.text.trim(),
        'direccion': _direccionController.text.trim(),
        'horario': _horarioController.text.trim(),
        'tiempo_demora': _demoraController.text.trim(),
        'precio_delivery': _parsePrice(_deliveryController.text), // Villa
        'v_envio_barrio': _parsePrice(_envioBarrioController.text),
        'v_envio_retiro': _parsePrice(_envioRetiroController.text),
        'unidad_comun': _parsePrice(_unidadComunController.text),
        'docena_comun': _parsePrice(_docenaComunController.text),
        'unidad_especial': _parsePrice(_unidadEspecialController.text),
        'docena_especial': _parsePrice(_docenaEspecialController.text),
        'alias_mp': _aliasController.text.trim(),
        'cbu_cvu': _cbuController.text.trim(),
        'whatsapp_comprobantes': _whatsappController.text.trim(),
        'estado_control': _estadoControl,
        'mostrar_empanadas': _mostrarEmpanadasMaster,
        'updated_at': FieldValue.serverTimestamp(),
      };
      
      // GUARDAR EN AMBOS LUGARES PARA COMPATIBILIDAD (Seguridad Gonzalo)
      await FirebaseFirestore.instance.collection('configuracion_local').doc('precios').set(data, SetOptions(merge: true));
      
      // ACTUALIZAR ESTADO DINÁMICO PARA EL CLIENTE (configuracion/local -> estaAbierto)
      await FirebaseFirestore.instance.collection('configuracion').doc('local').set({
        'estaAbierto': _checkStatus(),
        'nombre': _nombreController.text.trim(),
        'slogan': _sloganController.text.trim(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      
      // Guardar WhatsApp en configuracion_negocio (Respaldo/Compatibilidad)
      await FirebaseFirestore.instance.collection('configuracion_negocio').doc('contacto').set({
        'whatsapp_comprobantes': _whatsappController.text.trim(),
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Guardar tiempo de edición en config/tiempos
      await FirebaseFirestore.instance.collection('config').doc('tiempos').set({
        'minutos_edicion': int.tryParse(_minutosEdicionController.text) ?? 5,
        'updated_at': FieldValue.serverTimestamp(),
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
      final query = await FirebaseFirestore.instance
          .collection('pedidos')
          .where('estado', isEqualTo: 'Finalizado')
          .get();

      final untrackedDocs = query.docs.where((doc) => (doc.data()['contabilizado'] ?? false) == false).toList();

      if (untrackedDocs.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No hay pedidos nuevos para cerrar')));
        return;
      }

      double totalMonto = 0;
      for (var doc in untrackedDocs) {
        totalMonto += (doc.data()['total'] ?? 0).toDouble();
      }

      await FirebaseFirestore.instance.collection('cierres_caja').add({
        'fecha_cierre': FieldValue.serverTimestamp(),
        'monto_total': totalMonto,
        'total_pedidos': untrackedDocs.length,
      });

      final batch = FirebaseFirestore.instance.batch();
      for (var doc in untrackedDocs) {
        batch.update(doc.reference, {'contabilizado': true});
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cierre de caja realizado con éxito'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error en el cierre: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isClosing = false);
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
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Cerrar Sesión"),
                  content: const Text("¿Estás seguro de que quieres salir de la cuenta de administrador?"),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCELAR")),
                    ElevatedButton(onPressed: () => Navigator.pop(context, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text("CERRAR SESIÓN")),
                  ],
                ),
              );

              if (confirmed == true) {
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                // En la App Admin, redirige a una pantalla de salida o simplemente aviso
                if (mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Sesión Cerrada. Reinicie la App.")));
                }
              }
            },
            tooltip: "Cerrar Sesión",
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HistorialCierresPage())),
            tooltip: "Historial de Cierres",
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // DASHBOARD CIERRE DE CAJA
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('pedidos').where('estado', isEqualTo: 'Finalizado').snapshots(),
              builder: (context, snapshot) {
                double totalActual = 0;
                int countActual = 0;
                if (snapshot.hasData) {
                  for (var doc in snapshot.data!.docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    if ((data['contabilizado'] ?? false) == false) {
                      totalActual += (data['total'] ?? 0).toDouble();
                      countActual++;
                    }
                  }
                }
                return Column(
                  children: [
                    _buildDashboard(totalActual, countActual),
                    const SizedBox(height: 15),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isClosing ? null : _realizarCierreCaja,
                            icon: _isClosing 
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.lock_outline, size: 20),
                            label: const Text("REALIZAR CIERRE DE CAJA", style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueGrey[800],
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 15),
            _buildSectionTitle("Control del Local"),
            _buildCard([
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _estadoControl == 0 
                            ? "CERRADO ❌" 
                            : (_estadoControl == 2 ? "SIEMPRE ABIERTO ✅" : (_checkStatus() ? "AUTO: ABIERTO ✅" : "AUTO: CERRADO ❌")),
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: _estadoControl == 0 
                              ? Colors.red[700] 
                              : (_estadoControl == 2 
                                  ? Colors.green[700] 
                                  : (_checkStatus() ? Colors.green[700] : Colors.grey[700])),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _estadoControl == 1 ? Colors.blue[50] : Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _estadoControl == 1 ? "MODO RELOJ" : "MODO MANUAL",
                          style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.bold, color: _estadoControl == 1 ? Colors.blue[800] : Colors.grey[700]),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      children: [
                        _buildStateButton(0, "CERRADO", Colors.red),
                        _buildStateButton(1, "AUTO", Colors.blue),
                        _buildStateButton(2, "ABIERTO", Colors.green),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _estadoControl == 0 
                      ? "El local ignora el reloj y figura siempre CERRADO." 
                      : (_estadoControl == 2 
                        ? "El local ignora el reloj y figura siempre ABIERTO."
                        : "El local respeta el horario: ${_horarioController.text}"),
                    style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ]),
            const SizedBox(height: 20),
            
            _buildSectionTitle("Branding de la Tienda"),
            _buildCard([
              _buildTextField("Nombre de la Pizzería", _nombreController, Icons.storefront),
              _buildTextField("Eslogan o Frase", _sloganController, Icons.auto_awesome),
            ]),

            const SizedBox(height: 25),

            _buildSectionTitle("Gestión de Envíos"),
            _buildCard([
              _buildTextField("Envío al Barrio \$", _envioBarrioController, Icons.local_shipping, isNumeric: true),
              _buildTextField("Envío a la Villa \$", _deliveryController, Icons.directions_bike, isNumeric: true),
              _buildTextField("Retiro por el Local \$", _envioRetiroController, Icons.store, isNumeric: true),
            ]),

            const SizedBox(height: 25),

            _buildSectionTitle("Demora y Edición de Pedidos"),
            _buildCard([
              _buildTextField("Dirección del Local", _direccionController, Icons.map),
              _buildTextField("Horario de Atención", _horarioController, Icons.access_time),
              _buildTextField("Demora estimada (ej: 40-50 min)", _demoraController, Icons.timer),
              _buildTextField("Límite de edición (minutos)", _minutosEdicionController, Icons.edit_calendar, isNumeric: true),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  "El cliente podrá editar su pedido hasta que pasen estos minutos.",
                  style: GoogleFonts.montserrat(fontSize: 10, color: Colors.blueGrey[400], fontStyle: FontStyle.italic),
                ),
              ),
            ]),
            
            const SizedBox(height: 25),

            _buildSectionTitle("Módulo de Empanadas"),
            _buildCard([
              SwitchListTile(
                title: Text("Activar Sección de Empanadas", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text("Si se apaga, las empanadas no aparecerán en la carta ni se podrán editar precios.", style: GoogleFonts.montserrat(fontSize: 11)),
                value: _mostrarEmpanadasMaster,
                activeColor: const Color(0xFFFF7F50),
                onChanged: (val) async {
                  setState(() => _mostrarEmpanadasMaster = val);
                  // Guardado inmediato para persistencia definitiva
                  await FirebaseFirestore.instance.collection('configuracion_local').doc('precios').set({
                    'mostrar_empanadas': val,
                  }, SetOptions(merge: true));
                },
              ),
            ]),

            const SizedBox(height: 25),
            
            // SECCIONES DE EMPANADAS (DINÁMICAS)
            if (_mostrarEmpanadasMaster) ...[
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
              const SizedBox(height: 25),
            ],
            
            _buildSectionTitle("Cobros (Mercado Pago / Transferencia)"),
            _buildCard([
              _buildTextField("Alias Mercado Pago", _aliasController, Icons.account_balance_wallet_outlined),
              _buildTextField("Teléfono", _cbuController, Icons.phone_android),
              _buildTextField("WhatsApp para Comprobantes", _whatsappController, Icons.chat_bubble_outline, isPhone: true),
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  "Este número se usará para recibir los comprobantes de transferencia.",
                  style: GoogleFonts.montserrat(fontSize: 11, color: Colors.grey[500], fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
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
          Text("VENTAS ACTUALES (POR CERRAR)", style: GoogleFonts.montserrat(color: Colors.white.withOpacity(0.8), fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
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
              Text("Pedidos sin contabilizar: $count", style: GoogleFonts.montserrat(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
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

  Widget _buildStateButton(int value, String label, Color activeColor) {
    bool isSelected = _estadoControl == value;
    return Expanded(
      child: GestureDetector(
        onTap: () async {
          setState(() => _estadoControl = value);
          // value: 0=Cerrado, 1=Auto(Abierto), 2=Siempre Abierto
          final bool nuevoEstado = value != 0; // 0=cerrado, 1 y 2 = abierto
          try {
            // Escribe el estado_control para la app admin
            await FirebaseFirestore.instance.collection('configuracion_local').doc('precios').update({
              'estado_control': value,
              'updated_at': FieldValue.serverTimestamp(),
            });
            // SINCRONIZACIÓN EN TIEMPO REAL: escribe estaAbierto para la app cliente
            await FirebaseFirestore.instance.collection('configuracion').doc('local').set({
              'estaAbierto': nuevoEstado,
              'updated_at': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          } catch (e) {
            debugPrint("Error updating status: $e");
          }
        },

        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, IconData icon, {bool isNumeric = false, bool isPhone = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        keyboardType: isNumeric || isPhone ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
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

class HistorialCierresPage extends StatelessWidget {
  const HistorialCierresPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: Text("Historial de Cierres", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('cierres_caja').orderBy('fecha_cierre', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text("No hay cierres registrados", style: GoogleFonts.montserrat(color: Colors.grey)));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: snapshot.data!.docs.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
              final date = (data['fecha_cierre'] as Timestamp).toDate();
              final format = DateFormat('dd/MM/yyyy HH:mm');

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.receipt_long, color: Color(0xFFFF7F50)),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(format.format(date), style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 14)),
                          Text("${data['total_pedidos']} pedidos registrados", style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey[600])),
                        ],
                      ),
                    ),
                    Text("\$ ${data['monto_total'].toStringAsFixed(2)}", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green[700])),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}


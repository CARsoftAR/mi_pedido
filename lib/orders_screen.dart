import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<String> _processedOrders = {}; 
  bool _remoteAlarmEnabled = true;
  double _remoteVolume = 1.0;
  bool _remoteLoop = false;
  String _currentTono = 'Corto';
  String? _selectedUri;
  bool _isShowingDialog = false;
  final AudioPlayer _audioPlayerInstance = AudioPlayer();
  static const _channel = MethodChannel('com.mipedido.pizzeria/sounds');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAlertPreference();
    _initOrderListener();
  }

  bool _isFirstLoad = true;

  Future<void> _loadAlertPreference() async {
    // Vincular con Alarma Remota (Firebase)
    FirebaseFirestore.instance.collection('config').doc('alarma').snapshots().listen((snap) {
      if (snap.exists) {
        if (mounted) {
          final data = snap.data() as Map<String, dynamic>;
          setState(() {
            _remoteAlarmEnabled = data['enabled'] ?? true;
            _remoteVolume = (data['volume'] ?? 1.0).toDouble();
            _remoteLoop = data['loop'] ?? false;
            _currentTono = data['tono'] ?? 'Corto';
            _selectedUri = data['uri'];
          });
          debugPrint("Configuración de Alarma Cargada: URI=$_selectedUri, Vol=$_remoteVolume");
        }
      } else {
        // CREAR SI NO EXISTE
        FirebaseFirestore.instance.collection('config').doc('alarma').set({
          'enabled': true,
          'tono': 'Corto',
          'uri': null, // Se configurará luego
          'volume': 1.0,
          'loop': false,
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    });
  }

  void _initOrderListener() {
    FirebaseFirestore.instance
        .collection('pedidos')
        .where('estado', isEqualTo: 'Pendiente')
        .snapshots()
        .listen((snapshot) {
          if (_isFirstLoad) {
            // En la primera carga, solo marcamos los existentes como procesados
            for (var doc in snapshot.docs) {
              _processedOrders.add(doc.id);
            }
            _isFirstLoad = false;
            debugPrint("Carga inicial de pedidos completada: ${_processedOrders.length} pre-existentes.");
            return;
          }

          for (var change in snapshot.docChanges) {
            if (change.type == DocumentChangeType.added) {
              final doc = change.doc;
              if (!_processedOrders.contains(doc.id)) {
                _processedOrders.add(doc.id);
                debugPrint("¡NUEVO PEDIDO DETECTADO! ID: ${doc.id}");
                if (!_isShowingDialog) {
                  _playNotificationSound();
                  _showNewOrderDialog(doc);
                }
              }
            }
          }
        });
  }

  Future<void> _playNotificationSound({bool force = false}) async {
    if (!force && (!_remoteAlarmEnabled)) return;
    
    try {
      debugPrint("Intentando reproducir alarma: URI=$_selectedUri, Tono=$_currentTono");
      
      // Detener cualquier sonido previo
      FlutterRingtonePlayer().stop();
      await _channel.invokeMethod('stopAllSounds');

      if (_selectedUri != null && _selectedUri!.isNotEmpty) {
        // REPRODUCCIÓN POR URI (Elegido por el usuario en el cel)
        final bool success = await _channel.invokeMethod('playCustomRingtone', {
          'uri': _selectedUri,
          'volume': _remoteVolume,
          'loop': _remoteLoop,
        });
        debugPrint("Resultado playCustomRingtone: $success");
      } else {
        // Fallback a sonidos predefinidos si no hay URI (Compatibilidad)
        debugPrint("No hay URI específica, usando fallback de tono: $_currentTono");
        if (_currentTono == 'Sirena') {
          FlutterRingtonePlayer().playAlarm();
        } else if (_currentTono == 'Campana') {
          FlutterRingtonePlayer().playRingtone();
        } else {
          // Si es 'Corto' o cualquier otro, usamos Notification (que suele ser el 'BUBBLE')
          // Lo cambiamos a playAlarm() si queremos que sea más ruidoso
          FlutterRingtonePlayer().playNotification();
        }
      }
      
      // Lógica de Repetición (Loop)
      if (_remoteLoop) {
        Future.delayed(const Duration(seconds: 4), () {
          if (_isShowingDialog && _remoteLoop && mounted) {
            debugPrint("Re-disparando alarma (Loop activo)...");
            _playNotificationSound(force: true);
          }
        });
      }
    } catch (e) {
      debugPrint("Error al reproducir sonido de notificación: $e");
    }
  }

  void _stopAllSounds() {
    FlutterRingtonePlayer().stop();
    _audioPlayerInstance.stop();
    _channel.invokeMethod('stopAllSounds');
  }

  void _showNewOrderDialog(DocumentSnapshot doc) {
    setState(() => _isShowingDialog = true);
    final data = doc.data() as Map<String, dynamic>;
    final List productos = data['productos'] ?? [];
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              color: const Color(0xFFFF7F50),
              child: Column(
                children: [
                   const Icon(Icons.notifications_active, color: Colors.white, size: 40),
                   const SizedBox(height: 10),
                   Text("¡NUEVO PEDIDO!", style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 18, letterSpacing: 1.2)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(25),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(data['nombre_cliente'] ?? 'Desconocido', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text("PRODUCTOS:", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(height: 10),
                  ...productos.map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text("• ${p['cantidad']}x ${p['nombre']}", style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w600)),
                  )),
                  const Divider(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("TOTAL:", style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 18)),
                      Text(_formatMoney(data['total']), style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 24, color: const Color(0xFFFF7F50))),
                    ],
                  ),
                  const SizedBox(height: 25),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _tabController.animateTo(0);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF7F50),
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    child: Text("VER PEDIDO", style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, color: Colors.white)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).then((_) {
      _stopAllSounds();
      if (mounted) setState(() => _isShowingDialog = false);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _audioPlayerInstance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: Text("Pizzería Miguel Angel", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('config').doc('alarma').snapshots(),
            builder: (context, snapshot) {
              final bool isEnabled = (snapshot.data?.data() as Map?)?['enabled'] ?? true;
              return IconButton(
                icon: Icon(
                  isEnabled ? Icons.notifications_active : Icons.notifications_off, 
                  color: isEnabled ? const Color(0xFFFF7F50) : Colors.grey
                ),
                onPressed: () async {
                  bool newEnabled = !isEnabled;
                  await FirebaseFirestore.instance.collection('config').doc('alarma').set({
                    'enabled': newEnabled,
                    'updated_at': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true));
                  
                  if (newEnabled) {
                    _playNotificationSound(force: true);
                    Future.delayed(const Duration(seconds: 2), () => _stopAllSounds());
                  }
                },
              );
            }
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFF7F50),
          labelColor: const Color(0xFFFF7F50),
          unselectedLabelColor: Colors.grey,
          isScrollable: true,
          labelStyle: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 11),
          tabs: const [
            Tab(text: "PENDIENTES"),
            Tab(text: "COCINA"),
            Tab(text: "LISTOS"),
            Tab(text: "TOTALES"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrderList('Pendiente'),
          _buildOrderList('En Preparación'),
          _buildOrderList('En Mostrador'),
          _buildOrderList('Historial/Entregas'),
        ],
      ),
    );
  }

  Widget _buildOrderList(String estado) {
    return StreamBuilder<QuerySnapshot>(
      stream: estado == 'En Mostrador' 
          ? FirebaseFirestore.instance.collection('pedidos').where('estado', isEqualTo: 'listo_para_despacho').snapshots()
          : estado == 'Historial/Entregas'
              ? FirebaseFirestore.instance.collection('pedidos').where('estado', whereIn: ['Despachado', 'Finalizado']).snapshots()
              : FirebaseFirestore.instance.collection('pedidos').where('estado', isEqualTo: estado).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        
        docs.sort((a, b) {
          final Timestamp? aTime = (a.data() as Map)['createdAt'];
          final Timestamp? bTime = (b.data() as Map)['createdAt'];
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime);
        });

        if (docs.isEmpty) return Center(child: Text("Sin pedidos.", style: GoogleFonts.montserrat(color: Colors.grey)));

        return ListView.builder(
          padding: const EdgeInsets.all(15),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final String id = doc.id;
            final String status = data['estado'] ?? 'Pendiente';
            final bool isCocina = status == 'En Preparación';
            final bool isReadyForDispatch = status == 'listo_para_despacho';
            final bool isEnCamino = status == 'Despachado';

            return Container(
              margin: const EdgeInsets.only(bottom: 15),
              decoration: BoxDecoration(
                color: isReadyForDispatch ? Colors.green[50] : (isEnCamino ? Colors.blue[50] : Colors.white),
                borderRadius: BorderRadius.circular(25),
                border: isReadyForDispatch ? Border.all(color: Colors.green, width: 2) : (isEnCamino ? Border.all(color: Colors.blue, width: 2) : null),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)]
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    title: Text("${data['nombre_cliente'] ?? 'Cliente'} (#${id.substring(id.length - 4)})", style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 16)),
                    trailing: isCocina ? _buildActionButton(id, status, data) : null,
                  ),
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("PRODUCTOS:", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.grey[700])),
                        ...(data['productos'] as List? ?? []).map((p) => Text("• ${p['cantidad']}x ${p['nombre']}", style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w700))),
                        
                        const SizedBox(height: 12),
                        
                        // DIRECCIÓN REAL - ALTA VISIBILIDAD
                        if (status != 'En Preparación') ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            width: double.infinity,
                            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.08), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.orange.withOpacity(0.2))),
                            child: Row(
                              children: [
                                const Icon(Icons.location_on, color: Color(0xFFFF7F50), size: 18),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    "ENTREGA: ${
                                      (data['direccion_entrega']?.toString().isNotEmpty == true && !data['direccion_entrega'].toLowerCase().contains("calle falsa")) 
                                      ? data['direccion_entrega'] 
                                      : (data['lat_cliente'] != null ? '📍 UBICACIÓN POR GPS (VER MAPA)' : 'Retira en Local')
                                    }", 
                                    style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFF2D2D2D))
                                  )
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 15),
                          const SizedBox(height: 15),
                        ],

                        // BLOQUE DE PAGO - NUEVO
                        if (status != "En Preparación") ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.08), 
                              borderRadius: BorderRadius.circular(15), 
                              border: Border.all(color: Colors.blue.withOpacity(0.2))
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (data['metodo_pago'] == 'Efectivo') ...[
                                  Row(
                                    children: [
                                      const Icon(Icons.payments, color: Colors.green, size: 18),
                                      const SizedBox(width: 10),
                                      Text(
                                        "EFECTIVO", 
                                        style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.green[800])
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  Builder(builder: (context) {
                                    double pagaCon = double.tryParse(data['paga_con'].toString()) ?? 0;
                                    double total = (data['total'] is num) ? data['total'].toDouble() : 0.0;
                                    double cambio = pagaCon - total;
                                    return Text(
                                      "💵 Paga con: ${_formatMoney(pagaCon)} | Cambio: ${_formatMoney(cambio > 0 ? cambio : 0.0)}",
                                      style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.black87)
                                    );
                                  }),
                                ] else if (data['metodo_pago'] == 'Mercado Pago') ...[
                                  Row(
                                    children: [
                                      const Icon(Icons.account_balance_wallet, color: Color(0xFF00B1EA), size: 18),
                                      const SizedBox(width: 10),
                                      Text(
                                        "MERCADO PAGO (Alias/CBU)", 
                                        style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.w900, color: const Color(0xFF00779E))
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    "💳 Pago por Transferencia / App MP",
                                    style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.black87)
                                  ),
                                ] else ...[
                                  Text("⚠️ Sin método de pago especificado", style: GoogleFonts.montserrat(fontSize: 12, color: Colors.red)),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 15),
                        ],

                        // ACCIONES (Si no es Cocina, lo mostramos aquí abajo para más comodidad)
                        if (!isCocina) ...[
                          Center(child: _buildActionButton(id, status, data)),
                          const SizedBox(height: 15),
                        ],
                      ],
                    ),
                  ),
                  
                  if (!isCocina && data['lat_cliente'] != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      child: _buildMapsButton(data['lat_cliente'], data['long_cliente']),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActionButton(String id, String currentStatus, Map<String, dynamic> data) {
    if (currentStatus == 'Pendiente') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // BOTÓN RECHAZAR GIGANTE
          Container(
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
            child: IconButton(
              iconSize: 40,
              padding: const EdgeInsets.all(12),
              icon: const Icon(Icons.cancel, color: Colors.red),
              onPressed: () => _rejectOrder(id, data),
            ),
          ),
          const SizedBox(width: 20),
          // BOTÓN ACEPTAR GIGANTE
          Container(
            decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
            child: IconButton(
              iconSize: 40,
              padding: const EdgeInsets.all(12),
              icon: const Icon(Icons.check_circle, color: Colors.green),
              onPressed: () => _acceptOrder(id, data),
            ),
          ),
        ],
      );
    }

    if (currentStatus == 'En Preparación') {
      return ElevatedButton.icon(
        onPressed: () => FirebaseFirestore.instance.collection('pedidos').doc(id).update({'estado': 'listo_para_despacho', 'updatedAt': FieldValue.serverTimestamp()}),
        icon: const Icon(Icons.restaurant, size: 30),
        label: Text("LISTO", style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 16)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 5,
        ),
      );
    }

    if (currentStatus == 'listo_para_despacho') {
      return ElevatedButton.icon(
        onPressed: () => _dispatchOrder(id, data),
        icon: const Icon(Icons.delivery_dining, size: 35),
        label: Text("DESPACHAR", style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 14)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFF7F50),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 5,
        ),
      );
    }

    if (currentStatus == 'Despachado') {
      return ElevatedButton(
        onPressed: () => FirebaseFirestore.instance.collection('pedidos').doc(id).update({'estado': 'Finalizado'}),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        ),
        child: Text("ENTREGADO", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 11)),
      );
    }

    return const Icon(Icons.check, color: Colors.blue);
  }

  Future<void> _acceptOrder(String id, Map<String, dynamic> data) async {
    if (data['metodo_pago']?.toString().contains('TRANSFERENCIA') == true) {
      final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text("Confirmación"), content: const Text("¿Verificaste Mercado Pago?"), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text("NO")), TextButton(onPressed: () => Navigator.pop(c, true), child: const Text("SÍ"))]));
      if (confirm != true) return;
    }
    FirebaseFirestore.instance.collection('pedidos').doc(id).update({'estado': 'En Preparación', 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> _rejectOrder(String id, Map<String, dynamic> data) async {
    String selectedReason = "";
    final controller = TextEditingController();

    final reason = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          Widget buildChip(String label) {
            bool isSelected = label == selectedReason;
            return ListTile(
              title: Text(label, style: GoogleFonts.montserrat(fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
              trailing: isSelected ? const Icon(Icons.check_circle, color: Colors.red) : null,
              onTap: () => setDialogState(() => selectedReason = label),
            );
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
            title: Text("❌ Rechazar Pedido", style: GoogleFonts.montserrat(fontWeight: FontWeight.w900)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                buildChip("Pago no recibido"),
                buildChip("Sin stock"),
                buildChip("Fuera de zona"),
                buildChip("Otro"),
                if (selectedReason == "Otro")
                  TextField(controller: controller, decoration: const InputDecoration(hintText: "Escribí el motivo...")),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCELAR")),
            ElevatedButton(
              onPressed: selectedReason.isEmpty ? null : () {
                final finalReason = selectedReason == "Otro" ? controller.text : selectedReason;
                if (finalReason.isNotEmpty) Navigator.pop(context, finalReason);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text("CONFIRMAR", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      }),
    );

    if (reason != null && reason.isNotEmpty) {
      FirebaseFirestore.instance.collection('pedidos').doc(id).update({
        'estado': 'rechazado',
        'motivo_rechazo': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _dispatchOrder(String id, Map<String, dynamic> data) async {
    await FirebaseFirestore.instance.collection('pedidos').doc(id).update({'estado': 'Despachado', 'updatedAt': FieldValue.serverTimestamp()});
    final phone = data['cliente'] ?? '';
    final name = data['nombre_cliente'] ?? 'Cliente';
    final address = data['direccion_entrega'] ?? data['direccion'] ?? 'tu domicilio';
    String finalNumber = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (finalNumber.length == 10) finalNumber = "549$finalNumber";
    final msg = "¡Hola $name! Tu pedido de Pizzería Miguel Angel ya salió del local y va en camino a $address. ¡Que lo disfrutes! 🍕🛵";
    final url = "https://wa.me/$finalNumber?text=${Uri.encodeComponent(msg)}";
    if (await canLaunchUrl(Uri.parse(url))) await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Widget _buildMapsButton(double lat, double lng) {
    return ElevatedButton.icon(
      onPressed: () async {
        final url = "https://www.google.com/maps/search/?api=1&query=$lat,$lng";
        if (await canLaunchUrl(Uri.parse(url))) await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      },
      icon: const Icon(Icons.location_on),
      label: const Text("VER MAPA"),
      style: ElevatedButton.styleFrom(backgroundColor: Colors.blue[700], foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
    );
  }
  String _formatMoney(dynamic value) {
    if (value == null) return "\$0,00";
    double price = (value is num) ? value.toDouble() : (double.tryParse(value.toString().replaceAll(',', '.')) ?? 0.0);
    return "\$${price.toStringAsFixed(2).replaceAll('.', ',')}";
  }
}

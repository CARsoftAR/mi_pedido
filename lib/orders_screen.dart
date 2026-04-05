import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:blue_thermal_printer/blue_thermal_printer.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final Set<String> _processedOrders = {}; 
  bool _isShowingDialog = false;
  String _alertType = 'notification'; 
  String? _selectedRingtoneUri;
  String? _selectedRingtoneTitle;
  final AudioPlayer _audioPlayerInstance = AudioPlayer();
  static const _channel = MethodChannel('com.mipedido.pizzeria/sounds');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadAlertPreference();
    _loadSystemRingtones();
    _initOrderListener();
  }

  Future<void> _loadSystemRingtones() async {
    // Característica deshabilitada para mejorar compatibilidad con Android 14
  }

  Future<void> _loadAlertPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _alertType = prefs.getString('alert_type') ?? 'notification';
      _selectedRingtoneUri = prefs.getString('ringtone_uri');
      _selectedRingtoneTitle = prefs.getString('ringtone_title');
    });
  }

  Future<void> _saveAlertPreference(String type, {String? uri, String? title}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('alert_type', type);
    if (uri != null) await prefs.setString('ringtone_uri', uri);
    if (title != null) await prefs.setString('ringtone_title', title);
    
    setState(() {
      _alertType = type;
      if (uri != null) _selectedRingtoneUri = uri;
      if (title != null) _selectedRingtoneTitle = title;
    });
  }

  void _initOrderListener() {
    FirebaseFirestore.instance
        .collection('pedidos')
        .where('estado', isEqualTo: 'Pendiente')
        .snapshots()
        .listen((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            for (var doc in snapshot.docs) {
              if (!_processedOrders.contains(doc.id)) {
                _processedOrders.add(doc.id);
                
                // Si el diálogo ya está abierto, no acumulamos más para evitar pantalla negra
                if (!_isShowingDialog) {
                  _playNotificationSound();
                  _showNewOrderDialog(doc);
                }
              }
            }
          }
        });
  }

  Future<void> _playNotificationSound() async {
    if (_alertType == 'silent') return;

    try {
      if (_alertType == 'custom' && _selectedRingtoneUri != null) {
        // SOLUCION DEFINITIVA: Usar canal nativo para saltar restricciones de MediaPlayer
        await _channel.invokeMethod('playCustomRingtone', {'uri': _selectedRingtoneUri});
      } else if (_alertType == 'alarm') {
        FlutterRingtonePlayer().playAlarm();
      } else if (_alertType == 'ringtone') {
        FlutterRingtonePlayer().playRingtone();
      } else {
        FlutterRingtonePlayer().playNotification();
      }
    } catch (e) {
      debugPrint("Error playing sound: $e");
    }
  }

  void _stopAllSounds() {
    FlutterRingtonePlayer().stop();
    _audioPlayerInstance.stop();
    _channel.invokeMethod('stopAllSounds');
  }

  void _showRingtonePickerDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text("Melodías del Celular", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Padding(
          padding: const EdgeInsets.all(20),
          child: Text("La selección de melodías personalizadas ha sido deshabilitada temporalmente para garantizar la compatibilidad con Android 14. Se usarán los tonos estándar del sistema.", style: GoogleFonts.montserrat(fontSize: 13)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("ENTENDIDO")),
        ],
      ),
    );
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
                  Row(
                    children: [
                      const Icon(Icons.person, color: Color(0xFFFF7F50), size: 18),
                      const SizedBox(width: 10),
                      Text(data['nombre_cliente'] ?? 'Desconocido', style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 16)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.phone, color: Colors.grey, size: 18),
                      const SizedBox(width: 10),
                      Text(data['cliente'] ?? '--', style: GoogleFonts.montserrat(fontSize: 14)),
                    ],
                  ),
                  const Divider(height: 30),
                  
                  if (data['metodo_pago'] != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 15),
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 15),
                      decoration: BoxDecoration(
                        color: data['metodo_pago'].toString().contains('TRANSFERENCIA') ? Colors.red[50] : Colors.blueGrey[50], 
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: data['metodo_pago'].toString().contains('TRANSFERENCIA') ? Colors.red.withOpacity(0.2) : Colors.blueGrey.withOpacity(0.2))
                      ),
                      child: Row(
                        children: [
                          Icon(
                            data['metodo_pago'].toString().contains('TRANSFERENCIA') ? Icons.warning_amber_rounded : Icons.payments_outlined, 
                            color: data['metodo_pago'].toString().contains('TRANSFERENCIA') ? Colors.red[700] : Colors.blueGrey[700],
                            size: 18
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              data['metodo_pago'].toString().contains('TRANSFERENCIA') 
                                  ? "PAGO POR TRANSFERENCIA (Verificar MP)"
                                  : "PAGO EN EFECTIVO (Cobrar en puerta)",
                              style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 10, color: data['metodo_pago'].toString().contains('TRANSFERENCIA') ? Colors.red[800] : Colors.blueGrey[800]),
                            ),
                          ),
                        ],
                      ),
                    ),

                  Text("PRODUCTOS:", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey[600])),
                  const SizedBox(height: 10),
                  ...productos.map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text("• ${p['cantidad']}x ${p['nombre']}", style: GoogleFonts.montserrat(fontSize: 13)),
                  )),
                  
                  const Divider(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("TOTAL:", style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 18)),
                      Text("\$${data['total']}", style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 24, color: const Color(0xFFFF7F50))),
                    ],
                  ),
                  
                  if (data['lat_cliente'] != null) ...[
                    const SizedBox(height: 15),
                    _buildMapsButton(
                      (data['lat_cliente'] as num).toDouble(), 
                      (data['long_cliente'] as num).toDouble(),
                      isSmall: true // Usar versión pequeña en diálogos para evitar desborde
                    ),
                  ],
                  if (data['paga_con'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text("Paga con: \$${data['paga_con']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey)),
                      ),
                    ),
                  
                  const SizedBox(height: 25),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _tabController.animateTo(0);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF7F50),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 0,
                    ),
                    child: Text("VER PEDIDO", style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, letterSpacing: 1.1)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ).then((_) {
      _stopAllSounds();
      if (mounted) {
        setState(() => _isShowingDialog = false);
      }
    });
  }

  // ignore: unused_element
  Future<void> _printOrder(Map<String, dynamic> data, String id) async {
    BlueThermalPrinter bluetooth = BlueThermalPrinter.instance;
    bool? isConnected = await bluetooth.isConnected;

    if (isConnected != true) {
      List<BluetoothDevice> devices = await bluetooth.getBondedDevices();
      if (devices.isEmpty) return;
      try {
        await bluetooth.connect(devices.first);
      } catch (e) {
        return;
      }
    }

    // Diseño del Ticket
    bluetooth.printCustom("MIGUEL ANGEL", 3, 1);
    bluetooth.printCustom("--------------------------------", 1, 1);
    bluetooth.printCustom("PEDIDO: #${id.substring(id.length - 4)}", 2, 1);
    bluetooth.printCustom("CLI: ${data['nombre_cliente'] ?? 'Desconocido'}", 1, 0);
    if (data['direccion'] != null) {
      bluetooth.printCustom("DIR: ${data['direccion']}", 1, 0);
    }
    bluetooth.printCustom("TEL: ${data['cliente'] ?? '--'}", 1, 0);
    bluetooth.printCustom("--------------------------------", 1, 1);
    
    List productos = data['productos'] ?? [];
    for (var p in productos) {
      bluetooth.printCustom("${p['cantidad']}x ${p['nombre']}", 1, 0);
    }
    
    bluetooth.printCustom("--------------------------------", 1, 1);
    bluetooth.printCustom("TOTAL: \$${data['total']}", 2, 2);
    if (data['metodo_pago'] != null) {
       bluetooth.printCustom("PAGO: ${data['metodo_pago']}", 1, 0);
    }
    bluetooth.printCustom("--------------------------------", 1, 1);
    bluetooth.printNewLine();
    bluetooth.printNewLine();
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
        title: Text("Pedidos de Hoy", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.notifications_active, color: Color(0xFFFF7F50), size: 28),
            onSelected: (value) {
              if (value == 'test') {
                _playNotificationSound();
                if (_alertType == 'alarm' || _alertType == 'ringtone' || _alertType == 'custom') {
                  Future.delayed(const Duration(seconds: 5), () => _stopAllSounds());
                }
              } else if (value == 'custom_selector') {
                _showRingtonePickerDialog();
              } else {
                _saveAlertPreference(value);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'test', child: Row(children: [const Icon(Icons.play_circle_fill, size: 20, color: Colors.green), const SizedBox(width: 10), Text("Probar: ${_alertType == 'custom' ? (_selectedRingtoneTitle ?? 'Tono') : _alertType}", style: const TextStyle(fontWeight: FontWeight.bold))])),
              const PopupMenuDivider(),
              PopupMenuItem(value: 'custom_selector', child: Row(children: [const Icon(Icons.queue_music, size: 18, color: Colors.blue), const SizedBox(width: 10), const Text("ELEGIR MELODÍA...")])),
              const PopupMenuDivider(),
              PopupMenuItem(value: 'notification', child: Row(children: [Icon(Icons.message, size: 18, color: _alertType == 'notification' ? Colors.orange : null), const SizedBox(width: 10), const Text("Mensaje (Corto)")])),
              PopupMenuItem(value: 'alarm', child: Row(children: [Icon(Icons.alarm, size: 18, color: _alertType == 'alarm' ? Colors.orange : null), const SizedBox(width: 10), const Text("Alarma Sistema")])),
              PopupMenuItem(value: 'ringtone', child: Row(children: [Icon(Icons.phone_android, size: 18, color: _alertType == 'ringtone' ? Colors.orange : null), const SizedBox(width: 10), const Text("Llamada Sistema")])),
              PopupMenuItem(value: 'silent', child: Row(children: [Icon(Icons.volume_off, size: 18, color: _alertType == 'silent' ? Colors.orange : null), const SizedBox(width: 10), const Text("Silencio")])),
            ],
          ),
          if (_alertType == 'alarm' || _alertType == 'ringtone' || _alertType == 'custom') 
            IconButton(
              icon: const Icon(Icons.stop_circle, color: Colors.red, size: 30),
              onPressed: () => _stopAllSounds(),
              tooltip: "Detener Alarma",
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
          _buildOrderList('Despachado'),
          _buildOrderList('Finalizado'),
        ],
      ),
    );
  }

  Widget _buildOrderList(String estado) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('pedidos')
          .where('estado', isEqualTo: estado)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final List<QueryDocumentSnapshot> docs = snapshot.data!.docs;
        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final Timestamp? aTime = aData['createdAt'];
          final Timestamp? bTime = bData['createdAt'];
          
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return -1;
          if (bTime == null) return 1;
          
          return bTime.compareTo(aTime);
        });

        if (docs.isEmpty) {
          return Center(child: Text("Sin pedidos en $estado", style: GoogleFonts.montserrat(color: Colors.grey)));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(15),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final orderData = doc.data() as Map<String, dynamic>;
            final String orderId = doc.id;
            
            final bool isCocina = estado == 'En Preparación';
            
            final bool isModificando = estado == 'modificando';

            return Container(
              margin: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isModificando ? Colors.blueGrey[50] : Colors.white,
                borderRadius: BorderRadius.circular(15),
                border: isModificando ? Border.all(color: Colors.blueGrey, width: 2) : null,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)]
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text("${orderData['nombre_cliente'] ?? 'Cliente'} (#${orderId.substring(orderId.length - 4)})", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold))),
                        if (isModificando)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(color: Colors.blueGrey, borderRadius: BorderRadius.circular(8)),
                            child: Text("MODIFICANDO...", style: GoogleFonts.montserrat(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900)),
                          ),
                        // La impresora queda oculta para la versión celular, se usará en la versión PC próximamente
                        const Visibility(
                          visible: false,
                          child: Icon(Icons.print),
                        ),
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!isCocina) ...[
                          if (orderData['metodo_pago'] != null)
                             Padding(
                               padding: const EdgeInsets.symmetric(vertical: 4),
                               child: Text(
                                 orderData['metodo_pago'].toString().contains('TRANSFERENCIA') 
                                    ? "⚠️ TRANSFERENCIA (Verificar en MP)"
                                    : "💵 EFECTIVO (Cobrar \$${orderData['total']})",
                                 style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.blueGrey[600]),
                               ),
                             ),
                          Text("Total: \$${orderData['total']}", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          if (orderData['paga_con'] != null)
                            Text("Paga con \$${orderData['paga_con']}",
                              style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey)),
                        ],
                        
                        const SizedBox(height: 8),
                        Text("PRODUCTOS:", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 10, color: Colors.grey[700])),
                        const SizedBox(height: 4),
                        ...(orderData['productos'] as List? ?? []).map((p) => Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text("• ${p['cantidad']}x ${p['nombre']}", style: GoogleFonts.montserrat(fontSize: 11, color: Colors.black87)),
                        )),
                        
                        if (!isCocina) ...[
                          if (orderData['direccion'] != null && orderData['direccion'].toString().isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.home, size: 16, color: Colors.blueGrey),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "ENTREGA: ${orderData['direccion']}",
                                    style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blueGrey[800]),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          
                          if ((orderData['direccion'] == null || orderData['direccion'].toString().isEmpty) && 
                               orderData['lat_cliente'] == null && 
                               orderData['metodo_envio'] != 'Retiro')
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text("⚠️ Sin dirección especificada", style: TextStyle(color: Colors.red[700], fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ],
                    ),
                    trailing: _buildActionButton(orderId, estado, orderData),
                  ),
                  if (!isCocina && orderData['lat_cliente'] != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                      child: _buildMapsButton(
                        (orderData['lat_cliente'] as num).toDouble(), 
                        (orderData['long_cliente'] as num).toDouble(),
                        isSmall: false
                      ),
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
    String nextStatus = "";
    String label = "";
    Color color = Colors.orange;

    if (currentStatus == 'Pendiente') {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            onPressed: () async {
              String selectedReason = "";
              final controller = TextEditingController();

              final reason = await showDialog<String>(
                context: context,
                builder: (context) => StatefulBuilder(
                  builder: (context, setDialogState) => Dialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    clipBehavior: Clip.antiAlias,
                    child: Padding(
                      padding: const EdgeInsets.all(25),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("❌ Rechazar Pedido", style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 20, color: Colors.black)),
                          const SizedBox(height: 5),
                          Text("Por favor, elegí un motivo para notificar al cliente.", style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey[600])),
                          const SizedBox(height: 20),
                          
                          _buildModernReasonItem(
                            context, 
                            "❌ Pago no recibido", 
                            selectedReason == "Pago no recibido", 
                            () => setDialogState(() => selectedReason = "Pago no recibido")
                          ),
                          _buildModernReasonItem(
                            context, 
                            "🧀 Sin stock de ingrediente", 
                            selectedReason == "Sin stock", 
                            () => setDialogState(() => selectedReason = "Sin stock")
                          ),
                          _buildModernReasonItem(
                            context, 
                            "🛵 Fuera de zona de entrega", 
                            selectedReason == "Fuera de zona", 
                            () => setDialogState(() => selectedReason = "Fuera de zona")
                          ),
                          _buildModernReasonItem(
                            context, 
                            "📝 Otro motivo...", 
                            selectedReason == "Otro", 
                            () => setDialogState(() => selectedReason = "Otro")
                          ),

                          if (selectedReason == "Otro")
                            Padding(
                              padding: const EdgeInsets.only(top: 15),
                              child: TextField(
                                controller: controller,
                                decoration: InputDecoration(
                                  hintText: "Escribí acá el motivo...",
                                  hintStyle: GoogleFonts.montserrat(fontSize: 12),
                                  filled: true,
                                  fillColor: Colors.grey[100],
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                                ),
                                style: GoogleFonts.montserrat(fontSize: 13),
                              ),
                            ),
                          
                          const SizedBox(height: 30),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text("CANCELAR", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.grey[600])),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: selectedReason == "" ? null : () {
                                    final finalReason = selectedReason == "Otro" ? controller.text : selectedReason;
                                    if (finalReason.isNotEmpty) Navigator.pop(context, finalReason);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    disabledBackgroundColor: Colors.grey[300],
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                    padding: const EdgeInsets.symmetric(vertical: 15),
                                  ),
                                  child: Text("CONFIRMAR", style: GoogleFonts.montserrat(fontWeight: FontWeight.w900)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
              
              if (reason != null && reason.isNotEmpty) {
                FirebaseFirestore.instance.collection('pedidos').doc(id).update({
                  'estado': 'Cancelado',
                  'motivo_rechazo': reason,
                  'updatedAt': FieldValue.serverTimestamp(),
                });

                // Seguridad de Comisión: Log de cancelación con GPS
                if (data['lat_cliente'] != null) {
                  FirebaseFirestore.instance.collection('logs_cancelaciones').add({
                    'pedido_id': id,
                    'cliente': data['nombre_cliente'],
                    'lat': data['lat_cliente'],
                    'long': data['long_cliente'],
                    'motivo': reason,
                    'timestamp': FieldValue.serverTimestamp(),
                  });
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[400],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: const Text("RECHAZAR", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () async {
              if (data['metodo_pago'] != null && data['metodo_pago'].toString().contains('TRANSFERENCIA')) {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    title: Text("Confirmación", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
                    content: const Text("¿Ya verificaste el ingreso en Mercado Pago?"),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCELAR", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: Text("SÍ, EMPEZAR COCINA", style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, color: const Color(0xFFFF7F50)))),
                    ],
                  ),
                );
                if (confirm != true) return;
              }

              FirebaseFirestore.instance.collection('pedidos').doc(id).update({
                'estado': 'En Preparación',
                'updatedAt': FieldValue.serverTimestamp(),
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: const Text("ACEPTAR", style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
          ),
        ],
      );
    }

    if (currentStatus == 'En Preparación') {
      nextStatus = 'Despachado';
      label = 'LISTO';
      color = Colors.blue;
    } else if (currentStatus == 'Despachado') {
      nextStatus = 'Finalizado';
      label = 'ENTREGADO';
      color = Colors.black;
    } else {
      return const Icon(Icons.check_circle, color: Colors.green);
    }

    return ElevatedButton(
      onPressed: () async {
        FirebaseFirestore.instance.collection('pedidos').doc(id).update({
          'estado': nextStatus,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildModernReasonItem(BuildContext context, String text, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
        decoration: BoxDecoration(
          color: isSelected ? Colors.red[50] : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isSelected ? Colors.red.withOpacity(0.5) : Colors.grey.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Expanded(child: Text(text, style: GoogleFonts.montserrat(fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.red[900] : Colors.black87))),
            if (isSelected) const Icon(Icons.check_circle, color: Colors.red, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildMapsButton(double lat, double lng, {bool isSmall = false}) {
    return InkWell(
      onTap: () async {
        final url = "https://www.google.com/maps/search/?api=1&query=$lat,$lng";
        if (await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        width: double.infinity,
        margin: EdgeInsets.symmetric(vertical: isSmall ? 12 : 15),
        padding: EdgeInsets.symmetric(vertical: isSmall ? 15 : 20),
        decoration: BoxDecoration(
          color: Colors.blue[600],
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.location_on, color: Colors.white, size: isSmall ? 18 : 22),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                "VER UBICACIÓN EN EL MAPA",
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: isSmall ? 10 : 12, // Reducir un poco el tamaño
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Set<String> _processedOrders = {}; // Evitar sonar múltiples veces por el mismo pedido

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initOrderListener();
  }

  void _initOrderListener() {
    // Escuchar únicamente pedidos Pendientes para la alarma
    FirebaseFirestore.instance
        .collection('pedidos')
        .where('estado', isEqualTo: 'Pendiente')
        .snapshots()
        .listen((snapshot) {
          if (snapshot.docs.isNotEmpty) {
            for (var doc in snapshot.docs) {
              if (!_processedOrders.contains(doc.id)) {
                _processedOrders.add(doc.id);
                _playNotificationSound();
                _showNewOrderDialog(doc);
              }
            }
          }
        });
  }

  Future<void> _playNotificationSound() async {
    try {
      // Usamos un sonido de caja registradora público
      await _audioPlayer.play(UrlSource('https://www.soundjay.com/misc/sounds/cash-register-purchase-1.mp3'));
    } catch (e) {
      debugPrint("Error playing sound: $e");
    }
  }

  void _showNewOrderDialog(DocumentSnapshot doc) {
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
                      _audioPlayer.stop();
                      _tabController.animateTo(0);
                      Navigator.pop(context);
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
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _audioPlayer.dispose();
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
          
          // Los pedidos nuevos (sin timestamp de servidor aún) van ARRIBA
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
            
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)]
              ),
              child: ListTile(
                  title: Text("${orderData['nombre_cliente'] ?? 'Cliente'} (#${orderId.substring(orderId.length - 4)})", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                      Text("Total: \$${orderData['total']}", style: const TextStyle(fontSize: 12)),
                      if (orderData['paga_con'] != null)
                        Text("Paga con \$${orderData['paga_con']}",
                          style: const TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey)),
                    ],
                  ),
                  trailing: _buildActionButton(orderId, estado, orderData),
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
        if (currentStatus == 'Pendiente' && data['metodo_pago'] != null && data['metodo_pago'].toString().contains('TRANSFERENCIA')) {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text("Confirmación de Pago"),
              content: const Text("¿Ya verificaste el ingreso en Mercado Pago?"),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCELAR", style: TextStyle(color: Colors.grey))),
                TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("SÍ, EMPEZAR COCINA", style: TextStyle(fontWeight: FontWeight.bold))),
              ],
            ),
          );
          if (confirm != true) return;
        }

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
}

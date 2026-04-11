import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'client_carta_screen.dart';

class OrderStatusScreen extends StatefulWidget {
  final String orderId;

  const OrderStatusScreen({super.key, required this.orderId});

  @override
  State<OrderStatusScreen> createState() => _OrderStatusScreenState();
}

class _OrderStatusScreenState extends State<OrderStatusScreen> {

  @override
  void initState() {
    super.initState();
  }


  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('pedidos').doc(widget.orderId).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        
        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final String estado = data['estado'] ?? 'Pendiente';
        final String productosStr = (data['productos'] as List? ?? []).map((p) => p['nombre']).join(", ");

        return Scaffold(
          backgroundColor: const Color(0xFF121212), // Fondo oscuro para resaltar Glassmorphism
          body: Stack(
            children: [
              // Fondo con gradiente sutil
              Positioned.fill(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF1A1A1A), Color(0xFF000000)],
                    ),
                  ),
                ),
              ),

              SafeArea(
                child: Column(
                  children: [
                    _buildPremiumHeader(estado),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
                        child: Column(
                          children: [
                            const SizedBox(height: 10),
                            _buildGlassStatusCard(estado, productosStr),
                            const SizedBox(height: 30),
                            _buildProgressTrack(estado),
                            const SizedBox(height: 40),
                            _buildOrderSummary(data),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPremiumHeader(String estado) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(onPressed: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const ClientCartaScreen()), (route) => false), icon: const Icon(Icons.close, color: Colors.white70)),
          Text("ESTADO DE PEDIDO", style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 2, fontSize: 13)),
          const SizedBox(width: 48), // Equilibrar el botón de cierre
        ],
      ),
    );
  }

  Widget _buildGlassStatusCard(String estado, String productosStr) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(35),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          border: Border.all(color: Colors.white.withOpacity(0.15), width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(35),
          child: Column(
            children: [
              // Icono Animado / Central
              _buildLargeAnimatedIcon(estado),
              const SizedBox(height: 25),
              Text(
                _getStatusTitle(estado).toUpperCase(),
                style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 1),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                estado == 'En Preparación' 
                  ? "Ya estamos cocinando tu combo de: $productosStr. ¡Casi listo!"
                  : _getStatusDescription(estado),
                style: GoogleFonts.montserrat(color: Colors.white70, fontSize: 13, height: 1.5),
                textAlign: TextAlign.center,
              ),
              if (estado == 'Pendiente') ...[
                const SizedBox(height: 25),
                ElevatedButton.icon(
                  onPressed: () => _confirmarModificacion(context),
                  icon: const Icon(Icons.edit_note, color: Colors.white),
                  label: Text("MODIFICAR MI PEDIDO", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 12)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF7F50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _confirmarModificacion(BuildContext context) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: Text("¿Modificar pedido?", style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text("El pedido volverá al carrito para que puedas editarlo. ¿Continuar?", style: GoogleFonts.montserrat(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text("CANCELAR", style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(c);
              await FirebaseFirestore.instance.collection('pedidos').doc(widget.orderId).update({'estado': 'modificando'});
              if (mounted) {
                Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const ClientCartaScreen()), (route) => false);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF7F50)),
            child: const Text("SÍ, MODIFICAR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildLargeAnimatedIcon(String estado) {
    IconData icon = Icons.timer_outlined;
    if (estado == 'En Preparación') icon = Icons.local_pizza;
    if (estado == 'listo_para_despacho') icon = Icons.outdoor_grill;
    if (estado == 'Despachado') icon = Icons.delivery_dining;
    if (estado == 'Finalizado') icon = Icons.verified;
    if (estado == 'Cancelado') icon = Icons.cancel;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(seconds: 2),
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.9 + (0.1 * value),
          child: Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFF7F50).withOpacity(0.15 * value),
              boxShadow: [
                BoxShadow(color: const Color(0xFFFF7F50).withOpacity(0.1), blurRadius: 30, spreadRadius: 10),
              ],
            ),
            child: Icon(icon, size: 70, color: const Color(0xFFFF7F50)),
          ),
        );
      },
    );
  }

  Widget _buildProgressTrack(String estado) {
    int activeStep = 0;
    if (estado == 'En Preparación' || estado == 'listo_para_despacho') activeStep = 1;
    if (estado == 'Despachado' || estado == 'Finalizado') activeStep = 2;

    return Row(
      children: [
        _buildStepIndicator("Confirmado", activeStep >= 0, true),
        _buildStepLine(activeStep >= 1),
        _buildStepIndicator("Cocinando", activeStep >= 1, false),
        _buildStepLine(activeStep >= 2),
        _buildStepIndicator("En Camino", activeStep >= 2, false),
      ],
    );
  }

  Widget _buildStepIndicator(String label, bool isDone, bool isFirst) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDone ? const Color(0xFFFF7F50) : Colors.white12,
              border: Border.all(color: isDone ? Colors.white : Colors.transparent, width: 2),
            ),
            child: isDone ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
          ),
          const SizedBox(height: 10),
          Text(label, style: GoogleFonts.montserrat(color: isDone ? Colors.white : Colors.white38, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildStepLine(bool isDone) {
    return Container(
      width: 40, height: 3,
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isDone ? const Color(0xFFFF7F50) : Colors.white12,
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  String _getStatusTitle(String estado) {
    if (estado == 'Pendiente') return "Esperando local...";
    if (estado == 'En Preparación') return "¡Ya lo estamos preparando!";
    if (estado == 'listo_para_despacho') return "¡Casi listo!";
    if (estado == 'Despachado') return "¡En Camino!";
    if (estado == 'Cancelado') return "Pedido Cancelado";
    if (estado == 'Finalizado') return "¡Entregado!";
    return "PROCESANDO...";
  }

  String _getStatusDescription(String estado) {
    if (estado == 'Pendiente') return "Gonzalo está revisando tu pedido. ¡Casi empezamos!";
    if (estado == 'En Preparación') return "Gonzalo ya está manos a la obra con tu pedido. ¡Falta muy poco!";
    if (estado == 'listo_para_despacho') return "Tu pedido ya salió del horno y espera al repartidor.";
    if (estado == 'Despachado') return "¡Todo listo! Tené tu mesa preparada, nosotros nos encargamos del resto.";
    if (estado == 'Finalizado') return "¡Que lo disfrutes mucho! Gracias por elegirnos.";
    if (estado == 'Cancelado') return "Lamentablemente el local no pudo tomar tu pedido. Contactanos por WhatsApp.";
    return "Seguimiento en tiempo real activado.";
  }

  Widget _buildOrderSummary(Map<String, dynamic> data) {
    final String id = widget.orderId;
    final String shortId = id.length > 5 ? id.substring(id.length - 5).toUpperCase() : id;
    final List productos = data['productos'] as List? ?? [];
    
    // Filtramos para mostrar solo los items principales (que tienen precio > 0)
    final itemsPrincipales = productos.where((p) => (p['precio'] ?? 0) > 0).toList();

    return Container(
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05), 
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.white.withOpacity(0.1))
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("ORDEN #$shortId", style: GoogleFonts.montserrat(color: Colors.white38, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 1.5)),
              Text(data['metodo_pago']?.toUpperCase() ?? 'EFECTIVO', style: GoogleFonts.montserrat(color: const Color(0xFF00B1EA), fontWeight: FontWeight.w900, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 20),
          
          // Resumen simple de productos (solo principales)
          ...itemsPrincipales.map((p) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white24, size: 14),
                const SizedBox(width: 8),
                Text("${p['cantidad']}x ${p['nombre']}", style: GoogleFonts.montserrat(color: Colors.white.withOpacity(0.85), fontSize: 13, fontWeight: FontWeight.w500)),
              ],
            ),
          )),
          
          const Divider(color: Colors.white10, height: 40),
          
          _buildPaymentSummaryRow("TOTAL A PAGAR", "\$${data['total']?.toString() ?? '0'}", isTotal: true),
          
          if (data['metodo_pago'] == 'Efectivo' && data['paga_con'] != null) ...[
            const SizedBox(height: 12),
            _buildPaymentSummaryRow("ABONA CON", "\$${data['paga_con']}"),
          ],

          const SizedBox(height: 25),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.03), borderRadius: BorderRadius.circular(15)),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: Color(0xFFFF7F50), size: 16),
                const SizedBox(width: 10),
                Expanded(child: Text(data['direccion_entrega'] ?? 'GPS Capturado', style: GoogleFonts.montserrat(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentSummaryRow(String label, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.montserrat(color: Colors.white38, fontSize: 12, fontWeight: FontWeight.bold)),
        Text(value, style: GoogleFonts.montserrat(color: isTotal ? const Color(0xFFFF7F50) : Colors.white, fontSize: isTotal ? 16 : 13, fontWeight: FontWeight.w900)),
      ],
    );
  }

}

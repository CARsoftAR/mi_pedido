import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'client_carta_screen.dart';

class OrderStatusScreen extends StatefulWidget {
  final String orderId;

  const OrderStatusScreen({super.key, required this.orderId});

  @override
  State<OrderStatusScreen> createState() => _OrderStatusScreenState();
}

class _OrderStatusScreenState extends State<OrderStatusScreen> {
  bool _rejectionDialogShown = false;

  @override
  void initState() {
    super.initState();
    _rejectionDialogShown = false;
  }

  void _showRejectionAlert(BuildContext context, String motivo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25), 
          side: const BorderSide(color: Colors.redAccent, width: 2)
        ),
        title: Text("❌ PEDIDO RECHAZADO", style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, color: Colors.redAccent)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("Lo sentimos, tu pedido fue rechazado por el local.", style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
              child: Text("MOTIVO: ${motivo.isEmpty ? 'Sin motivo especificado' : motivo}", style: GoogleFonts.montserrat(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context), 
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            child: Text("ENTENDIDO", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.white))
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('pedidos').doc(widget.orderId).snapshots(includeMetadataChanges: true),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFFFF7F50))));
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          if (snapshot.connectionState == ConnectionState.active && snapshot.data != null) {
            SharedPreferences.getInstance().then((p) => p.remove('lastOrderId'));
          }
          return const Scaffold(body: Center(child: Text("Cargando seguimiento...", style: TextStyle(color: Colors.white54))));
        }
        
        final orderData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final String estadoActual = orderData['estado'] ?? 'Pendiente';
        final List productosList = orderData['productos'] as List? ?? [];
        final String pNombres = productosList.map((p) => p['nombre']).join(", ");
        final String motivoRechazo = orderData['motivo_rechazo'] ?? orderData['motivo'] ?? '';

        if ((estadoActual == 'rechazado' || estadoActual == 'Cancelado') && !_rejectionDialogShown) {
          _rejectionDialogShown = true;
          debugPrint("ALERTA: DISPARANDO DIÁLOGO DE RECHAZO PARA ESTADO: $estadoActual");
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _showRejectionAlert(context, motivoRechazo);
            }
          });
        }

        return Scaffold(
          backgroundColor: const Color(0xFF121212),
          body: Stack(
            children: [
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
                    _buildPremiumHeader(estadoActual),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 20),
                        child: Column(
                          children: [
                            const SizedBox(height: 10),
                            _buildGlassStatusCard(estadoActual, pNombres, motivoRechazo),
                             const SizedBox(height: 30),
                             if (estadoActual != 'rechazado' && estadoActual != 'Cancelado') ...[
                               _buildProgressTrack(estadoActual),
                               const SizedBox(height: 40),
                             ] else ...[
                               const SizedBox(height: 20),
                               Container(
                                 width: double.infinity,
                                 padding: const EdgeInsets.all(20),
                                 decoration: BoxDecoration(
                                   color: Colors.redAccent.withOpacity(0.1),
                                   borderRadius: BorderRadius.circular(20),
                                   border: Border.all(color: Colors.redAccent.withOpacity(0.3))
                                 ),
                                 child: Column(
                                   children: [
                                     const Icon(Icons.error_outline, color: Colors.redAccent, size: 40),
                                     const SizedBox(height: 10),
                                     Text(
                                       "ESTE PEDIDO FUE CANCELADO",
                                       style: GoogleFonts.montserrat(color: Colors.redAccent, fontWeight: FontWeight.w900, fontSize: 14),
                                     ),
                                   ],
                                 ),
                               ),
                               const SizedBox(height: 30),
                             ],
                            _buildOrderSummary(orderData),
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
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  Widget _buildGlassStatusCard(String estado, String productosStr, String motivo) {
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
              _buildLargeAnimatedIcon(estado),
              const SizedBox(height: 25),
              Text(
                _getStatusTitle(estado).toUpperCase(),
                style: GoogleFonts.montserrat(
                  color: (estado == 'Cancelado' || estado == 'rechazado') ? Colors.redAccent : Colors.white, 
                  fontWeight: FontWeight.w900, 
                  fontSize: 20, 
                  letterSpacing: 1
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              
              if ((estado == 'Cancelado' || estado == 'rechazado') && motivo.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(15)),
                  child: Text(
                    "MOTIVO: $motivo",
                    style: GoogleFonts.montserrat(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 15),
              ],

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
              if (estado == 'Finalizado' || estado == 'rechazado' || estado == 'Cancelado') ...[
                const SizedBox(height: 25),
                ElevatedButton.icon(
                  onPressed: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('lastOrderId');
                    await prefs.remove('notifiedStatus');
                    if (context.mounted) {
                      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const ClientCartaScreen()), (route) => false);
                    }
                  },
                  icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                  label: Text("FINALIZAR Y VOLVER", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[600],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 5,
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
    if (estado == 'Cancelado' || estado == 'rechazado') icon = Icons.cancel;

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
    if (estado == 'rechazado' || estado == 'Cancelado') {
      return const SizedBox.shrink();
    }
    
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
    if (estado == 'rechazado' || estado == 'Cancelado') return "Pedido Rechazado ❌";
    if (estado == 'Finalizado') return "¡Entregado!";
    return "PROCESANDO...";
  }

  String _getStatusDescription(String estado) {
    if (estado == 'Pendiente') return "Gonzalo está revisando tu pedido. ¡Casi empezamos!";
    if (estado == 'En Preparación') return "Gonzalo ya está manos a la obra con tu pedido. ¡Falta muy poco!";
    if (estado == 'listo_para_despacho') return "Tu pedido ya salió del horno y espera al repartidor.";
    if (estado == 'Despachado') return "¡Todo listo! Tené tu mesa preparada, nosotros nos encargamos del resto.";
    if (estado == 'Finalizado') return "¡Que lo disfrutes mucho! Gracias por elegirnos.";
    if (estado == 'rechazado' || estado == 'Cancelado') return "Lo sentimos, el local no pudo tomar tu pedido en este momento.";
    return "Seguimiento en tiempo real activado.";
  }

  Widget _buildOrderSummary(Map<String, dynamic> data) {
    final String id = widget.orderId;
    final String shortId = id.length > 5 ? id.substring(id.length - 5).toUpperCase() : id;
    final List productos = data['productos'] as List? ?? [];
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
          _buildPaymentSummaryRow("TOTAL A PAGAR", _formatMoney(data['total'] ?? 0), isTotal: true),
          if (data['metodo_pago'] == 'Efectivo' && data['paga_con'] != null) ...[
            const SizedBox(height: 12),
            _buildPaymentSummaryRow("ABONA CON", _formatMoney(data['paga_con'])),
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

  String _formatMoney(dynamic value) {
    if (value == null) return "\$0,00";
    double price = (value is num) ? value.toDouble() : (double.tryParse(value.toString().replaceAll(',', '.')) ?? 0.0);
    return "\$${price.toStringAsFixed(2).replaceAll('.', ',')}";
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

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OrderStatusScreen extends StatefulWidget {
  final String orderId;

  const OrderStatusScreen({super.key, required this.orderId});

  @override
  State<OrderStatusScreen> createState() => _OrderStatusScreenState();
}

class _OrderStatusScreenState extends State<OrderStatusScreen> {
  int _minutosLimite = 5;
  late Stream<int> _timerStream;

  @override
  void initState() {
    super.initState();
    _fetchLimit();
    _timerStream = Stream.periodic(const Duration(seconds: 1), (i) => i);
  }

  void _fetchLimit() async {
    final doc = await FirebaseFirestore.instance.collection('config').doc('tiempos').get();
    if (doc.exists) {
      setState(() {
        _minutosLimite = doc.data()?['minutos_edicion'] ?? 5;
      });
    }
  }

  void _iniciarEdicion(Map<String, dynamic> data) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "¿Modificar este Pedido?", 
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: const Color(0xFF2D2D2D))
        ),
        content: Text(
          "Tus productos actuales se cargarán de nuevo en la bolsa para que puedas editarlos. El pedido seguirá vigente en el comercio como 'Modificando'.",
          style: GoogleFonts.montserrat(color: Colors.grey[700], fontSize: 14)
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text("VOLVER", style: GoogleFonts.montserrat(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF7F50),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text("EDITAR AHORA", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // 1. Cambiamos el estado a 'modificando' en Firestore
      await FirebaseFirestore.instance.collection('pedidos').doc(widget.orderId).update({
        'estado': 'modificando'
      });
      
      if (mounted) {
        // 2. Limpiamos navegación y vamos a la carta de forma directa
        Navigator.pushNamedAndRemoveUntil(context, '/carta', (route) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('pedidos').doc(widget.orderId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Scaffold(body: Center(child: Text("Error: ${snapshot.error}")));
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            appBar: AppBar(title: const Text("Pedido")),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.search_off, size: 50, color: Colors.grey),
                  const SizedBox(height: 20),
                  const Text("No pudimos encontrar el estado de tu pedido."),
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text("VOLVER AL MENÚ")),
                ],
              ),
            ),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final String estado = data['estado'] ?? 'Pendiente';
        final String? motivoRechazo = data['motivo_rechazo'];
        final Timestamp? createdAt = data['createdAt'];

        int minutosRestantes = 0;
        bool canEdit = false;
        if (estado == 'Pendiente' || estado == 'En Preparación' || estado == 'modificando') {
          if (createdAt == null) {
            canEdit = true;
            minutosRestantes = _minutosLimite;
          } else {
            final diff = DateTime.now().difference(createdAt.toDate()).inMinutes;
            minutosRestantes = _minutosLimite - diff;
            if (minutosRestantes > 0) {
              canEdit = true;
            } else {
              minutosRestantes = 0;
            }
          }
        }

        final bool isFinished = estado == 'Finalizado' || estado == 'Cancelado';
        final bool canGoBack = isFinished || estado == 'modificando';

        return PopScope(
          canPop: canGoBack,
          onPopInvoked: (didPop) {
            if (didPop) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Tu pedido está en curso. No podés volver al menú ahora.")),
            );
          },
          child: Scaffold(
            backgroundColor: Colors.white,
            appBar: AppBar(
              title: Text("Estado de tu Pedido", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 18)),
              centerTitle: true,
              backgroundColor: Colors.white,
              elevation: 0,
              foregroundColor: Colors.black,
              automaticallyImplyLeading: isFinished,
            ),
            body: Column(
              children: [
                if (canEdit && estado != 'modificando')
                  _buildTimerBanner(minutosRestantes),
                
                if (estado == 'Cancelado')
                  _buildStatusBanner(
                    "Tu pedido fue rechazado",
                    "Motivo: ${motivoRechazo ?? 'No especificado'}",
                    Colors.red,
                    Icons.cancel,
                  )
                else if (estado == 'En Preparación')
                  _buildStatusBanner(
                    "¡Pedido Aceptado!",
                    "Ya estamos preparando tu pizza",
                    Colors.green,
                    Icons.check_circle,
                  )
                else if (estado == 'Despachado')
                  _buildStatusBanner(
                    "¡Pedido en Camino!",
                    "El repartidor está yendo a tu domicilio",
                    Colors.blue,
                    Icons.delivery_dining,
                  )
                else if (estado == 'Finalizado')
                  _buildStatusBanner(
                    "¡Pedido Entregado!",
                    "¡Que disfrutes tu comida!",
                    Colors.black,
                    Icons.verified,
                  ),

                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildStatusIcon(estado),
                          const SizedBox(height: 30),
                          Text(
                            _getStatusTitle(estado),
                            style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 24, color: _getStatusColor(estado)),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 10),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: Text(
                              _getStatusDescription(estado),
                              style: GoogleFonts.montserrat(fontSize: 14, color: Colors.grey[600]),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                if (canEdit)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
                    child: ElevatedButton.icon(
                      onPressed: estado == 'modificando' ? null : () => _iniciarEdicion(data),
                      icon: Icon(estado == 'modificando' ? Icons.sync : Icons.edit, color: Colors.white),
                      label: Text(estado == 'modificando' ? "ESTÁS EDITANDO..." : "MODIFICAR MI PEDIDO"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: estado == 'modificando' ? Colors.grey : Colors.orange[800],
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      ),
                    ),
                  ),
                
                if (isFinished)
                  Padding(
                    padding: const EdgeInsets.only(left: 25, right: 25, bottom: 10),
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("VOLVER AL MENÚ", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                    ),
                  ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 25),
                  child: TextButton(
                    onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.remove('editingOrderId'); // <<< IMPORTANTE: Para que el nuevo pedido sea NUEVO
                      if (context.mounted) {
                        Navigator.pushNamedAndRemoveUntil(context, '/carta', (route) => false);
                      }
                    },
                    child: Text(
                      "VER EL MENÚ", 
                      style: GoogleFonts.montserrat(color: Colors.grey[600], fontWeight: FontWeight.bold, decoration: TextDecoration.underline)
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 25),
                  child: Text(
                    "Orden: #${widget.orderId.length > 6 ? widget.orderId.substring(widget.orderId.length - 6).toUpperCase() : widget.orderId.toUpperCase()}",
                    style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTimerBanner(int minutos) {
    return StreamBuilder<int>(
      stream: _timerStream,
      builder: (context, _) {
        return Container(
          width: double.infinity,
          color: Colors.amber[700],
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Center(
            child: Text(
              "Podés editar tu pedido durante los próximos $minutos minutos ⏳",
              style: GoogleFonts.montserrat(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    );
  }

  Widget _buildStatusBanner(String title, String subtitle, Color color, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border(bottom: BorderSide(color: color.withOpacity(0.2))),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 30),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
                Text(subtitle, style: GoogleFonts.montserrat(fontSize: 13, color: color.withOpacity(0.8))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(String estado) {
    IconData icon = Icons.timer_outlined;
    Color color = Colors.orange;

    if (estado == 'En Preparación') {
      icon = Icons.local_pizza_outlined;
      color = Colors.green;
    } else if (estado == 'Despachado') {
      icon = Icons.delivery_dining_outlined;
      color = Colors.blue;
    } else if (estado == 'Cancelado') {
      icon = Icons.error_outline;
      color = Colors.red;
    } else if (estado == 'Finalizado') {
      icon = Icons.verified_outlined;
      color = Colors.black;
    }

    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
      child: Icon(icon, size: 80, color: color),
    );
  }

  String _getStatusTitle(String estado) {
    switch (estado) {
      case 'Pendiente': return "ESPERANDO CONFIRMACIÓN";
      case 'En Preparación': return "EN LA COCINA";
      case 'Despachado': return "EN CAMINO";
      case 'Cancelado': return "PEDIDO CANCELADO";
      case 'Finalizado': return "ENTREGADO";
      default: return estado.toUpperCase();
    }
  }

  String _getStatusDescription(String estado) {
    switch (estado) {
      case 'Pendiente': return "Estamos esperando que Gonzalo revise tu pedido. ¡No cierres la app!";
      case 'modificando': return "Estás editando tu pedido. ¡No olvides enviar los cambios!";
      case 'En Preparación': return "¡Buenas noticias! Tu pizza ya está en el horno.";
      case 'Despachado': return "Prepará el efectivo o tené la app lista, tu pedido está llegando.";
      case 'Cancelado': return "Lo sentimos mucho. Revisá el motivo arriba o contactanos por WhatsApp.";
      case 'Finalizado': return "¡Esperamos que lo disfrutes!";
      default: return "";
    }
  }

  Color _getStatusColor(String estado) {
    switch (estado) {
      case 'Pendiente': return Colors.orange;
      case 'modificando': return Colors.blueGrey;
      case 'En Preparación': return Colors.green;
      case 'Despachado': return Colors.blue;
      case 'Cancelado': return Colors.red;
      case 'Finalizado': return Colors.black;
      default: return Colors.orange;
    }
  }
}

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class OrderStatusScreen extends StatelessWidget {
  final String orderId;

  const OrderStatusScreen({super.key, required this.orderId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Estado de tu Pedido", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('pedidos').doc(orderId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
          if (!snapshot.hasData || !snapshot.data!.exists) return const Center(child: CircularProgressIndicator());

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final String estado = data['estado'] ?? 'Pendiente';
          final String? motivoRechazo = data['motivo_rechazo'];

          return Column(
            children: [
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
              
              Padding(
                padding: const EdgeInsets.all(25),
                child: Text(
                  "Orden: #${orderId.substring(orderId.length - 6).toUpperCase()}",
                  style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
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
      case 'En Preparación': return Colors.green;
      case 'Despachado': return Colors.blue;
      case 'Cancelado': return Colors.red;
      case 'Finalizado': return Colors.black;
      default: return Colors.orange;
    }
  }
}

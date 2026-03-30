import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'order_status_screen.dart';

class CartSummaryScreen extends StatefulWidget {
  final Map<String, int> carrito;
  final Map<String, dynamic> preciosConfig;
  final List<DocumentSnapshot> allProducts;

  const CartSummaryScreen({
    super.key,
    required this.carrito,
    required this.preciosConfig,
    required this.allProducts,
  });

  @override
  State<CartSummaryScreen> createState() => _CartSummaryScreenState();
}

class _CartSummaryScreenState extends State<CartSummaryScreen> {
  bool _isSending = false;
  String _metodoPago = 'Efectivo'; // 'Efectivo' o 'Transferencia'
  final TextEditingController _pagaConController = TextEditingController();

  double _getRawPrice(Map<String, dynamic> prod) {
    if (prod['categoria'] == 'Empanada') {
      final key = (prod['is_especial'] ?? false) ? 'unidad_especial' : 'unidad_comun';
      final val = widget.preciosConfig[key];
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val.replaceAll(',', '.')) ?? 0;
      return 0;
    }
    final p = prod['precio'];
    if (p is num) return p.toDouble();
    if (p is String) return double.tryParse(p.replaceAll(',', '.')) ?? 0;
    return 0;
  }

  String _formatMoney(double price) {
    return "\$${price.toStringAsFixed(2).replaceAll('.', ',')}";
  }

  Future<void> _enviarPedido(double total, List<Map<String, dynamic>> productos) async {
    setState(() => _isSending = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final String userPhone = prefs.getString('userPhone') ?? 'Desconocido';
      final String userName = prefs.getString('userName') ?? 'Cliente';

      String finalMetodo = _metodoPago;
      if (_metodoPago == 'Transferencia') {
        finalMetodo = 'TRANSFERENCIA - VERIFICAR EN MP';
      }

      final docRef = await FirebaseFirestore.instance.collection('pedidos').add({
        'cliente': userPhone,
        'nombre_cliente': userName,
        'productos': productos,
        'total': total,
        'estado': 'Pendiente',
        'metodo_pago': finalMetodo,
        'paga_con': _metodoPago == 'Efectivo' ? (double.tryParse(_pagaConController.text) ?? total) : null,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Guardar último ID para el listener global
      await prefs.setString('lastOrderId', docRef.id);
      await prefs.setBool('lastOrderNotified', false);
      await prefs.setString('notifiedStatus', 'Pendiente');

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => OrderStatusScreen(orderId: docRef.id)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al enviar: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    double subtotal = 0;
    final List<Widget> itemsWidgets = [];
    final List<Map<String, dynamic>> productosData = [];

    widget.carrito.forEach((id, qty) {
      final doc = widget.allProducts.firstWhere((element) => element.id == id);
      final data = doc.data() as Map<String, dynamic>;
      final price = _getRawPrice(data);
      final itemTotal = price * qty;
      subtotal += itemTotal;

      productosData.add({
        'nombre': data['nombre'],
        'cantidad': qty,
        'precio_unitario': price,
      });

      itemsWidgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Text("${qty}x", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: const Color(0xFFFF7F50))),
              const SizedBox(width: 10),
              Expanded(child: Text(data['nombre'], style: GoogleFonts.montserrat(fontSize: 14))),
              Text(_formatMoney(itemTotal), style: GoogleFonts.montserrat(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
    });

    const double envio = 3000;
    final double total = subtotal + envio;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text("Resumen de Pedido", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(25),
              children: [
                ...itemsWidgets,
                const Divider(height: 30),
                _buildTotalLine("Subtotal", _formatMoney(subtotal)),
                _buildTotalLine("Envío", _formatMoney(envio)),
                _buildTotalLine("TOTAL", _formatMoney(total), isBold: true, fontSize: 18, color: const Color(0xFFFF7F50)),
                const SizedBox(height: 30),
                
                Text("MÉTODO DE PAGO", style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 15),
                Row(
                  children: [
                    _buildPaymentOption('Efectivo', Icons.payments_outlined),
                    const SizedBox(width: 15),
                    _buildPaymentOption('Transferencia', Icons.account_balance_outlined),
                  ],
                ),
                
                const SizedBox(height: 20),
                if (_metodoPago == 'Efectivo')
                  TextField(
                    controller: _pagaConController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: "¿Con cuánto pagás?",
                      prefixIcon: const Icon(Icons.attach_money),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                      filled: true, fillColor: Colors.grey[50],
                    ),
                  )
                else
                  _buildTransferSection(),
                  
                const SizedBox(height: 20),
              ],
            ),
          ),
          
          Container(
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))]),
            child: ElevatedButton(
              onPressed: _isSending ? null : () => _enviarPedido(total, productosData),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF7F50),
                minimumSize: const Size(double.infinity, 60),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              child: _isSending 
                ? const CircularProgressIndicator(color: Colors.white)
                : Text("ENVIAR PEDIDO", style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentOption(String value, IconData icon) {
    bool isSelected = _metodoPago == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _metodoPago = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFF7F50).withOpacity(0.1) : Colors.grey[50],
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: isSelected ? const Color(0xFFFF7F50) : Colors.transparent, width: 2),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? const Color(0xFFFF7F50) : Colors.grey),
              const SizedBox(height: 5),
              Text(value, style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 12, color: isSelected ? const Color(0xFFFF7F50) : Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransferSection() {
    final alias = widget.preciosConfig['alias_mp'] ?? 'PIZZERIA.GONZALO.MP';
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.blueGrey[50], borderRadius: BorderRadius.circular(15)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Pagá a este Alias:", style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                  child: Text(alias, style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.blueGrey[800])),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: alias));
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Alias copiado al portapapeles")));
                },
                style: IconButton.styleFrom(backgroundColor: const Color(0xFFFF7F50), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                icon: const Icon(Icons.copy, size: 20),
              )
            ],
          ),
          const SizedBox(height: 10),
          Text("Abrí Mercado Pago, pegá el Alias y realizá el envío.", style: GoogleFonts.montserrat(fontSize: 10, color: Colors.blueGrey[600], fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  Widget _buildTotalLine(String label, String value, {bool isBold = false, double fontSize = 14, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.montserrat(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.w500, color: color)),
          Text(value, style: GoogleFonts.montserrat(fontSize: fontSize, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

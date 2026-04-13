import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'order_status_screen.dart';
import 'package:geolocator/geolocator.dart';

class CartSummaryScreen extends StatefulWidget {
  final Map<String, int> carrito;
  final Map<String, dynamic> preciosConfig;
  final List<DocumentSnapshot> allProducts;
  final VoidCallback onOrderSent;

  const CartSummaryScreen({
    super.key,
    required this.carrito,
    required this.preciosConfig,
    required this.allProducts,
    required this.onOrderSent,
  });

  @override
  State<CartSummaryScreen> createState() => _CartSummaryScreenState();
}

class _CartSummaryScreenState extends State<CartSummaryScreen> {
  bool _isSending = false;
  String _metodoPago = 'Efectivo';
  String _metodoEnvio = 'Barrio'; // Barrio, Villa, Retiro
  final TextEditingController _pagaConController = TextEditingController();
  
  String _whatsappComercio = "";
  final TextEditingController _whatsappManualController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  bool _isEditingWhatsApp = false;
  double? _latCliente;
  double? _longCliente;
  bool _isCapturingLocation = false;

  @override
  void initState() {
    super.initState();
    _fetchWhatsAppNegocio();
    _loadShippingPreference();
    _pagaConController.addListener(() {
      setState(() {}); // Actualizar vuelto en tiempo real
    });
  }

  @override
  void dispose() {
    _pagaConController.dispose();
    _whatsappManualController.dispose();
    super.dispose();
  }

  void _loadShippingPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final String? saved = prefs.getString('lastShippingMethod');
    if (saved != null) {
      setState(() {
        _metodoEnvio = saved;
      });
    }
  }

  void _fetchWhatsAppNegocio() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('configuracion_negocio').doc('contacto').get();
      if (doc.exists) {
        setState(() {
          _whatsappComercio = doc.data()?['whatsapp_comprobantes'] ?? "";
          _whatsappManualController.text = _whatsappComercio;
        });
      }
    } catch (e) {
      debugPrint("Error fetching WhatsApp: $e");
    }
  }

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
      if (_metodoEnvio != 'Retiro' && _latCliente == null && _addressController.text.trim().isEmpty) {
        throw "Por favor, captura tu ubicación con el botón GPS o escribe tu dirección para que el repartidor pueda llegar.";
      }

      final prefs = await SharedPreferences.getInstance();
      final String userPhone = prefs.getString('userPhone') ?? 'Desconocido';
      final String userName = prefs.getString('userName') ?? 'Cliente';
      final String habitualAddress = prefs.getString('userAddress') ?? 'No configurada';
      
      String finalDireccion = _addressController.text.trim();
      if (finalDireccion.isEmpty) {
        finalDireccion = habitualAddress;
      }

      String finalMetodo = _metodoPago;
      if (_metodoPago == 'Transferencia') {
        finalMetodo = 'TRANSFERENCIA - VERIFICAR EN MP';
      }

      double totalProductos = 0;
      for (var p in productos) {
        totalProductos += (p['precio_unitario'] as double) * (p['cantidad'] as int);
      }

      double envioSeleccionado = 0;
      if (_metodoEnvio == 'Barrio') envioSeleccionado = (widget.preciosConfig['v_envio_barrio'] ?? 0).toDouble();
      if (_metodoEnvio == 'Villa') envioSeleccionado = (widget.preciosConfig['precio_delivery'] ?? 0).toDouble();
      if (_metodoEnvio == 'Retiro') envioSeleccionado = (widget.preciosConfig['v_envio_retiro'] ?? 0).toDouble();

      // RE-VERIFICAR DISPONIBILIDAD ANTES DE ENVIAR (Seguridad Gonzalo)
      for (var p in productos) {
        final prodId = p['id']; // Usar el ID que guardamos
        final freshDoc = await FirebaseFirestore.instance.collection('productos').doc(prodId).get();
        if (freshDoc.exists && freshDoc.data()?['disponible'] == false) {
          throw "Lo sentimos, el producto '${p['nombre']}' se acaba de agotar. Por favor, revisá tu pedido.";
        }
      }

      final String? editingOrderId = prefs.getString('editingOrderId');
      DocumentReference docRef;

      final Map<String, dynamic> pedidoData = {
        'cliente': userPhone,
        'nombre_cliente': userName,
        'productos': productos,
        'subtotal': totalProductos,
        'costo_envio': envioSeleccionado,
        'total': total,
        'metodo_envio': _metodoEnvio,
        'estado': 'Pendiente', // Volvemos a Pendiente al terminar
        'metodo_pago': finalMetodo,
        'paga_con': _metodoPago == 'Efectivo' ? (double.tryParse(_pagaConController.text) ?? total) : null,
        'direccion': finalDireccion,
        'lat_cliente': _latCliente,
        'long_cliente': _longCliente,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (editingOrderId != null) {
        // ACTUALIZAMOS EL EXISTENTE
        docRef = FirebaseFirestore.instance.collection('pedidos').doc(editingOrderId);
        await docRef.update(pedidoData);
        await prefs.remove('editingOrderId'); // Limpiamos para la próxima
      } else {
        // CREAMOS NUEVO
        pedidoData['createdAt'] = FieldValue.serverTimestamp();
        docRef = await FirebaseFirestore.instance.collection('pedidos').add(pedidoData);
      }

      // --- MAGIA: GENERACIÓN DE TICKET PREMIUM ---
      String productDetail = "";
      for (var p in productos) {
        productDetail += "• ${p['cantidad']}x ${p['nombre']}\n";
      }

      final String orderIdShort = docRef.id.length > 4 ? docRef.id.substring(docRef.id.length - 4).toUpperCase() : docRef.id.toUpperCase();
      
      String locationLink = "";
      if (_latCliente != null && _longCliente != null) {
        locationLink = "\n\n🗺️ *VER EN MAPA:*\nhttps://www.google.com/maps/search/?api=1&query=$_latCliente,$_longCliente";
      }

      String cashInfo = "";
      if (_metodoPago == 'Efectivo') {
        double pagaCon = double.tryParse(_pagaConController.text.replaceAll(',', '.')) ?? total;
        double vuelto = pagaCon > total ? pagaCon - total : 0;
        cashInfo = "\n👉 *Paga con:* \$${pagaCon.toStringAsFixed(2).replaceAll('.', ',')}" +
                  (vuelto > 0 ? "\n💰 *Vuelto:* \$${vuelto.toStringAsFixed(2).replaceAll('.', ',')}" : "");
      }

      final String ticketMagico = 
          "🍕 *NUEVO PEDIDO - #$orderIdShort* 🍕\n" +
          "━━━━━━━━━━━━━━━━\n" +
          "👤 *Cliente:* $userName\n" +
          "🏠 *Dirección:* $finalDireccion\n" +
          "📍 *Entrega:* $_metodoEnvio\n" +
          "━━━━━━━━━━━━━━━━\n" +
          "📝 *DETALLE:*\n$productDetail" +
          "━━━━━━━━━━━━━━━━\n" +
          "💵 *PAGO:* $finalMetodo$cashInfo\n\n" +
          "🚚 *ENVÍO:* \$${envioSeleccionado.toStringAsFixed(2).replaceAll('.', ',')}\n" +
          "⭐ *TOTAL: \$${total.toStringAsFixed(2).replaceAll('.', ',')}*\n" +
          "━━━━━━━━━━━━━━━━$locationLink\n\n" +
          "✅ *¡Muchas gracias por elegirnos!*";

      String rawWhatsApp = _whatsappManualController.text.trim();
      if (rawWhatsApp.isEmpty) rawWhatsApp = "5491156651458"; 

      String finalWhatsApp = rawWhatsApp.replaceAll(RegExp(r'[^0-9]'), '');
      if (finalWhatsApp.length == 10 && !finalWhatsApp.startsWith('549')) {
        finalWhatsApp = '549' + finalWhatsApp;
      }
      
      final url = "https://wa.me/$finalWhatsApp?text=${Uri.encodeComponent(ticketMagico)}";
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }

      // Guardar último ID para el listener global
      await prefs.setString('lastOrderId', docRef.id);
      await prefs.setBool('lastOrderNotified', false);
      await prefs.setString('notifiedStatus', 'Pendiente');

      // VACIAR CARRITO PARA QUE AL VOLVER ESTÉ LIMPIO
      widget.onOrderSent();
      widget.carrito.clear();

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

    final List<String> removidos = [];
    widget.carrito.forEach((id, qty) {
      final doc = widget.allProducts.firstWhere((element) => element.id == id);
      final data = doc.data() as Map<String, dynamic>;
      
      if (data['disponible'] == false) {
        removidos.add(id);
        return;
      }

      final price = _getRawPrice(data);
      final itemTotal = price * qty;
      subtotal += itemTotal;

      productosData.add({
        'id': id, // Guardar el ID real para poder restaurar el carrito si edita
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

    // Limpiar ítems agotados automáticamente
    if (removidos.isNotEmpty && !_isSending) {
      Future.delayed(Duration.zero, () {
        for (var id in removidos) widget.carrito.remove(id);
        if (mounted) setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("⚠️ Algunos productos se agotaron y fueron quitados de la bolsa."), backgroundColor: Colors.orange),
        );
      });
    }

    double costBarrio = (widget.preciosConfig['v_envio_barrio'] ?? 0).toDouble();
    double costVilla = (widget.preciosConfig['precio_delivery'] ?? 0).toDouble();
    double costRetiro = (widget.preciosConfig['v_envio_retiro'] ?? 0).toDouble();

    double envio = 0;
    if (_metodoEnvio == 'Barrio') envio = costBarrio;
    if (_metodoEnvio == 'Villa') envio = costVilla;
    if (_metodoEnvio == 'Retiro') envio = costRetiro;
    
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

                Text("TIPO DE ENTREGA / ENVÍO", style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 10),
                _buildShippingOption('Barrio', 'Envío a domicilio en el barrio', Icons.local_shipping_outlined, costBarrio),
                const SizedBox(height: 10),
                _buildShippingOption('Villa', 'Envío adicional a la Villa', Icons.directions_bike_outlined, costVilla),
                const SizedBox(height: 10),
                _buildShippingOption('Retiro', 'Retiro por el local (Gratis)', Icons.storefront_outlined, costRetiro),
                
                if (_metodoEnvio != 'Retiro') ...[
                   const SizedBox(height: 25),
                   _buildAddressSection(),
                ],
                
                const SizedBox(height: 25),
                _buildLocationSection(),
                
                const SizedBox(height: 30),
                
                Text("MÉTODO DE PAGO", style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                const SizedBox(height: 15),
                Row(
                  children: [
                    _buildPaymentOption('Efectivo', Icons.payments_outlined, "EFECTIVO"),
                    const SizedBox(width: 15),
                    _buildPaymentOption('Transferencia', Icons.account_balance_outlined, "MERCADO PAGO"),
                  ],
                ),
                
                const SizedBox(height: 20),
                if (_metodoPago == 'Efectivo')
                  _buildCashSection(total)
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

  Widget _buildPaymentOption(String value, IconData icon, String label) {
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
              Text(label, style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 11, color: isSelected ? const Color(0xFFFF7F50) : Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCashSection(double totalOrder) {
    double pagaCon = double.tryParse(_pagaConController.text.replaceAll(',', '.')) ?? 0;
    double vuelto = pagaCon > totalOrder ? pagaCon - totalOrder : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
          TextField(
            controller: _pagaConController,
            keyboardType: TextInputType.number,
            style: GoogleFonts.montserrat(
              fontWeight: FontWeight.bold, 
              color: Colors.black, // Texto bien oscuro para que se vea
              fontSize: 18,
            ),
            decoration: InputDecoration(
              labelText: "¿CON CUÁNTO ABONARÁ?",
              labelStyle: GoogleFonts.montserrat(color: Colors.blueGrey[700], fontWeight: FontWeight.w600),
              prefixIcon: const Icon(Icons.attach_money, color: Colors.green, size: 28),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(color: Colors.green, width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(color: Colors.green.withOpacity(0.5), width: 1.5),
              ),
              hintText: "Ej: 10000",
              hintStyle: GoogleFonts.montserrat(color: Colors.grey[400]),
              filled: true,
              fillColor: Colors.white, // Fondo blanco para máximo contraste
            ),
          ),
        if (pagaCon > 0 && pagaCon < totalOrder)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 10),
            child: Text("El monto debe ser mayor al total", style: GoogleFonts.montserrat(color: Colors.red, fontSize: 11)),
          ),
        if (vuelto > 0)
          Container(
            margin: const EdgeInsets.only(top: 15),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                const SizedBox(width: 10),
                Text("VUELTO: ", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 13)),
                Text(_formatMoney(vuelto), style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.deepOrange)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildShippingOption(String value, String description, IconData icon, double cost) {
    bool isSelected = _metodoEnvio == value;
    return GestureDetector(
      onTap: () async {
        setState(() => _metodoEnvio = value);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('lastShippingMethod', value);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF7F50).withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: isSelected ? const Color(0xFFFF7F50) : Colors.grey.withOpacity(0.2), width: 1.5),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? const Color(0xFFFF7F50) : Colors.grey, size: 24),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 14, color: isSelected ? const Color(0xFFFF7F50) : Colors.black87)),
                  Text(description, style: GoogleFonts.montserrat(fontSize: 10, color: Colors.grey[600])),
                ],
              ),
            ),
            if (cost > 0)
                  Text("+${_formatMoney(cost)}", style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 14, color: Colors.blueGrey[800])),
            const SizedBox(width: 5),
            Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_off, color: isSelected ? const Color(0xFFFF7F50) : Colors.grey[300], size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTransferSection() {
    final alias = widget.preciosConfig['alias_mp'] ?? 'bonzalosc22.uala';
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
          if (widget.preciosConfig['whatsapp_comprobantes'] != null && widget.preciosConfig['whatsapp_comprobantes'].toString().isNotEmpty) ...[
            const SizedBox(height: 15),
            Text("ENVIAR COMPROBANTE AL (WhatsApp):", style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w900, color: const Color(0xFFFF7F50))),
            const SizedBox(height: 5),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFF7F50).withOpacity(0.3))),
                    child: Text(widget.preciosConfig['whatsapp_comprobantes'].toString(), style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.black)),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: widget.preciosConfig['whatsapp_comprobantes'].toString()));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Número copiado")));
                  },
                  style: IconButton.styleFrom(backgroundColor: const Color(0xFFFF7F50), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  icon: const Icon(Icons.copy, size: 20),
                )
              ],
            ),
          ],
          const SizedBox(height: 10),
          Text("Abrí Mercado Pago, pegá el Alias y realizá el envío.", style: GoogleFonts.montserrat(fontSize: 10, color: Colors.blueGrey[600], fontStyle: FontStyle.italic)),
          const SizedBox(height: 20),
          
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.orange[50], borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.orange.withOpacity(0.3))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.chat, color: Colors.green, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Al confirmar, te redirigiremos a WhatsApp para que envíes el comprobante.",
                        style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.orange[900]),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (!_isEditingWhatsApp)
                  GestureDetector(
                    onTap: () => setState(() => _isEditingWhatsApp = true),
                    child: Text(
                      "¿Enviar a otro número? [Editar]",
                      style: GoogleFonts.montserrat(fontSize: 9, color: Colors.blue[800], fontWeight: FontWeight.bold, decoration: TextDecoration.underline),
                    ),
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _whatsappManualController,
                          keyboardType: TextInputType.phone,
                          style: GoogleFonts.montserrat(fontSize: 11),
                          decoration: InputDecoration(
                            hintText: "Número con código de país (ej: 549...)",
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                            border: UnderlineInputBorder(borderSide: BorderSide(color: Colors.orange[900]!)),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => setState(() => _isEditingWhatsApp = false),
                        icon: const Icon(Icons.check, color: Colors.green, size: 18),
                      )
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("MEJORAR ENTREGA (GPS)", style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _isCapturingLocation ? null : _getCurrentLocation,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 15),
            decoration: BoxDecoration(
              color: _latCliente != null ? Colors.green[600] : const Color(0xFF2196F3), // Azul premium si no hay nada
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: (_latCliente != null ? Colors.green : Colors.blue).withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                )
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _latCliente != null ? Icons.location_on : Icons.my_location,
                  color: Colors.white,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    _latCliente != null ? "UBICACIÓN CAPTURADA ✅" : "CAPTURAR MI UBICACIÓN",
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w900,
                      fontSize: 13, // Un pelín más pequeño
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                if (_isCapturingLocation) ...[
                  const SizedBox(width: 15),
                  const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddressSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("📍 DIRECCIÓN / ENTREGA (OPCIONAL)", style: GoogleFonts.montserrat(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 10),
        TextField(
          controller: _addressController,
          style: GoogleFonts.montserrat(fontSize: 14),
          decoration: InputDecoration(
            hintText: "Ej: Av. Rivadavia 1234, Piso 2 o Casa azul",
            hintStyle: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey),
            prefixIcon: const Icon(Icons.home, color: Color(0xFFFF7F50)),
            filled: true,
            fillColor: Colors.blueGrey[50],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.all(15),
          ),
        ),
      ],
    );
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isCapturingLocation = true);
    try {
      // 1. Verificar o pedir permisos a nivel de Aplicación
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        // Si es la primera vez o se denegó antes, pedir explícitamente
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'No se otorgaron permisos de ubicación. Debes aceptarlos en el cartel del sistema.';
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Los permisos están bloqueados en ajustes. Por favor habilítalos manualmente.")),
          );
        }
        await Geolocator.openAppSettings();
        return;
      }

      // 2. Obtener ubicación con timeout
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 20)
      );

      setState(() {
        _latCliente = position.latitude;
        _longCliente = position.longitude;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("📍 Ubicación capturada con éxito"), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isCapturingLocation = false);
    }
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

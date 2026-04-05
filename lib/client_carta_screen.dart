import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'order_status_screen.dart';
import 'cart_summary_screen.dart';

class ClientCartaScreen extends StatefulWidget {
  const ClientCartaScreen({super.key});

  @override
  State<ClientCartaScreen> createState() => _ClientCartaScreenState();
}

class _ClientCartaScreenState extends State<ClientCartaScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _preciosConfig;
  final Map<String, int> _carrito = {};

  void _addToCart(String id) => setState(() => _carrito[id] = (_carrito[id] ?? 0) + 1);
  void _removeFromCart(String id) {
    if ((_carrito[id] ?? 0) > 0) {
      setState(() {
        _carrito[id] = _carrito[id]! - 1;
        if (_carrito[id] == 0) _carrito.remove(id);
      });
    }
  }

  double _getRawPrice(Map<String, dynamic> prod) {
    if (prod['categoria'] == 'Empanada') {
      final key = (prod['is_especial'] ?? false) ? 'unidad_especial' : 'unidad_comun';
      final val = _preciosConfig?[key];
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val.replaceAll(',', '.')) ?? 0;
      return 0;
    }
    final p = prod['precio'];
    if (p is num) return p.toDouble();
    if (p is String) return double.tryParse(p.replaceAll(',', '.')) ?? 0;
    return 0;
  }

  double _calculateTotal(List<DocumentSnapshot> allProducts) {
    double subtotal = 0;
    _carrito.forEach((id, qty) {
      try {
        final doc = allProducts.firstWhere((d) => d.id == id);
        subtotal += _getRawPrice(doc.data() as Map<String, dynamic>) * qty;
      } catch (e) {
        debugPrint("Producto $id no encontrado en el catálogo");
      }
    });
    return subtotal;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initOrderStatusListener();
    _checkRestoreCart();
    _checkActiveOrderRedirect();
  }

  void _checkActiveOrderRedirect() async {
    final prefs = await SharedPreferences.getInstance();
    final String? editingId = prefs.getString('editingOrderId');
    if (editingId != null) return; 

    final String? lastOrderId = prefs.getString('lastOrderId');
    if (lastOrderId != null) {
      final doc = await FirebaseFirestore.instance.collection('pedidos').doc(lastOrderId).get();
      if (doc.exists) {
        // Redirecciones automáticas desactivadas para permitir navegación manual
      }
    }
  }

  void _checkRestoreCart() async {
    final prefs = await SharedPreferences.getInstance();
    final String? lastOrderId = prefs.getString('lastOrderId');
    
    if (lastOrderId == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('pedidos').doc(lastOrderId).get();
      if (!doc.exists) return;

      final data = doc.data() as Map<String, dynamic>? ?? {};
      final String estado = data['estado'] ?? '';

      if (estado == 'modificando') {
        setState(() => _carrito.clear());
        final List<dynamic> items = data['productos'] ?? [];
        setState(() {
          for (var item in items) {
            final String? id = item['id'];
            final int qty = item['cantidad'] ?? 0;
            if (id != null && qty > 0) {
              _carrito[id] = qty;
            }
          }
        });
        await prefs.setString('editingOrderId', lastOrderId);
      }
    } catch (e) {
      debugPrint("[ERROR] Falló la restauración del pedido $lastOrderId: $e");
      setState(() => _carrito.clear());
    }
  }

  void _initOrderStatusListener() {
    FirebaseFirestore.instance
        .collection('pedidos')
        .snapshots()
        .listen((snapshot) async {
          final prefs = await SharedPreferences.getInstance();
          final String? lastOrderId = prefs.getString('lastOrderId');
          final String? lastStatus = prefs.getString('notifiedStatus') ?? 'Pendiente';

          if (lastOrderId == null) return;

          for (var change in snapshot.docChanges) {
            if (change.doc.id == lastOrderId) {
              final data = change.doc.data() as Map<String, dynamic>;
              final String newStatus = data['estado'] ?? 'Pendiente';
              
              if (newStatus == lastStatus) continue;

              await prefs.setString('notifiedStatus', newStatus);

              if (newStatus == 'Cancelado' && mounted) {
                final String? editingId = prefs.getString('editingOrderId');
                if (editingId != change.doc.id) {
                   _showRejectionAlert(data['motivo_rechazo'] ?? 'No especificado');
                }
              }
            }
          }
        });
  }

  Widget _buildActiveOrderBanner() {
    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, prefsSnapshot) {
        if (!prefsSnapshot.hasData) return const SizedBox.shrink();
        final String? lastOrderId = prefsSnapshot.data!.getString('lastOrderId');
        if (lastOrderId == null) return const SizedBox.shrink();

        return StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('pedidos').doc(lastOrderId).snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox.shrink();
            final data = snapshot.data!.data() as Map<String, dynamic>;
            final String estado = data['estado'] ?? '';
            
            if (estado == 'Finalizado' || estado == 'Cancelado' || estado == '' || estado == 'modificando') return const SizedBox.shrink();

            return GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => OrderStatusScreen(orderId: lastOrderId)));
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                color: Colors.amber[800],
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Tenés un pedido en curso (#${lastOrderId.length > 6 ? lastOrderId.substring(lastOrderId.length - 6).toUpperCase() : lastOrderId.toUpperCase()})",
                        style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showRejectionAlert(String motivo) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 20),
              color: Colors.red[50],
              child: Column(
                children: [
                   const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 40),
                   const SizedBox(height: 10),
                   Text("AVISO IMPORTANTE", style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, color: Colors.red[800], fontSize: 16)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(25),
              child: Column(
                children: [
                   Text("Tu pedido fue rechazado", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87)),
                   const SizedBox(height: 15),
                   Container(
                     padding: const EdgeInsets.all(12),
                     decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(15)),
                     child: Text(
                       "Motivo: $motivo",
                       style: GoogleFonts.montserrat(fontSize: 14, color: Colors.grey[700], fontStyle: FontStyle.italic),
                       textAlign: TextAlign.center,
                     ),
                   ),
                   const SizedBox(height: 25),
                   OutlinedButton(
                     onPressed: () {
                       setState(() => _carrito.clear());
                       Navigator.pop(context);
                     },
                     style: OutlinedButton.styleFrom(
                       foregroundColor: Colors.red,
                       side: const BorderSide(color: Colors.red),
                       minimumSize: const Size(double.infinity, 50),
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                     ),
                     child: Text("ENTENDIDO", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
                   ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _checkStatus() {
    if (_preciosConfig == null) return true;
    final int estadoControl = _preciosConfig!['estado_control'] ?? (_preciosConfig!['local_abierto_manual'] == false ? 0 : 1);
    if (estadoControl == 0) return false;
    if (estadoControl == 2) return true;
    final horario = _preciosConfig!['horario']?.toString().toLowerCase() ?? '';
    try {
      final matches = RegExp(r'(\d{1,2})').allMatches(horario).toList();
      if (matches.length >= 2) {
        int start = int.parse(matches[0].group(0)!);
        int end = int.parse(matches[matches.length - 1].group(0)!);
        final int now = DateTime.now().hour;
        if (start > end) return (now >= start) || (now < end);
        else return (now >= start) && (now < end);
      }
    } catch (e) {
      debugPrint("Error parseando horario cliente: $e");
    }
    final int hora = DateTime.now().hour;
    return (hora >= 20) || (hora < 4);
  }

  String _formatMoney(dynamic value) {
    if (value == null || value == '--') return "\$0,00";
    double price = 0;
    if (value is double) price = value;
    else if (value is int) price = value.toDouble();
    else if (value is String) price = double.tryParse(value.replaceAll(',', '.')) ?? 0;
    return "\$${price.toStringAsFixed(2).replaceAll('.', ',')}";
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('configuracion_local').doc('precios').snapshots(),
      builder: (context, configSnapshot) {
        if (!configSnapshot.hasData) return const Center(child: CircularProgressIndicator());
        _preciosConfig = configSnapshot.data!.data() as Map<String, dynamic>?;
        final bool isOpen = _checkStatus();

        return Scaffold(
          backgroundColor: const Color(0xFFF9F9F9),
          floatingActionButton: FloatingActionButton(
            onPressed: () async {
              String whatsapp = _preciosConfig?['whatsapp_comprobantes'] ?? '';
              if (whatsapp.isEmpty) {
                final extra = await FirebaseFirestore.instance.collection('configuracion_negocio').doc('contacto').get();
                whatsapp = extra.data()?['whatsapp_comprobantes'] ?? '';
              }
              if (whatsapp.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No hay un número de WhatsApp configurado aún.")));
                return;
              }
              String finalNumber = whatsapp.replaceAll(RegExp(r'[^0-9]'), '');
              if (finalNumber.length == 10) finalNumber = "549$finalNumber";
              final url = "https://wa.me/$finalNumber?text=${Uri.encodeComponent('Hola! Tengo una consulta sobre mi pedido...')}";
              if (await canLaunchUrl(Uri.parse(url))) await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
            },
            backgroundColor: const Color(0xFF25D366),
            child: ClipOval(
              child: Image.network(
                'https://cdn-icons-png.flaticon.com/512/124/124034.png',
                width: 35, height: 35, fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.chat, color: Colors.white),
              ),
            ),
          ),
          body: Stack(
            children: [
              Column(
                children: [
                  _buildActiveOrderBanner(),
                  _buildHeader(isOpen),
                  if (!isOpen) _buildClosedBanner(),
                  Expanded(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                      ),
                      child: Column(
                        children: [
                          TabBar(
                            controller: _tabController,
                            isScrollable: true,
                            indicatorWeight: 4,
                            indicatorSize: TabBarIndicatorSize.label,
                            indicatorColor: const Color(0xFFFF7F50),
                            labelColor: const Color(0xFFFF7F50),
                            unselectedLabelColor: Colors.grey,
                            labelStyle: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 13),
                            tabs: const [Tab(text: "PROMOS"), Tab(text: "PIZZAS"), Tab(text: "EMPANADAS"), Tab(text: "BEBIDAS")],
                          ),
                          Expanded(
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                _buildCardList('Oferta', isOpen),
                                _buildCardList('Pizza', isOpen),
                                _buildCardList('Empanada', isOpen),
                                _buildCardList('Bebida', isOpen),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (_carrito.isNotEmpty)
                _buildStickyCartButton(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isOpen) {
    final String storeName = _preciosConfig?['nombre'] ?? 'Pizzería Miguel Angelo';
    final String storeSlogan = _preciosConfig?['slogan'] ?? '¡Pizzas con Amor!';
    return Container(
      padding: const EdgeInsets.only(top: 60, left: 25, right: 25, bottom: 20),
      color: const Color(0xFFF9F9F9),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(storeSlogan, style: GoogleFonts.montserrat(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(storeName, style: GoogleFonts.montserrat(fontSize: 24, fontWeight: FontWeight.w900, color: const Color(0xFF2D2D2D)))),
              ],
            ),
          ),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                   IconButton(onPressed: () => Navigator.pushNamed(context, '/perfil'), icon: const Icon(Icons.account_circle_outlined, color: Colors.blueGrey, size: 24)),
                   IconButton(onPressed: () async {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('isLoggedIn', false);
                      if (context.mounted) Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                    }, icon: const Icon(Icons.logout, color: Color(0xFFFF7F50), size: 22)),
                ],
              ),
              Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: isOpen ? Colors.green[50] : Colors.red[50], borderRadius: BorderRadius.circular(20), border: Border.all(color: isOpen ? Colors.green : Colors.red, width: 1)), child: Row(mainAxisSize: MainAxisSize.min, children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: isOpen ? Colors.green : Colors.red, shape: BoxShape.circle)), const SizedBox(width: 8), Text(isOpen ? "ABIERTO" : "CERRADO", style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.bold, color: isOpen ? Colors.green[800] : Colors.red[800]))])),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildClosedBanner() {
    return Container(
      width: double.infinity, margin: const EdgeInsets.only(left: 25, right: 25, bottom: 20), padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.red[700], borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))]),
      child: Row(children: [const Icon(Icons.info_outline, color: Colors.white), const SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_preciosConfig?['estado_control'] == 0 ? "CERRADO TEMPORALMENTE" : "ESTAMOS CERRADOS", style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)), Text(_preciosConfig?['estado_control'] == 0 ? "Disculpá las molestias, volvemos pronto." : "Volveremos a abrir a las 20:00 hs.", style: GoogleFonts.montserrat(color: Colors.white.withOpacity(0.9), fontSize: 11))]))]),
    );
  }

  Widget _buildStickyCartButton() {
    return Positioned(
      bottom: 30, left: 30, right: 30,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('productos').snapshots(),
        builder: (context, snapshot) {
          double total = 0;
          if (snapshot.hasData) total = _calculateTotal(snapshot.data!.docs);
          return GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => CartSummaryScreen(carrito: _carrito, preciosConfig: _preciosConfig!, allProducts: snapshot.data!.docs, onOrderSent: () => setState(() => _carrito.clear()))));
            },
            child: Container(height: 60, decoration: BoxDecoration(color: const Color(0xFF2D2D2D), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))]), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 24), const SizedBox(width: 15), Text("VER MI BOLSA", style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.2)), const SizedBox(width: 10), Text("(${_formatMoney(total)})", style: GoogleFonts.montserrat(color: const Color(0xFFFF7F50), fontWeight: FontWeight.bold))])),
          );
        }
      ),
    );
  }

  Widget _buildCardList(String category, bool storeOpen) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('productos').where('categoria', isEqualTo: category).where('disponible', isEqualTo: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return Center(child: Text("Sin disponibilidad en $category", style: GoogleFonts.montserrat(color: Colors.grey, fontSize: 12)));
        return ListView.builder(
          padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 100),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final docId = docs[index].id;
            final prod = docs[index].data() as Map<String, dynamic>;
            final bool disponible = (prod['disponible'] ?? true) && storeOpen;
            final int qty = _carrito[docId] ?? 0;
            String price = category == 'Empanada' ? ((prod['is_especial'] ?? false) ? _formatMoney(_preciosConfig?['unidad_especial']) : _formatMoney(_preciosConfig?['unidad_comun'])) : _formatMoney(prod['precio']);
            return Opacity(opacity: disponible ? 1.0 : 0.6, child: Container(margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15)]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(height: 140, width: double.infinity, decoration: BoxDecoration(color: Colors.grey[100], borderRadius: const BorderRadius.vertical(top: Radius.circular(20))), clipBehavior: Clip.antiAlias, child: _buildImageWidget(prod['foto_url'], category == 'Bebida' ? Icons.local_drink : Icons.fastfood_rounded)), Padding(padding: const EdgeInsets.all(15), child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(prod['nombre'], style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(height: 4), if (category == 'Oferta') ...List<String>.from(prod['items'] ?? []).map((item) => Padding(padding: const EdgeInsets.only(top: 2), child: Text("🍕 $item", style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey[700])))) else Text(prod['descripcion'] ?? "", style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey[500]), maxLines: 3), const SizedBox(height: 8), Text(price, style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, color: const Color(0xFFFF7F50), fontSize: 16))])), if (disponible) Padding(padding: const EdgeInsets.only(left: 10), child: _buildCounter(docId, qty))]))])));
          },
        );
      },
    );
  }

  Widget _buildCounter(String id, int qty) {
    return Container(decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(15)), child: Row(children: [IconButton(onPressed: () => _removeFromCart(id), icon: const Icon(Icons.remove_circle_outline, size: 20, color: Color(0xFFFF7F50))), Text(qty.toString(), style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 16)), IconButton(onPressed: () => _addToCart(id), icon: const Icon(Icons.add_circle, size: 20, color: Color(0xFFFF7F50)))]));
  }

  Widget _buildImageWidget(String? imageData, IconData fallbackIcon) {
    if (imageData == null || imageData.isEmpty) return Center(child: Icon(fallbackIcon, color: const Color(0xFFFF7F50), size: 50));
    try { return Image.memory(base64Decode(imageData), fit: BoxFit.cover, errorBuilder: (c, e, s) => Center(child: Icon(fallbackIcon, size: 50))); } catch (e) { return Center(child: Icon(fallbackIcon, size: 50)); }
  }
}

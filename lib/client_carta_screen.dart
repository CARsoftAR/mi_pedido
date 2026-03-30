import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
      final doc = allProducts.firstWhere((d) => d.id == id);
      subtotal += _getRawPrice(doc.data() as Map<String, dynamic>) * qty;
    });
    // Costo de envío fijo de $3000
    if (subtotal > 0) {
      subtotal += 3000;
    }
    return subtotal;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _initOrderStatusListener();
  }

  void _initOrderStatusListener() {
    FirebaseFirestore.instance
        .collection('pedidos')
        .snapshots() // Escuchar todos pero filtrar por cliente o guardar ID en prefs
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
                _showRejectionAlert(data['motivo_rechazo'] ?? 'No especificado');
              } else if (newStatus == 'En Preparación' && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("¡Tu pedido fue aceptado! En breve estará listo ✅"),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 5),
                  ),
                );
              }
            }
          }
        });
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
    
    // Si el Admin dijo CERRADO (0), es cerrado definitivo.
    if (estadoControl == 0) return false;
    // Si el Admin dijo ABIERTO (2), es abierto definitivo.
    if (estadoControl == 2) return true;
    
    // Modo AUTO (1): Respeta horario 20:00 - 04:00
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
          body: Stack(
            children: [
              Column(
                children: [
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
                            tabs: const [
                              Tab(text: "PROMOS"),
                              Tab(text: "PIZZAS"),
                              Tab(text: "EMPANADAS"),
                              Tab(text: "BEBIDAS"),
                              Tab(text: "POSTRES")
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                _buildCardList('Oferta', isOpen),
                                _buildCardList('Pizza', isOpen),
                                _buildCardList('Empanada', isOpen),
                                _buildCardList('Bebida', isOpen),
                                _buildCardList('Postre', isOpen)
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
    return Container(
      padding: const EdgeInsets.only(top: 60, left: 25, right: 25, bottom: 20),
      color: const Color(0xFFF9F9F9),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("¡Pizzas con Amor!", style: GoogleFonts.montserrat(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.bold)),
              Text("Mi Pedido Real", style: GoogleFonts.montserrat(fontSize: 24, fontWeight: FontWeight.w900, color: const Color(0xFF2D2D2D))),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isOpen ? Colors.green[50] : Colors.red[50],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isOpen ? Colors.green : Colors.red, width: 1),
            ),
            child: Row(
              children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: isOpen ? Colors.green : Colors.red, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text(isOpen ? "ABIERTO" : "CERRADO", style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.bold, color: isOpen ? Colors.green[800] : Colors.red[800])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClosedBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(left: 25, right: 25, bottom: 20),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.red[700], 
        borderRadius: BorderRadius.circular(15), 
        boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))]
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.white),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _preciosConfig?['estado_control'] == 0 ? "CERRADO TEMPORALMENTE" : "ESTAMOS CERRADOS",
                  style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)
                ),
                Text(
                  _preciosConfig?['estado_control'] == 0 
                      ? "Disculpá las molestias, volvemos pronto." 
                      : "Volveremos a abrir a las 20:00 hs.", 
                  style: GoogleFonts.montserrat(color: Colors.white.withOpacity(0.9), fontSize: 11)
                ),
              ],
            ),
          ),
        ],
      ),
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
              final allDocs = snapshot.data!.docs;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CartSummaryScreen(
                    carrito: _carrito,
                    preciosConfig: _preciosConfig!,
                    allProducts: allDocs,
                  ),
                ),
              );
            },
            child: Container(
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFF2D2D2D),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shopping_bag_outlined, color: Colors.white, size: 24),
                  const SizedBox(width: 15),
                  Text("VER MI BOLSA", style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                  const SizedBox(width: 10),
                  Text("(${_formatMoney(total)})", style: GoogleFonts.montserrat(color: const Color(0xFFFF7F50), fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  Widget _buildCardList(String category, bool storeOpen) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('productos').where('categoria', isEqualTo: category).snapshots(),
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
            
            String price = "";
            if (category == 'Empanada') {
              price = (prod['is_especial'] ?? false) ? _formatMoney(_preciosConfig?['unidad_especial']) : _formatMoney(_preciosConfig?['unidad_comun']);
            } else {
              price = _formatMoney(prod['precio']);
            }

            return Opacity(
              opacity: disponible ? 1.0 : 0.6,
              child: Container(
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 15)]),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Stack(
                      children: [
                        Container(
                          height: 140, width: double.infinity,
                          decoration: BoxDecoration(color: Colors.grey[100], borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
                          clipBehavior: Clip.antiAlias,
                          child: _buildImageWidget(prod['foto_url'], category == 'Bebida' ? Icons.local_drink : Icons.fastfood_rounded),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.all(15),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(prod['nombre'], style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(height: 4),
                                if (category == 'Oferta') ...[
                                  ...List<String>.from(prod['items'] ?? []).map((item) {
                                    String icon = "🍕";
                                    if (item.toLowerCase().contains("coca") || item.toLowerCase().contains("bebi") || item.toLowerCase().contains("paso")) icon = "🥤";
                                    if (item.toLowerCase().contains("empa")) icon = "🥟";
                                    if (item.toLowerCase().contains("postre")) icon = "🍰";
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text("$icon $item", style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey[700])),
                                    );
                                  }),
                                ] else
                                  Text(prod['descripcion'] ?? "", style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey[500]), maxLines: 3),
                                const SizedBox(height: 8),
                                Text(price, style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, color: const Color(0xFFFF7F50), fontSize: 16)),
                              ],
                            ),
                          ),
                          if (disponible)
                            Padding(
                              padding: const EdgeInsets.only(left: 10),
                              child: _buildCounter(docId, qty),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCounter(String id, int qty) {
    return Container(
      decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(15)),
      child: Row(
        children: [
          IconButton(onPressed: () => _removeFromCart(id), icon: const Icon(Icons.remove_circle_outline, size: 20, color: Color(0xFFFF7F50))),
          Text(qty.toString(), style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 16)),
          IconButton(onPressed: () => _addToCart(id), icon: const Icon(Icons.add_circle, size: 20, color: Color(0xFFFF7F50))),
        ],
      ),
    );
  }

  Widget _buildImageWidget(String? imageData, IconData fallbackIcon) {
    if (imageData == null || imageData.isEmpty) return Center(child: Icon(fallbackIcon, color: const Color(0xFFFF7F50), size: 50));
    try { return Image.memory(base64Decode(imageData), fit: BoxFit.cover, errorBuilder: (c, e, s) => Center(child: Icon(fallbackIcon, size: 50)));
    } catch (e) { return Center(child: Icon(fallbackIcon, size: 50)); }
  }
}

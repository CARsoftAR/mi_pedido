import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class ClientCartaScreen extends StatefulWidget {
  const ClientCartaScreen({super.key});

  @override
  State<ClientCartaScreen> createState() => _ClientCartaScreenState();
}

class _ClientCartaScreenState extends State<ClientCartaScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Map<String, dynamic>? _preciosConfig;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  bool _isStoreOpenNow() {
    if (_preciosConfig == null) return true;
    final bool manualOpen = _preciosConfig!['local_abierto_manual'] ?? true;
    if (!manualOpen) return false;

    try {
      final String horarioRaw = (_preciosConfig!['horario'] ?? "").toString().trim().toLowerCase();
      final parts = horarioRaw.split(RegExp(r'[\sa\-]+')).where((e) => e.isNotEmpty).toList();
      if (parts.length < 2) return true;

      final startParts = parts[0].trim().split(':');
      final endParts = parts[parts.length - 1].trim().split(':');
      
      final double startVal = double.parse(startParts[0]) + (double.parse(startParts[1]) / 60.0);
      final double endVal = double.parse(endParts[0]) + (double.parse(endParts[1]) / 60.0);
      
      final now = DateTime.now();
      final double nowVal = now.hour + (now.minute / 60.0);

      if (endVal < startVal) {
        return (nowVal >= startVal || nowVal < endVal);
      } else {
        return (nowVal >= startVal && nowVal < endVal);
      }
    } catch (e) { return true; }
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
        final bool isOpen = _isStoreOpenNow();

        return Scaffold(
          backgroundColor: const Color(0xFFF9F9F9),
          body: Column(
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
                            _buildCardList('Oferta'),
                            _buildCardList('Pizza'),
                            _buildCardList('Empanada'),
                            _buildCardList('Bebida'),
                            _buildCardList('Postre')
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
      decoration: BoxDecoration(color: Colors.red[700], borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))]),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Colors.white),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("ESTAMOS CERRADOS", style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                Text("Volveremos a las ${_preciosConfig?['horario'] ?? 'el próximo turno'}.", style: GoogleFonts.montserrat(color: Colors.white.withOpacity(0.9), fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardList(String category) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('productos').where('categoria', isEqualTo: category).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return Center(child: Text("Sin disponibilidad en $category", style: GoogleFonts.montserrat(color: Colors.grey, fontSize: 12)));

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final prod = docs[index].data() as Map<String, dynamic>;
            final bool disponible = prod['disponible'] ?? true;
            final bool isOferta = category == 'Oferta';
            
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
                          height: 180, width: double.infinity,
                          decoration: BoxDecoration(color: Colors.grey[100], borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
                          clipBehavior: Clip.antiAlias,
                          child: _buildImageWidget(prod['foto_url'], category == 'Bebida' ? Icons.local_drink : Icons.fastfood_rounded),
                        ),
                        if (!disponible)
                          Positioned.fill(child: Container(decoration: BoxDecoration(color: Colors.black45, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))), child: Center(child: Text("AGOTADO", style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24, letterSpacing: 2))))),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.all(15),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(prod['nombre'], style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text(price, style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, color: const Color(0xFFFF7F50), fontSize: 18)),
                            ],
                          ),
                          const SizedBox(height: 5),
                          if (isOferta) ...[
                            ...List<String>.from(prod['items'] ?? []).map((item) => Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text("• $item", style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey[700])),
                            )),
                          ] else
                            Text(prod['descripcion'] ?? "", style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey[500]), maxLines: 2, overflow: TextOverflow.ellipsis),
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

  Widget _buildImageWidget(String? imageData, IconData fallbackIcon) {
    if (imageData == null || imageData.isEmpty) return Center(child: Icon(fallbackIcon, color: const Color(0xFFFF7F50), size: 50));
    try { return Image.memory(base64Decode(imageData), fit: BoxFit.cover, errorBuilder: (c, e, s) => Center(child: Icon(fallbackIcon, size: 50)));
    } catch (e) { return Center(child: Icon(fallbackIcon, size: 50)); }
  }
}

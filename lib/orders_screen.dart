import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: Text("Gestión de Pedidos", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFF7F50),
          labelColor: const Color(0xFFFF7F50),
          unselectedLabelColor: Colors.grey,
          labelStyle: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 12),
          tabs: const [
            Tab(text: "NUEVOS"),
            Tab(text: "PROCESO"),
            Tab(text: "DESPACHADOS"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrderList('Nuevo'),
          _buildOrderList('En Proceso'),
          _buildOrderList('Despachado'),
        ],
      ),
    );
  }

  Widget _buildOrderList(String estado) {
    return StreamBuilder<QuerySnapshot>(
      // Quitamos el .orderBy local para evitar el error de índice compuesto de Firebase
      stream: FirebaseFirestore.instance
          .collection('pedidos')
          .where('estado', isEqualTo: estado)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}", style: const TextStyle(fontSize: 10)));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        // Ordenamos localmente por fecha (más recientes primero)
        final List<QueryDocumentSnapshot> docs = snapshot.data!.docs;
        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final Timestamp? aTime = aData['createdAt'];
          final Timestamp? bTime = bData['createdAt'];
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime);
        });

        if (docs.isEmpty) {
          return Center(child: Text("No hay pedidos en $estado", style: GoogleFonts.montserrat(color: Colors.grey)));
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
                title: Text("Pedido #${orderId.substring(orderId.length - 5)}", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
                subtitle: Text("Total: \$${orderData['total'] ?? 0}"),
                trailing: _buildActionButton(orderId, estado),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildActionButton(String id, String currentStatus) {
    String nextStatus = "";
    String label = "";
    Color color = Colors.orange;

    if (currentStatus == 'Nuevo') {
      nextStatus = 'En Proceso';
      label = 'LISTO';
      color = Colors.blue;
    } else if (currentStatus == 'En Proceso') {
      nextStatus = 'Despachado';
      label = 'DESPACHAR';
      color = Colors.green;
    } else if (currentStatus == 'Despachado') {
      nextStatus = 'Finalizado';
      label = 'ENTREGAR';
      color = Colors.purple;
    }

    return ElevatedButton(
      onPressed: () => FirebaseFirestore.instance.collection('pedidos').doc(id).update({
        'estado': nextStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      }),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        padding: const EdgeInsets.symmetric(horizontal: 12),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

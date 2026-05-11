import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyBrKYzDilrpRuzduz2762JsbZpA03BMgE8",
        appId: "1:95059591548:android:ef3dedc01d37b5b43c24f9",
        messagingSenderId: "95059591548",
        projectId: "mi-pedido-pizzeria",
        storageBucket: "mi-pedido-pizzeria.firebasestorage.app",
      ),
    );
  } catch (e) {
    debugPrint("Firebase Error: $e");
  }
  runApp(const AdminWindowsApp());
}

class AdminWindowsApp extends StatelessWidget {
  const AdminWindowsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Plataforma Admin Windows',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        textTheme: GoogleFonts.montserratTextTheme(),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F172A),
          primary: const Color(0xFF2563EB),
        ),
      ),
      home: const MainContainer(),
    );
  }
}

class MainContainer extends StatefulWidget {
  const MainContainer({super.key});

  @override
  State<MainContainer> createState() => _MainContainerState();
}

class _MainContainerState extends State<MainContainer> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _buildSidebar(),
          Expanded(
            child: _selectedIndex == 0 
                ? const DashboardPage() 
                : const BusinessesPage(),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 260,
      color: const Color(0xFF0F172A),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.shield_rounded, color: Colors.blueAccent, size: 32),
                const SizedBox(width: 15),
                Text("CONTROL", style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 22, letterSpacing: 1.5)),
              ],
            ),
          ),
          const Divider(color: Colors.white10, indent: 20, endIndent: 20),
          const SizedBox(height: 20),
          _sidebarItem(0, "Métricas", Icons.analytics_rounded),
          _sidebarItem(1, "Negocios & Cobros", Icons.business_center_rounded),
          const Spacer(),
          _buildSystemStatus(),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _sidebarItem(int index, String title, IconData icon) {
    final isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blueAccent.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? Colors.blueAccent : Colors.blueGrey[400], size: 22),
            const SizedBox(width: 15),
            Text(title, style: GoogleFonts.montserrat(color: isSelected ? Colors.white : Colors.blueGrey[400], fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemStatus() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(15)),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.circle, color: Colors.green, size: 8),
              const SizedBox(width: 10),
              Text("Cloud Sync: OK", style: GoogleFonts.montserrat(color: Colors.white60, fontSize: 10)),
            ],
          ),
          const SizedBox(height: 5),
          Text("v1.5.0 Premium", style: GoogleFonts.montserrat(color: Colors.white24, fontSize: 9)),
        ],
      ),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});
  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  String _dateFilter = 'Hoy';
  String _paymentFilter = 'Todos';
  String _statusFilter = 'Todos';
  DateTimeRange? _customRange;
  double _commissionPercent = 5.0;

  bool _isDateInRange(DateTime date) {
    final now = DateTime.now();
    if (_dateFilter == 'Hoy') return date.year == now.year && date.month == now.month && date.day == now.day;
    if (_dateFilter == 'Mes Actual') return date.year == now.year && date.month == now.month;
    if (_dateFilter == 'Personalizado' && _customRange != null) return date.isAfter(_customRange!.start) && date.isBefore(_customRange!.end.add(const Duration(days: 1)));
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('pedidos').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              final allDocs = snapshot.data!.docs;
              final filteredDocs = allDocs.where((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final ts = data['createdAt'] as Timestamp?;
                if (ts == null || !_isDateInRange(ts.toDate())) return false;
                if (_paymentFilter != 'Todos' && data['metodo_pago'] != _paymentFilter) return false;
                if (_statusFilter != 'Todos' && data['estado'] != _statusFilter) return false;
                return true;
              }).toList();

              double totalV = 0;
              for (var d in filteredDocs) totalV += ((d.data() as Map<String, dynamic>)['total'] ?? 0).toDouble();
              double totalC = (totalV * _commissionPercent) / 100;

              return Column(
                children: [
                  _buildStatsRow(totalV, filteredDocs.length, totalC),
                  Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 30), child: _buildTableContainer(filteredDocs))),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(30),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              Text("Dashboard Administrativo", style: GoogleFonts.montserrat(fontSize: 22, fontWeight: FontWeight.bold)),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => _exportToPdf(context),
                icon: const Icon(Icons.picture_as_pdf), label: const Text("Exportar Liquidación"),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              _buildFilterLabel("Fecha:"),
              _buildChip("Hoy"), _buildChip("Mes Actual"), _buildChip("Personalizado"),
              const SizedBox(width: 30),
              _buildFilterLabel("Pago:"),
              _buildDropdown(['Todos', 'Efectivo', 'Mercado Pago'], _paymentFilter, (v) => setState(() => _paymentFilter = v!)),
              const SizedBox(width: 30),
               _buildFilterLabel("Estado:"),
              _buildDropdown(['Todos', 'Pendiente', 'Confirmado', 'Finalizado', 'rechazado'], _statusFilter, (v) => setState(() => _statusFilter = v!)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildFilterLabel(String t) => Padding(padding: const EdgeInsets.only(right: 15), child: Text(t, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey)));
  
  Widget _buildChip(String label) {
    bool sel = _dateFilter == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 11, fontWeight: sel ? FontWeight.bold : FontWeight.normal)),
        selected: sel,
        onSelected: (val) async {
          if (label == 'Personalizado') {
            final p = await showDateRangePicker(context: context, firstDate: DateTime(2024), lastDate: DateTime(2100));
            if (p != null) setState(() { _customRange = p; _dateFilter = label; });
          } else setState(() => _dateFilter = label);
        },
      ),
    );
  }

  Widget _buildDropdown(List<String> items, String cur, Function(String?) s) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12), decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
      child: DropdownButtonHideUnderline(child: DropdownButton<String>(value: cur, items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 12)))).toList(), onChanged: s)),
    );
  }

  Widget _buildStatsRow(double v, int c, double com) {
    return Padding(padding: const EdgeInsets.all(30), child: Row(children: [
      _statCard("VENTAS PERIODO", _formatMoney(v), Icons.wallet, Colors.blue),
      const SizedBox(width: 25),
      _statCard("ORDENES", c.toString(), Icons.shopping_cart, Colors.teal),
      const SizedBox(width: 25),
      _statCard("COMISIÓN (5%)", _formatMoney(com), Icons.monetization_on, Colors.orange),
    ]));
  }

  Widget _statCard(String t, String v, IconData i, Color c) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(25), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.black.withOpacity(0.05))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(i, color: c, size: 20)),
        const SizedBox(height: 15),
        Text(t, style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 5),
        Text(v, style: GoogleFonts.montserrat(fontSize: 26, fontWeight: FontWeight.w900)),
      ]),
    ));
  }

  Widget _buildTableContainer(List<QueryDocumentSnapshot> docs) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: const BorderRadius.vertical(top: Radius.circular(24)), border: Border.all(color: Colors.black.withOpacity(0.05))),
      child: ClipRRect(borderRadius: const BorderRadius.vertical(top: Radius.circular(24)), child: SingleChildScrollView(child: DataTable(
        headingRowHeight: 60, horizontalMargin: 30, columnSpacing: 40,
        columns: [ DataColumn(label: _th("CLIENTE")), DataColumn(label: _th("FECHA")), DataColumn(label: _th("PAGO")), DataColumn(label: _th("ESTADO")), DataColumn(label: _th("TOTAL")), DataColumn(label: _th("COMISIÓN")) ],
        rows: docs.map((d) {
          final data = d.data() as Map<String, dynamic>;
          return DataRow(cells: [
            DataCell(Text(data['nombre_cliente'] ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.w600))),
            DataCell(Text(DateFormat('dd/MM HH:mm').format((data['createdAt'] as Timestamp).toDate()))),
            DataCell(Text(data['metodo_pago'] ?? 'Efectivo')),
            DataCell(_statusBadge(data['estado'] ?? 'Pendiente')),
            DataCell(Text(_formatMoney((data['total'] ?? 0).toDouble()), style: const TextStyle(fontWeight: FontWeight.bold))),
            DataCell(Text(_formatMoney((data['total'] ?? 0) * 0.05), style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold))),
          ]);
        }).toList(),
      ))),
    );
  }

  Widget _th(String t) => Text(t, style: GoogleFonts.montserrat(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.blueGrey));
  
  Widget _statusBadge(String s) {
    Color c = Colors.orange;
    if (s == 'Finalizado') c = Colors.green;
    if (s == 'rechazado' || s == 'Cancelado') c = Colors.red;
    return Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(30)), child: Text(s.toUpperCase(), style: TextStyle(color: c, fontSize: 9, fontWeight: FontWeight.bold)));
  }

  String _formatMoney(double v) => "\$${v.toStringAsFixed(2).replaceAll('.', ',')}";
  
  Future<void> _exportToPdf(BuildContext context) async {
    final pdf = pw.Document();
    pdf.addPage(pw.Page(build: (c) => pw.Center(child: pw.Text("Liquidación", style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)))));
    await Printing.layoutPdf(onLayout: (fmt) async => pdf.save());
  }
}

class BusinessesPage extends StatelessWidget {
  const BusinessesPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Column(children: [
       _buildBusinessHeader(context),
       Expanded(child: StreamBuilder<QuerySnapshot>(
         stream: FirebaseFirestore.instance.collection('configuracion_negocio').snapshots(),
         builder: (context, snapshot) {
           if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
           final docs = snapshot.data?.docs ?? [];
           if (docs.isEmpty) return _buildEmptyState(context);
           return ListView.separated(
             padding: const EdgeInsets.all(30), itemCount: docs.length, separatorBuilder: (c, i) => const SizedBox(height: 20),
             itemBuilder: (context, index) {
               return _buildBusinessCard(context, docs[index].id, docs[index].data() as Map<String, dynamic>);
             },
           );
         },
       )),
    ]);
  }

  Widget _buildBusinessHeader(BuildContext context) {
    return Container(padding: const EdgeInsets.all(30), color: Colors.white, child: Row(children: [
       Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
         Text("Gestión de Negocios", style: GoogleFonts.montserrat(fontSize: 24, fontWeight: FontWeight.w900)),
         Text("Los negocios aparecen automáticamente al configurar su App Comercio", style: TextStyle(color: Colors.grey[500])),
       ]),
       const Spacer(),
       TextButton.icon(onPressed: () => _discover(context), icon: const Icon(Icons.search), label: const Text("Vincular Local Actual")),
    ]));
  }

  Widget _buildBusinessCard(BuildContext context, String id, Map<String, dynamic> data) {
    final bool activo = data['activo'] ?? true;
    final String pago = data['estado_pago'] ?? 'Pendiente';
    final double deuda = (data['deuda_acumulada'] ?? 0.0).toDouble();
    return Container(
      padding: const EdgeInsets.all(25), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.black.withOpacity(0.05))),
      child: Row(children: [
         const CircleAvatar(backgroundColor: Color(0xFFF1F5F9), child: Icon(Icons.storefront, color: Colors.blueAccent)),
         const SizedBox(width: 20),
         Expanded(child: Text(data['nombre'] ?? id, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
         Column(children: [
           const Text("DEUDA", style: TextStyle(fontSize: 10, color: Colors.grey)),
           Text("\$${deuda.toStringAsFixed(0)}", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: deuda > 0 ? Colors.red : Colors.green)),
         ]),
         const SizedBox(width: 30),
         Column(children: [
           Switch(value: activo, onChanged: (v) => FirebaseFirestore.instance.collection('configuracion_negocio').doc(id).update({'activo': v}), activeColor: Colors.green, inactiveThumbColor: Colors.red),
           Text(activo ? "ACTIVO" : "SUSPENDIDO", style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: activo ? Colors.green : Colors.red)),
         ]),
         const SizedBox(width: 20),
         IconButton(onPressed: () {
           FirebaseFirestore.instance.collection('configuracion_negocio').doc(id).update({'estado_pago': 'Pagado', 'deuda_acumulada': 0});
         }, icon: const Icon(Icons.check_circle, color: Colors.green)),
      ]),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.auto_awesome, size: 80, color: Colors.blueAccent.withOpacity(0.2)),
      const SizedBox(height: 20),
      const Text("ESPERANDO VINCULACIÓN", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      const Padding(padding: EdgeInsets.all(20), child: Text("Cuando un local configure su App Comercio, aparecerá aquí.", textAlign: TextAlign.center)),
      ElevatedButton(onPressed: () => _discover(context), child: const Text("VINCULAR LOCAL ACTUAL")),
    ]));
  }

  void _discover(BuildContext context) async {
    final snap = await FirebaseFirestore.instance.collection('config').doc('datos_local').get();
    if (!snap.exists) return;
    final nombre = snap.data()!['nombre'] ?? 'Local';
    final id = nombre.toLowerCase().replaceAll(' ', '_');
    await FirebaseFirestore.instance.collection('configuracion_negocio').doc(id).set({
      'nombre': nombre, 'activo': true, 'estado_pago': 'Pendiente', 'deuda_acumulada': 0,
    }, SetOptions(merge: true));
  }
}

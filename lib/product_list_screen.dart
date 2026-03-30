import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  
  bool _isSpecial = false;
  bool _isAvailable = true;
  String? _editingId;
  String? _currentImageUrl;
  File? _imageFile;
  bool _isUploading = false;
  
  Map<String, dynamic>? _preciosConfig;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadPreciosConfig();
  }

  void _loadPreciosConfig() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('configuracion_local').doc('precios').get();
      if (doc.exists) setState(() => _preciosConfig = doc.data());
    } catch (e) { debugPrint("Error: $e"); }
  }

  Future<void> _pickImage(StateSetter setModalState) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 20, maxWidth: 450);
      if (pickedFile != null) {
        setModalState(() => _imageFile = File(pickedFile.path));
        setState(() => _imageFile = File(pickedFile.path));
      }
    } catch (e) { _showError("Error imagen: $e"); }
  }

  // Lógica funcional para Borrar Producto
  void _deleteProduct(String id) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("¿Eliminar Ítem?", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        content: const Text("Esta acción borrará el ítem de la carta permanentemente."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCELAR")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("BORRAR", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      await FirebaseFirestore.instance.collection('productos').doc(id).delete();
      if (mounted) {
        Navigator.pop(context); // Cierra el modal de edición
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Item eliminado correctamente")));
      }
    }
  }

  void _showProductModal({String? id, Map<String, dynamic>? data, String? category}) {
    final String activeCategory = category ?? (data != null ? data['categoria'] : 'Pizza');
    if (id != null && data != null) {
      _editingId = id;
      _nameController.text = data['nombre'] ?? '';
      _descController.text = data['descripcion'] ?? '';
      _priceController.text = (data['precio'] ?? '').toString();
      _isSpecial = data['is_especial'] ?? false;
      _isAvailable = data['disponible'] ?? true;
      _currentImageUrl = data['foto_url'];
      _imageFile = null;
    } else {
      _editingId = null;
      _nameController.clear();
      _descController.clear();
      _priceController.clear();
      _isSpecial = false;
      _isAvailable = true;
      _currentImageUrl = null;
      _imageFile = null;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, top: 20, left: 25, right: 25),
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                   Center(child: Container(width: 45, height: 4, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 15),
                  Text(_editingId == null ? "Nuevo Ítem: $activeCategory" : "Editar Ítem: $activeCategory", 
                    style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFFFF7F50)), textAlign: TextAlign.center),
                  const SizedBox(height: 15),
                  Center(
                    child: GestureDetector(
                      onTap: () => _pickImage(setModalState),
                      child: Container(
                        height: 90, width: 90,
                        decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.orange.withOpacity(0.1))),
                        clipBehavior: Clip.antiAlias,
                        child: _imageFile != null ? Image.file(_imageFile!, fit: BoxFit.cover) : _buildImageWidget(_currentImageUrl, Icons.add_a_photo, size: 25),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  _buildInput(activeCategory == 'Oferta' ? "Nombre del Combo" : _getInputLabel(activeCategory), _nameController, Icons.fastfood),
                  if (activeCategory == 'Pizza' || activeCategory == 'Empanada')
                    SwitchListTile(
                      title: Text("¿Variedad Especial?", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 13)),
                      value: _isSpecial, activeColor: Colors.amber[700],
                      secondary: Icon(Icons.star, color: _isSpecial ? Colors.amber[700] : Colors.grey[200]),
                      onChanged: (val) { setModalState(() => _isSpecial = val); setState(() => _isSpecial = val); },
                    ),
                  if (activeCategory != 'Empanada')
                    _buildInput("Precio Actual (\$)", _priceController, Icons.attach_money, isNumeric: true)
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text("Precio automático (Central de Precios).", 
                        style: GoogleFonts.montserrat(color: Colors.grey[500], fontSize: 11, fontStyle: FontStyle.italic), textAlign: TextAlign.center),
                    ),
                  _buildInput(activeCategory == 'Oferta' ? "Items unidos con +" : "Descripción corta", _descController, Icons.description),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    title: Text("Producto Disponible", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 13, color: _isAvailable ? Colors.green[800] : Colors.red[800])),
                    subtitle: Text(_isAvailable ? "Los clientes pueden pedirlo" : "Aparecerá como AGOTADO", style: GoogleFonts.montserrat(fontSize: 11)),
                    value: _isAvailable,
                    activeColor: Colors.green,
                    secondary: Icon(_isAvailable ? Icons.check_circle : Icons.do_not_disturb_on, color: _isAvailable ? Colors.green : Colors.red),
                    onChanged: (val) { setModalState(() => _isAvailable = val); setState(() => _isAvailable = val); },
                  ),
                  const SizedBox(height: 15),
                  ElevatedButton(
                    onPressed: _isUploading ? null : () => _saveProduct(setModalState, activeCategory),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF7F50), padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                    child: _isUploading 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(_editingId == null ? "CARGAR A LA CARTA" : "GUARDAR CAMBIOS", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                  // Botón de Borrado solo si estamos editando
                  if (_editingId != null) 
                    TextButton.icon(
                      onPressed: () => _deleteProduct(_editingId!),
                      icon: const Icon(Icons.delete_forever, color: Colors.red),
                      label: Text("BORRAR PRODUCTO 🗑️", style: GoogleFonts.montserrat(color: Colors.red, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  String _getInputLabel(String category) {
    switch (category) {
      case 'Empanada': return "Sabor de Empanada";
      case 'Bebida': return "Ej: Coca Cola 1.5L";
      case 'Postre': return "Ej: Tiramisú de la casa";
      default: return "Nombre del Producto";
    }
  }

  void _saveProduct(StateSetter setModalState, String activeCategory) async {
    if (_nameController.text.isEmpty) return;
    setModalState(() => _isUploading = true);
    setState(() => _isUploading = true);
    String? imageData = _currentImageUrl;
    try {
      if (_imageFile != null) {
        final bytes = await _imageFile!.readAsBytes();
        imageData = base64Encode(bytes);
      }
      final data = {
        'nombre': _nameController.text.trim(),
        'descripcion': _descController.text.trim(),
        'precio': activeCategory == 'Empanada' ? 0 : (double.tryParse(_priceController.text) ?? 0),
        'categoria': activeCategory,
        'is_especial': (activeCategory == 'Pizza' || activeCategory == 'Empanada') ? _isSpecial : false, 
        'disponible': _isAvailable,
        'foto_url': imageData,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (_editingId == null) {
        data['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('productos').add(data);
      } else {
        await FirebaseFirestore.instance.collection('productos').doc(_editingId).update(data);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) { _showError("Error: $e"); } finally {
      if (mounted) { setModalState(() => _isUploading = false); setState(() => _isUploading = false); }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      appBar: AppBar(
        title: Text("Mi Carta Digital", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: const Color(0xFFFF7F50),
          labelColor: const Color(0xFFFF7F50),
          tabs: const [ Tab(text: "OFERTAS"), Tab(text: "PIZZAS"), Tab(text: "EMPANADAS"), Tab(text: "BEBIDAS"), Tab(text: "POSTRES") ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [ _buildTabContent('Oferta'), _buildTabContent('Pizza'), _buildTabContent('Empanada'), _buildTabContent('Bebida'), _buildTabContent('Postre') ] 
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProductModal(category: ['Oferta', 'Pizza', 'Empanada', 'Bebida', 'Postre'][_tabController.index]), 
        backgroundColor: const Color(0xFFFF7F50), child: const Icon(Icons.add, color: Colors.white)
      ),
    );
  }

  Widget _buildTabContent(String category) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('productos').where('categoria', isEqualTo: category).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return Center(child: Text("Sin ítems en $category", style: GoogleFonts.montserrat(color: Colors.grey, fontSize: 12)));

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final prod = doc.data() as Map<String, dynamic>;
            final bool especial = prod['is_especial'] ?? false;
            final bool isOferta = category == 'Oferta';
            final bool disponible = prod['disponible'] ?? true;
            
            String priceLabel = "";
            if (category == 'Empanada') {
              priceLabel = especial ? "\$${_preciosConfig?['unidad_especial'] ?? '--'}" : "\$${_preciosConfig?['unidad_comun'] ?? '--'}";
            } else {
              priceLabel = "\$${prod['precio'] ?? '--'}";
            }

            if (isOferta) {
              return GestureDetector(
                onTap: () => _showProductModal(id: doc.id, data: prod),
                child: Opacity(
                  opacity: disponible ? 1.0 : 0.6,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 15),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white, borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: disponible ? Colors.red[400]! : Colors.grey, width: 1.5),
                      boxShadow: [BoxShadow(color: (disponible ? Colors.red : Colors.grey).withOpacity(0.06), blurRadius: 10)]
                    ),
                    child: Stack(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 80, height: 80,
                              decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(15)),
                              clipBehavior: Clip.antiAlias,
                              child: _buildImageWidget(prod['foto_url'], Icons.local_offer, size: 30),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(prod['nombre'], style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black)),
                                  const SizedBox(height: 6),
                                  ..._buildOfertaLines(prod['descripcion'] ?? ""),
                                  const SizedBox(height: 8),
                                  Align(
                                    alignment: Alignment.bottomRight,
                                    child: Text(priceLabel, style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, color: disponible ? Colors.red : Colors.grey, fontSize: 22)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (!disponible)
                          Positioned(
                            top: 0, right: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(8)),
                              child: Text("AGOTADO", style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return Opacity(
              opacity: disponible ? 1.0 : 0.6,
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white, borderRadius: BorderRadius.circular(15), 
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8)],
                  border: !disponible ? Border.all(color: Colors.red.withOpacity(0.3), width: 1) : null,
                ),
                child: ListTile(
                  onTap: () => _showProductModal(id: doc.id, data: prod),
                  leading: Stack(
                    children: [
                      Container(
                        width: 50, height: 50,
                        decoration: BoxDecoration(color: const Color(0xFFFF7F50).withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
                        clipBehavior: Clip.antiAlias,
                        child: _buildImageWidget(prod['foto_url'], Icons.restaurant),
                      ),
                      if (!disponible)
                        Positioned.fill(child: Container(color: Colors.black26, child: const Center(child: Icon(Icons.block, color: Colors.white, size: 20)))),
                    ],
                  ),
                  title: Row(
                    children: [
                      Text(prod['nombre'], style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 14)),
                      if (especial) Container(margin: const EdgeInsets.only(left: 4), padding: const EdgeInsets.all(2), decoration: BoxDecoration(color: Colors.amber[100], borderRadius: BorderRadius.circular(4)), child: const Text("⭐", style: TextStyle(fontSize: 8))),
                      if (!disponible) Container(margin: const EdgeInsets.only(left: 8), padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)), child: Text("AGOTADO", style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 8))),
                    ],
                  ),
                  subtitle: Text(prod['descripcion'] ?? "", style: GoogleFonts.montserrat(fontSize: 11), maxLines: 1),
                  trailing: Text(priceLabel, style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: disponible ? const Color(0xFFFF7F50) : Colors.grey, fontSize: 15)),
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<Widget> _buildOfertaLines(String desc) {
    final List<String> lines = desc.split(RegExp(r'\s*\+\s*'));
    return lines.map((line) {
      String emoji = "✨";
      String lower = line.toLowerCase();
      if (lower.contains("pizza")) emoji = "🍕";
      else if (lower.contains("empanada")) emoji = "🥟";
      else if (lower.contains("coca") || lower.contains("bebida") || lower.contains("cerveza") || lower.contains("sprite")) emoji = "🥤";
      else if (lower.contains("helado") || lower.contains("postre")) emoji = "🍰";

      return Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 10)),
            const SizedBox(width: 6),
            Expanded(child: Text(line.trim(), style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey[700]), maxLines: 1, overflow: TextOverflow.ellipsis)),
          ],
        ),
      );
    }).toList();
  }

  Widget _buildImageWidget(String? imageData, IconData fallbackIcon, {double size = 25}) {
    if (imageData == null || imageData.isEmpty) return Center(child: Icon(fallbackIcon, color: const Color(0xFFFF7F50), size: size));
    try { return Image.memory(base64Decode(imageData), fit: BoxFit.cover, errorBuilder: (c, e, s) => Center(child: Icon(fallbackIcon, size: size)));
    } catch (e) { return Center(child: Icon(fallbackIcon, size: size)); }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  Widget _buildInput(String label, TextEditingController controller, IconData icon, {bool isNumeric = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
        style: GoogleFonts.montserrat(fontSize: 14),
        decoration: _inputDecoration(label, icon),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFFFF7F50).withOpacity(0.7), size: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      filled: true, fillColor: Colors.grey[50], 
      contentPadding: const EdgeInsets.symmetric(vertical: 12),
    );
  }
}

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
    _tabController = TabController(length: 4, vsync: this);
    _loadPreciosConfig();
  }

  void _loadPreciosConfig() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('configuracion_local').doc('precios').get();
      if (doc.exists) setState(() => _preciosConfig = doc.data());
    } catch (e) {
      debugPrint("Error: $e");
    }
  }

  Future<void> _pickImage(StateSetter setModalState) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 25, maxWidth: 450);
      if (pickedFile != null) {
        setModalState(() => _imageFile = File(pickedFile.path));
        setState(() => _imageFile = File(pickedFile.path));
      }
    } catch (e) { _showError("Error imagen: $e"); }
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
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, top: 18, left: 25, right: 25),
            decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                   Center(child: Container(width: 45, height: 4, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10)))),
                  const SizedBox(height: 15),
                  Text(_editingId == null ? "Nuevo Item: $activeCategory" : "Editar Item: $activeCategory", 
                    style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFFFF7F50)), textAlign: TextAlign.center),
                  const SizedBox(height: 15),
                  
                  Center(
                    child: GestureDetector(
                      onTap: () => _pickImage(setModalState),
                      child: Container(
                        height: 90, width: 90,
                        decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.orange.withOpacity(0.1))),
                        clipBehavior: Clip.antiAlias,
                        child: _imageFile != null ? Image.file(_imageFile!, fit: BoxFit.cover) : _buildImageWidget(_currentImageUrl, Icons.add_a_photo, size: 22),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  _buildInput(activeCategory == 'Bebida' ? "Ej: Coca Cola 1.5L" : (activeCategory == 'Empanada' ? "Sabor (Carne, etc)" : "Nombre del Item"), _nameController, Icons.fastfood),
                  
                  // ELIMINADO SWITCH ESPECIAL SOLO PARA BEBIDAS
                  if (activeCategory != 'Bebida')
                    SwitchListTile(
                      title: Text("¿Variedad Especial?", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text(_isSpecial ? "Marcado como Premium ⭐" : "Versión Estándar", style: GoogleFonts.montserrat(fontSize: 11)),
                      value: _isSpecial,
                      activeColor: Colors.amber[700],
                      secondary: Icon(Icons.star, color: _isSpecial ? Colors.amber[700] : Colors.grey[200]),
                      onChanged: (val) {
                        setModalState(() => _isSpecial = val);
                        setState(() => _isSpecial = val);
                      },
                    ),

                  // Lógica de precios: Solo si NO es Empanada
                  if (activeCategory != 'Empanada')
                    _buildInput("Precio Unitario (\$)", _priceController, Icons.attach_money, isNumeric: true)
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text("Precio automático según Configuración Local.", 
                        style: GoogleFonts.montserrat(color: Colors.grey[500], fontSize: 11, fontStyle: FontStyle.italic), textAlign: TextAlign.center),
                    ),

                  _buildInput("Descripción (opcional)", _descController, Icons.description),

                  const SizedBox(height: 15),
                  ElevatedButton(
                    onPressed: _isUploading ? null : () => _saveProduct(setModalState, activeCategory),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF7F50), padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                    child: _isUploading 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(_editingId == null ? "AGREGAR A MI CARTA" : "ACTUALIZAR ÍTEM", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ],
              ),
            ),
          );
        }
      ),
    );
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
        'is_especial': activeCategory == 'Bebida' ? false : _isSpecial, // Forzamos false para Bebidas
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
          tabs: const [ Tab(text: "PIZZAS"), Tab(text: "EMPANADAS"), Tab(text: "BEBIDAS"), Tab(text: "POSTRES") ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [ _buildTabContent('Pizza'), _buildTabContent('Empanada'), _buildTabContent('Bebida'), _buildTabContent('Postre') ] 
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showProductModal(category: ['Pizza', 'Empanada', 'Bebida', 'Postre'][_tabController.index]), 
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
        if (docs.isEmpty) return Center(child: Text("No hay items en $category", style: GoogleFonts.montserrat(color: Colors.grey, fontSize: 12)));

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final prod = doc.data() as Map<String, dynamic>;
            final bool especial = prod['is_especial'] ?? false;
            
            String priceLabel = "";
            if (category == 'Empanada') {
              priceLabel = especial ? "\$${_preciosConfig?['unidad_especial'] ?? '--'}" : "\$${_preciosConfig?['unidad_comun'] ?? '--'}";
            } else {
              priceLabel = "\$${prod['precio'] ?? '--'}";
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6)]),
              child: ListTile(
                onTap: () => _showProductModal(id: doc.id, data: prod),
                leading: Container(
                  width: 45, height: 45,
                  decoration: BoxDecoration(color: const Color(0xFFFF7F50).withOpacity(0.05), borderRadius: BorderRadius.circular(10)),
                  clipBehavior: Clip.antiAlias,
                  child: _buildImageWidget(prod['foto_url'], Icons.restaurant),
                ),
                title: Row(
                  children: [
                    Text(prod['nombre'], style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 13)),
                    if (especial) Container(margin: const EdgeInsets.only(left: 4), padding: const EdgeInsets.all(2), decoration: BoxDecoration(color: Colors.amber[100], borderRadius: BorderRadius.circular(4)), child: Text("⭐", style: TextStyle(fontSize: 8))),
                  ],
                ),
                subtitle: Text(prod['descripcion'] ?? "", style: GoogleFonts.montserrat(fontSize: 10), maxLines: 1),
                trailing: Text(priceLabel, style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, color: const Color(0xFFFF7F50), fontSize: 14)),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildImageWidget(String? imageData, IconData fallbackIcon, {double size = 22}) {
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
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
        style: GoogleFonts.montserrat(fontSize: 13),
        decoration: _inputDecoration(label, icon),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFFFF7F50).withOpacity(0.7), size: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      filled: true, fillColor: Colors.grey[50], 
      contentPadding: const EdgeInsets.symmetric(vertical: 10),
    );
  }
}

import 'dart:ui';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'order_status_screen.dart';
import 'floating_cart_widget.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:whatsapp_share2/whatsapp_share2.dart';

class ClientCartaScreen extends StatefulWidget {
  const ClientCartaScreen({super.key});

  @override
  State<ClientCartaScreen> createState() => _ClientCartaScreenState();
}

class _ClientCartaScreenState extends State<ClientCartaScreen> with SingleTickerProviderStateMixin {
  final Map<String, int> _carrito = {};
  Map<String, dynamic>? _preciosConfig;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _restaurarPedidoEdicion();
    _initOrderStatusListener();
  }

  void _addToCart(String id) {
    setState(() {
      _carrito[id] = (_carrito[id] ?? 0) + 1;
    });
  }

  void _removeFromCart(String id) {
    setState(() {
      if ((_carrito[id] ?? 0) > 1) {
        _carrito[id] = _carrito[id]! - 1;
      } else {
        _carrito.remove(id);
      }
    });
  }

  double _calculateTotal(List<QueryDocumentSnapshot> allProducts) {
    double total = 0;
    _carrito.forEach((id, qty) {
      try {
        final doc = allProducts.firstWhere((d) => d.id == id);
        final data = doc.data() as Map<String, dynamic>? ?? {};
        total += _getRawPrice(data) * qty;
      } catch (e) {
        debugPrint("Error calculando total para $id: $e");
      }
    });
    return total;
  }

  double _getRawPrice(Map<String, dynamic> prod) {
    if (prod['categoria'] == 'Empanada') {
      final bool esEspecial = prod['is_especial'] == true;
      if (_preciosConfig == null) return 0.0;
      final dynamic value = esEspecial 
          ? _preciosConfig!['unidad_especial'] 
          : _preciosConfig!['unidad_comun'];
      return (value as num?)?.toDouble() ?? 0.0;
    }
    final dynamic p = prod['precio'];
    return (p as num?)?.toDouble() ?? 0.0;
  }

  /// Solo dígitos, prefijo Argentina 549 para wa.me / WhatsappShare.
  String _normalizeWhatsappArgentinaDigits(String raw) {
    String clean = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.startsWith('0')) clean = clean.substring(1);
    if (clean.startsWith('15') && clean.length > 8) clean = clean.substring(2);
    if (clean.isEmpty) return '';
    if (!clean.startsWith('54')) {
      clean = '549$clean';
    } else if (clean.startsWith('54') && !clean.startsWith('549')) {
      clean = '549${clean.substring(2)}';
    }
    return clean;
  }

  Future<String> _resolveWhatsappComercioDigits() async {
    String raw = (_preciosConfig?['whatsapp_comprobantes'] ?? '').toString().trim();
    if (raw.isEmpty) {
      try {
        final doc = await FirebaseFirestore.instance.collection('configuracion_negocio').doc('contacto').get();
        raw = (doc.data()?['whatsapp_comprobantes'] ?? '').toString().trim();
      } catch (e) {
        debugPrint('WhatsApp contacto fallback: $e');
      }
    }
    return _normalizeWhatsappArgentinaDigits(raw);
  }

  /// Copia el comprobante a ruta bajo caché o almacenamiento externo de la app (paths del FileProvider).
  Future<File> _ensureComprobanteForContentShare(File source) async {
    Directory dir;
    try {
      final ext = await getExternalStorageDirectory();
      dir = ext ?? await getTemporaryDirectory();
    } catch (_) {
      dir = await getTemporaryDirectory();
    }
    final dest = File('${dir.path}/comprobante_mp_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await source.copy(dest.path);
    return dest;
  }

  Future<void> _restaurarPedidoEdicion() async {
    final prefs = await SharedPreferences.getInstance();
    final String? lastOrderId = prefs.getString('lastOrderId');
    if (lastOrderId == null) return;

    try {
      final doc = await FirebaseFirestore.instance.collection('pedidos').doc(lastOrderId).get();
      if (doc.exists && doc.data()?['estado'] == 'modificando') {
        final List items = doc.data()?['productos'] ?? [];
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
    }
  }

  void _enviarPedidoDirecto() async {
    final String aliasMp = (_preciosConfig?['alias_mp'] ?? '').toString().trim();
    if (aliasMp.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: aliasMp));
    }
    
    if (!_checkStatus()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("LO SENTIMOS - Estamos Cerrados en este momento.", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.red[800],
        )
      );
      return;
    }
    
    final prefs = await SharedPreferences.getInstance();
    final String initialAddress = prefs.getString('userAddress') ?? 'Retiro por el local';
    
    final productDocs = await FirebaseFirestore.instance.collection('productos').get();
    final allProducts = productDocs.docs;
    
    double subtotal = 0;
    String detalleText = "";
    List<Map<String, dynamic>> productosData = [];

    _carrito.forEach((id, qty) {
      try {
        final doc = allProducts.firstWhere((d) => d.id == id);
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final double price = _getRawPrice(data);
        subtotal += price * qty;
        detalleText += "• $qty ${data['nombre']}\n";
        productosData.add({
          'id': id,
          'nombre': data['nombre'],
          'cantidad': qty,
          'precio_unitario': price,
        });
      } catch (e) {
        debugPrint("Error procesando producto $id: $e");
      }
    });

    if (productosData.isEmpty) return;
    _showConfirmOrderPremium(subtotal, detalleText, productosData, initialAddress);
  }

  void _showConfirmOrderPremium(double subtotal, String detalle, List<Map<String, dynamic>> productos, String currentAddress) {
    TextEditingController addressCtrl = TextEditingController(text: currentAddress);
    TextEditingController cashAmountCtrl = TextEditingController();
    
    bool isCapturingGps = false;
    double? lat;
    double? long;
    String metodoPago = "Efectivo";
    File? comprobanteFile;
    bool aliasCopied = false; // feedback visual inmediato al tocar MP

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.all(25),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("CONFIRMAR ENTREGA", style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 16, letterSpacing: 1.5)),
                      const SizedBox(height: 20),
                      
                      TextField(
                        controller: addressCtrl,
                        style: GoogleFonts.montserrat(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          labelText: "Dirección de Envío",
                          labelStyle: GoogleFonts.montserrat(color: Colors.white70, fontSize: 12),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      InkWell(
                        onTap: () async {
                          setDialogState(() => isCapturingGps = true);
                          try {
                            LocationPermission p = await Geolocator.requestPermission();
                            if (p == LocationPermission.deniedForever) throw "GPS deshabilitado";
                            Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high, timeLimit: const Duration(seconds: 15));
                            lat = pos.latitude; long = pos.longitude;
                            try {
                              List<Placemark> placemarks = await placemarkFromCoordinates(lat!, long!);
                              if (placemarks.isNotEmpty) {
                                addressCtrl.text = "${placemarks[0].street}";
                              }
                            } catch (_) { 
                              addressCtrl.text = "📍 Ubicación GPS Confirmada";
                            }
                            setDialogState(() => isCapturingGps = false);
                          } catch (e) {
                            setDialogState(() => isCapturingGps = false);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.gps_fixed, color: isCapturingGps ? const Color(0xFFFF7F50) : Colors.white70, size: 16),
                              const SizedBox(width: 8),
                              Text(isCapturingGps ? "LOCALIZANDO..." : "USAR MI UBICACIÓN ACTUAL", style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 25),
                      Text("MÉTODO DE PAGO", style: GoogleFonts.montserrat(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 11)),
                      const SizedBox(height: 12),
                      
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setDialogState(() => metodoPago = "Efectivo"),
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: metodoPago == "Efectivo" ? const Color(0xFFFF7F50) : Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(color: metodoPago == "Efectivo" ? Colors.white70 : Colors.transparent)
                                ),
                                child: Center(child: Text("EFECTIVO", style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: GestureDetector(
                                onTap: () {
                                  // Usamos un notice interno en el dialog (mensaje azul solicitado)
                                  setDialogState(() {
                                    metodoPago = "Mercado Pago";
                                    aliasCopied = true;
                                  });
                                  HapticFeedback.mediumImpact();
                                  Clipboard.setData(const ClipboardData(text: "gonzalosc22.uala"));
                                },
                              child: Container(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                decoration: BoxDecoration(
                                  color: metodoPago == "Mercado Pago" ? const Color(0xFF00B1EA) : Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(color: metodoPago == "Mercado Pago" ? Colors.white70 : Colors.transparent)
                                ),
                                child: Center(child: Text("MERCADO PAGO", style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Feedback inmediato: alias copiado
                      if (aliasCopied)
                        Container(
                          margin: const EdgeInsets.only(top: 15),
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))]
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.copy_all, color: Colors.white, size: 18),
                              const SizedBox(width: 10),
                              Text("¡ALIAS COPIADO! Pegalo en MP",
                                style: GoogleFonts.montserrat(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      
                      if (metodoPago == "Efectivo")
                        TextField(
                          controller: cashAmountCtrl,
                          keyboardType: TextInputType.number,
                          style: GoogleFonts.montserrat(color: Colors.white, fontSize: 13),
                          decoration: InputDecoration(
                            labelText: "¿Con cuánto vas a pagar?",
                            labelStyle: GoogleFonts.montserrat(color: Colors.white70, fontSize: 11),
                            filled: true,
                            fillColor: Colors.white.withOpacity(0.05),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                            prefixText: "\$ ", prefixStyle: const TextStyle(color: Colors.white),
                          ),
                        )
                      else ...[
                        // ── DATOS DE PAGO ──
                        GestureDetector(
                          onTap: () {
                            final a = (_preciosConfig?['alias_mp'] ?? '').toString().trim();
                            if (a.isNotEmpty) Clipboard.setData(ClipboardData(text: a));
                            setDialogState(() => aliasCopied = true);
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("¡Alias copiado!"), duration: Duration(seconds: 1)));
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.blue.withOpacity(0.4)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  () {
                                    final a = (_preciosConfig?['alias_mp'] ?? '').toString().trim();
                                    return "ALIAS: ${a.isEmpty ? '—' : a}";
                                  }(),
                                  style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // ── ADJUNTAR COMPROBANTE ──
                        GestureDetector(
                          onTap: () async {
                            final picker = ImagePicker();
                            final XFile? picked = await picker.pickImage(
                              source: ImageSource.gallery,
                              imageQuality: 60,
                              maxWidth: 1080,
                            );
                            if (picked != null) {
                              // CORRECCIÓN TÉCNICA: Copia de Seguridad inmediata a Temporal
                              try {
                                final tempDir = await getTemporaryDirectory();
                                final String fileName = "comprobante_${DateTime.now().millisecondsSinceEpoch}.jpg";
                                final File safeCopy = await File(picked.path).copy('${tempDir.path}/$fileName');
                                setDialogState(() => comprobanteFile = safeCopy);
                              } catch (e) {
                                debugPrint("Error copying file: $e");
                                setDialogState(() => comprobanteFile = File(picked.path));
                              }
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: comprobanteFile != null ? Colors.greenAccent : Colors.white30,
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                // Thumbnail si hay imagen
                                if (comprobanteFile != null) ...[
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(comprobanteFile!, width: 48, height: 48, fit: BoxFit.cover),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text("Comprobante listo ✅", style: GoogleFonts.montserrat(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 11)),
                                        Text("Tocá para cambiar", style: GoogleFonts.montserrat(color: Colors.white54, fontSize: 9)),
                                      ],
                                    ),
                                  ),
                                ] else ...[
                                  const Icon(Icons.camera_alt_outlined, color: Colors.white70, size: 20),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text("📷 Adjuntar Comprobante de Pago", style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                                  ),
                                  Text("Opcional", style: GoogleFonts.montserrat(color: Colors.white38, fontSize: 9)),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                      
                      const SizedBox(height: 30),
                      ElevatedButton(
                        onPressed: () {
                          if (metodoPago == "Mercado Pago" && comprobanteFile == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text("Adjuntá el comprobante de Mercado Pago para confirmar.", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
                                backgroundColor: Colors.orange[800],
                              ),
                            );
                            return;
                          }
                          _enviarFinal(subtotal, detalle, productos, addressCtrl.text, lat, long, metodoPago, cashAmountCtrl.text, comprobanteFile);
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFF7F50), minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                        child: Text("CONFIRMAR PEDIDO", style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _enviarFinal(double subtotal, String detalle, List<Map<String, dynamic>> productos, String finalAddress, double? lat, double? long, String metodo, String pagaCon, [File? comprobante]) async {
    if (metodo == "Mercado Pago" && comprobante == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Adjuntá el comprobante de Mercado Pago para confirmar.", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.orange[800],
        ),
      );
      return;
    }

    final String finalNumber = await _resolveWhatsappComercioDigits();
    if (finalNumber.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Falta el WhatsApp del comercio. Configuralo en la app de administración.",
            style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
          ),
          backgroundColor: Colors.red[800],
        ),
      );
      return;
    }

    if (!mounted) return;
    Navigator.pop(context);

    final prefs = await SharedPreferences.getInstance();
    final String userPhone = prefs.getString('userPhone') ?? 'Desconocido';
    final String userName = prefs.getString('userName') ?? 'Cliente';

    double envio = finalAddress.toLowerCase().contains("retiro") ? 0 : (_preciosConfig?['v_envio_barrio'] ?? 0).toDouble();
    double totalOrder = subtotal + envio;

    try {
      String? comprobanteBase64;
      if (comprobante != null) {
        try {
          final bytes = await comprobante.readAsBytes();
          comprobanteBase64 = base64Encode(bytes);
        } catch (e) {
          debugPrint("Error leyendo comprobante: $e");
        }
      }

      final Map<String, dynamic> pData = {
        'cliente': userPhone, 'nombre_cliente': userName, 'productos': productos,
        'subtotal': subtotal, 'costo_envio': envio, 'total': totalOrder,
        'metodo_envio': finalAddress.toLowerCase().contains("retiro") ? "Retiro" : "Barrio",
        'estado': 'Pendiente', 'direccion_entrega': finalAddress,
        'lat_cliente': lat, 'long_cliente': long,
        'metodo_pago': metodo, 'paga_con': pagaCon,
        'comprobante_enviado': comprobanteBase64 != null,
        if (comprobanteBase64 != null) 'comprobante_foto': comprobanteBase64,
        'createdAt': FieldValue.serverTimestamp(), 'updatedAt': FieldValue.serverTimestamp(),
      };

      final docRef = await FirebaseFirestore.instance.collection('pedidos').add(pData);
      await prefs.setString('lastOrderId', docRef.id);

      final String orderID = docRef.id.length > 4 ? docRef.id.substring(docRef.id.length - 4).toUpperCase() : docRef.id.toUpperCase();
      final String mapUrl = (lat != null && long != null)
          ? "https://www.google.com/maps/search/?api=1&query=$lat,$long"
          : "https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(finalAddress)}";

      final String pagoLinea = metodo == "Efectivo"
          ? "EFECTIVO — Paga con: \$$pagaCon"
          : "TRANSFERENCIA - VERIFICAR EN MP";

      final String ticket = "🍕 NUEVO PEDIDO - #$orderID 🍕\n"
          "👤 Cliente: $userName\n"
          "🏠 Dirección: $finalAddress\n"
          "📍 Entrega: ${finalAddress.toLowerCase().contains("retiro") ? "Retiro en local" : "Barrio/Envío"}\n"
          "📝 DETALLE:\n$detalle"
          "🚛 ENVÍO: \$${envio.toStringAsFixed(2)}\n"
          "⭐ TOTAL: \$${totalOrder.toStringAsFixed(2)}\n"
          "💵 PAGO: $pagoLinea\n\n"
          "🌍 VER EN MAPA:\n$mapUrl\n\n"
          "✅ ¡Muchas gracias por elegirnos!";

      if (metodo == "Mercado Pago") {
        final alias = (_preciosConfig?['alias_mp'] ?? '').toString().trim();
        if (alias.isNotEmpty) await Clipboard.setData(ClipboardData(text: alias));
      }

      Future<void> enviarSoloTextoWhatsapp() async {
        final waUri = Uri.parse("whatsapp://send?phone=$finalNumber&text=${Uri.encodeComponent(ticket)}");
        if (await canLaunchUrl(waUri)) {
          await launchUrl(waUri, mode: LaunchMode.externalApplication);
          return;
        }
        final installed = await WhatsappShare.isInstalled(package: Package.whatsapp);
        if (installed == true) {
          await WhatsappShare.share(phone: finalNumber, text: ticket, package: Package.whatsapp);
          return;
        }
        await launchUrl(
          Uri.parse("https://wa.me/$finalNumber?text=${Uri.encodeComponent(ticket)}"),
          mode: LaunchMode.externalApplication,
        );
      }

      if (comprobante != null) {
        final File shareReady = await _ensureComprobanteForContentShare(comprobante);
        try {
          if (!await shareReady.exists()) {
            debugPrint("Comprobante no disponible: ${shareReady.path}");
            await enviarSoloTextoWhatsapp();
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(
                  "Abriendo WhatsApp con tu pedido y la foto…",
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 12),
                ),
                backgroundColor: const Color(0xFF25D366),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ));
            }
            await Future.delayed(const Duration(milliseconds: 500));
            if (Platform.isAndroid) {
              try {
                const ch = MethodChannel('com.mipedido.pizzeria/whatsapp_direct');
                await ch.invokeMethod<void>('sendImageToWhatsApp', <String, String>{
                  'phone': finalNumber,
                  'filePath': shareReady.path,
                  'text': ticket,
                });
              } on PlatformException catch (e) {
                debugPrint('whatsapp_direct nativo: ${e.message}');
                await enviarSoloTextoWhatsapp();
              }
            } else {
              await enviarSoloTextoWhatsapp();
            }
          }
        } catch (e) {
          debugPrint("Error envío WhatsApp con adjunto: $e");
          await enviarSoloTextoWhatsapp();
        }
      } else {
        await enviarSoloTextoWhatsapp();
      }

      if (mounted) {
        setState(() => _carrito.clear());
        Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => OrderStatusScreen(orderId: docRef.id)), (route) => false);
      }
    } catch (e) {
      debugPrint("Error Final: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No se pudo registrar el pedido: $e"), backgroundColor: Colors.red[800]),
        );
      }
    }
  }


  void _initOrderStatusListener() async {
    final prefs = await SharedPreferences.getInstance();
    final String? lastOrderId = prefs.getString('lastOrderId');
    if (lastOrderId == null) return;

    FirebaseFirestore.instance.collection('pedidos').doc(lastOrderId).snapshots().listen((snapshot) async {
      if (!snapshot.exists) return;
      final data = snapshot.data() as Map<String, dynamic>;
      final String newStatus = data['estado'] ?? 'Pendiente';
      final String lastNotified = prefs.getString('notifiedStatus') ?? 'Pendiente';
      
      if (newStatus != lastNotified) {
        await prefs.setString('notifiedStatus', newStatus);
        if (newStatus == 'Cancelado' && mounted) _showRejectionAlert(data['motivo_rechazo'] ?? 'Sin motivo especificado');
      }
    });
  }

  void _showRejectionAlert(String motivo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("❌ Pedido Rechazado", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
        content: Text("Motivo: $motivo"),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("ENTENDIDO"))],
      ),
    );
  }

  bool _checkStatus() {
    if (_preciosConfig == null) return false;
    // Lee 'estado_control' directamente: 0=CERRADO, 1=AUTO(ABIERTO), 2=SIEMPRE ABIERTO
    // Mismo campo que escribe el admin, sin documentos intermedios
    final dynamic ctrl = _preciosConfig!['estado_control'];
    if (ctrl == null) return false;
    return (ctrl as int) != 0;
  }

  String _formatMoney(dynamic value) {
    if (value == null) return "\$0,00";
    double price = (value is num) ? value.toDouble() : (double.tryParse(value.toString().replaceAll(',', '.')) ?? 0.0);
    return "\$${price.toStringAsFixed(2).replaceAll('.', ',')}";
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      // FUENTE ÚNICA DE VERDAD: el documento que el admin SIEMPRE escribe
      stream: FirebaseFirestore.instance.collection('configuracion_local').doc('precios').snapshots(),
      builder: (context, configSnapshot) {
        if (!configSnapshot.hasData) return const Center(child: CircularProgressIndicator());
        
        final configData = configSnapshot.data!.data() as Map<String, dynamic>?;
        _preciosConfig = configData;
        final bool isOpen = _checkStatus();

        return Scaffold(
          backgroundColor: const Color(0xFFF9F9F9),
          floatingActionButton: FloatingActionButton(
            heroTag: "wa_btn",
            onPressed: () async {
              final digits = await _resolveWhatsappComercioDigits();
              if (!mounted) return;
              if (digits.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("WhatsApp del comercio no configurado.", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold))),
                );
                return;
              }
              final url = Uri.parse("https://wa.me/$digits");
              if (!mounted) return;
              if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
            },
            backgroundColor: const Color(0xFF25D366),
            child: const Icon(Icons.chat, color: Colors.white),
          ),
          body: Stack(
            children: [
              // FONDO 100% LIMPIO (SIN ICONOS HUÉRFANOS - ELIMINADOS DEL ÁRBOL)
              Column(
                children: [
                  _buildHeader(isOpen),
                  if (!isOpen) _buildClosedBanner(),
                  Expanded(
                    child: Container(
                      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
                      child: StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance.collection('productos').snapshots(),
                        builder: (context, snapshot) {
                          bool hasEmpanadas = false;
                          if (snapshot.hasData) {
                            hasEmpanadas = snapshot.data!.docs.any((d) => (d.data() as Map<String, dynamic>)['categoria'] == 'Empanada');
                          }
                          
                          // Variable de control (Solo depende del switch de administración)
                          final bool mostrarEmpanadas = _preciosConfig?['mostrar_empanadas'] ?? false;

                          // Definición dinámica de Pestañas
                          final List<Map<String, dynamic>> categories = [
                            {'label': 'PROMOS', 'category': 'Oferta'},
                            {'label': 'PIZZAS', 'category': 'Pizza'},
                            if (mostrarEmpanadas) {'label': 'EMPANADAS', 'category': 'Empanada'},
                            {'label': 'BEBIDAS', 'category': 'Bebida'},
                          ];

                          // Ajustar TabController si el número de pestañas cambió
                          // Esto se hace solo si realmente hay un cambio en la longitud detectada
                          if (_tabController.length != categories.length) {
                             WidgetsBinding.instance.addPostFrameCallback((_) {
                               setState(() {
                                 _tabController = TabController(length: categories.length, vsync: this);
                               });
                             });
                          }

                          return Column(
                            children: [
                              TabBar(
                                controller: _tabController,
                                isScrollable: true,
                                indicatorColor: const Color(0xFFFF7F50),
                                labelColor: const Color(0xFFFF7F50),
                                labelStyle: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 13),
                                tabs: categories.map((c) => Tab(text: c['label'])).toList(),
                              ),
                              Expanded(
                                child: TabBarView(
                                  controller: _tabController,
                                  children: categories.map((c) => _buildCardList(c['category'], isOpen)).toList(),
                                ),
                              ),
                            ],
                          );
                        }
                      ),
                    ),
                  ),
                ],
              ),
              _buildActiveOrderBanner(),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('productos').snapshots(),
                builder: (context, snapshot) {
                  double total = snapshot.hasData ? _calculateTotal(snapshot.data!.docs) : 0;
                  return FloatingCartWidget(total: total, onTap: _enviarPedidoDirecto);
                }
              ),
            ],
          ),
        );
      },
    );
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
            final String status = data['estado'] ?? '';
            
            if (status == 'Finalizado' || status == '' || status == 'modificando' || status == 'Cancelado') return const SizedBox.shrink();

            String title = "Seguí tu pedido";
            String sub = "Tocá para ver detalles";
            IconData icon = Icons.timer_outlined; 
            Color accent = Colors.orange;

            if (status == 'En Preparación') {
              title = "¡Pedido Aceptado! 🍕";
              sub = "Ya estamos cocinando tu pedido";
              icon = Icons.access_time_filled;
              accent = Colors.orange;
            } else if (status == 'listo_para_despacho') {
              title = "¡Casi listo! 📦";
              sub = "Tu pedido ya está en el mostrador";
              icon = Icons.inventory_2_outlined;
              accent = Colors.green;
            } else if (status == 'Despachado' || status == 'en_camino') {
              title = "¡Tu pedido va en camino! 🛵";
              sub = "¡Prepará la mesa!";
              icon = Icons.delivery_dining;
              accent = Colors.blue;
            }

            return Positioned(
              bottom: 100,
              left: 20, right: 20,
              child: GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => OrderStatusScreen(orderId: lastOrderId))),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(25),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(25), border: Border.all(color: Colors.white.withOpacity(0.2), width: 1)),
                      child: Row(
                        children: [
                          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: accent.withOpacity(0.2), shape: BoxShape.circle), child: Icon(icon, color: accent, size: 22)),
                          const SizedBox(width: 15),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title.toUpperCase(), style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11, letterSpacing: 1)), Text(sub, style: GoogleFonts.montserrat(color: Colors.white70, fontWeight: FontWeight.w500, fontSize: 10))])),
                          const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 14),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(bool isOpen) {
    final String storeName = _preciosConfig?['nombre'] ?? 'Pizzería Miguel Angel';
    final String slogan = _preciosConfig?['slogan'] ?? (isOpen ? "¡El sabor que esperabas!" : "Cerrado momentáneamente.");
    
    return FutureBuilder<SharedPreferences>(
      future: SharedPreferences.getInstance(),
      builder: (context, snapshot) {
        final String customerName = snapshot.data?.getString('userName') ?? 'Cliente';
        
        return Container(
          padding: const EdgeInsets.only(top: 60, left: 25, right: 25, bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isOpen ? Colors.green : Colors.red,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [BoxShadow(color: (isOpen ? Colors.green : Colors.red).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]
                    ),
                    child: Text(
                      isOpen ? "ABIERTO!" : "CERRADO", 
                      style: GoogleFonts.montserrat(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1)
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.account_circle, size: 30, color: Color(0xFF2D2D2D)),
                    onSelected: (value) async {
                      if (value == 'perfil') {
                        Navigator.pushNamed(context, '/perfil');
                      } else if (value == 'logout') {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text("Cerrar Sesión", style: GoogleFonts.montserrat(fontWeight: FontWeight.bold)),
                            content: Text("¿Estás seguro que querés salir?", style: GoogleFonts.montserrat()),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("CANCELAR")),
                              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("SALIR", style: TextStyle(color: Colors.red))),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.clear();
                          if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                        }
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(value: 'perfil', child: Row(children: [const Icon(Icons.person_outline, size: 18), const SizedBox(width: 10), Text("Mi Cuenta", style: GoogleFonts.montserrat(fontSize: 13))])),
                      PopupMenuItem(value: 'logout', child: Row(children: [const Icon(Icons.logout, size: 18, color: Colors.redAccent), const SizedBox(width: 10), Text("Cerrar Sesión", style: GoogleFonts.montserrat(fontSize: 13, color: Colors.redAccent, fontWeight: FontWeight.bold))])),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Text("¡Hola, $customerName! 👋", style: GoogleFonts.montserrat(fontSize: 14, color: const Color(0xFFFF7F50), fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              Text(storeName.toUpperCase(), style: GoogleFonts.montserrat(fontSize: 22, fontWeight: FontWeight.w900, color: const Color(0xFF2D2D2D), letterSpacing: 1)),
              Text(slogan, style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey[700], fontWeight: FontWeight.w600)),
            ],
          ),
        );
      }
    );
  }

  Widget _buildClosedBanner() {
    return Container(
      width: double.infinity, 
      margin: const EdgeInsets.symmetric(horizontal: 25, vertical: 10), 
      padding: const EdgeInsets.all(15), 
      decoration: BoxDecoration(color: Colors.red[800], borderRadius: BorderRadius.circular(15)), 
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.white), 
          const SizedBox(width: 15), 
          Expanded(child: Text("ESTAMOS CERRADOS - Consultá horarios por WhatsApp.", style: GoogleFonts.montserrat(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)))
        ]
      )
    );
  }

  Widget _buildCardList(String category, bool storeOpen) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('productos').where('categoria', isEqualTo: category).where('disponible', isEqualTo: true).snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) return Center(child: Text("Próximamente...", style: GoogleFonts.montserrat(color: Colors.grey)));
        
        return ListView.builder(
          padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 120),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final docId = docs[index].id;
            final prod = docs[index].data() as Map<String, dynamic>;
            final bool disponible = (prod['disponible'] ?? true) && storeOpen;
            final int qty = _carrito[docId] ?? 0;
            // CAMPO CORRECTO: el admin guarda las imágenes en 'foto_url' como Base64
            final String? imageUrl = prod['foto_url'];

            return Opacity(
              opacity: disponible ? 1.0 : 0.6,
              child: Container(
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 5))]),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      // WIDGET DE IMAGEN: BASE64 desde campo 'foto_url' (igual que el admin)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: _buildProductImage(imageUrl, 80),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(prod['nombre'], style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 14, color: const Color(0xFF2D2D2D))),
                            const SizedBox(height: 4),
                            Text(prod['descripcion'] ?? "", style: GoogleFonts.montserrat(fontSize: 10, color: Colors.grey[600], height: 1.3), maxLines: 2, overflow: TextOverflow.ellipsis),
                            const SizedBox(height: 8),
                            Text(_formatMoney(prod['precio']), style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, color: const Color(0xFFFF7F50), fontSize: 16)),
                          ],
                        ),
                      ),
                      if (disponible) _buildCounter(docId, qty),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Decodifica Base64 y muestra la imagen (campo 'foto_url'), igual que el admin
  Widget _buildProductImage(String? imageData, double size) {
    if (imageData == null || imageData.isEmpty) {
      return Container(
        width: size, height: size,
        color: Colors.grey[100],
        child: Icon(Icons.restaurant, color: Colors.grey[400], size: size * 0.4),
      );
    }
    try {
      return Image.memory(
        base64Decode(imageData),
        width: size, height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: size, height: size,
          color: Colors.grey[100],
          child: Icon(Icons.restaurant, color: Colors.grey[400], size: size * 0.4),
        ),
      );
    } catch (e) {
      return Container(
        width: size, height: size,
        color: Colors.grey[100],
        child: Icon(Icons.restaurant, color: Colors.grey[400], size: size * 0.4),
      );
    }
  }

  Widget _buildCounter(String id, int qty) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFF9F9F9), borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey[200]!)), 
      child: Column(
        children: [
          IconButton(onPressed: () => _addToCart(id), icon: const Icon(Icons.add_circle, size: 22, color: Color(0xFFFF7F50)), constraints: const BoxConstraints(), padding: const EdgeInsets.all(8)), 
          Text(qty.toString(), style: GoogleFonts.montserrat(fontWeight: FontWeight.w900, fontSize: 14)), 
          IconButton(onPressed: () => _removeFromCart(id), icon: const Icon(Icons.remove_circle_outline, size: 22, color: Colors.black54), constraints: const BoxConstraints(), padding: const EdgeInsets.all(8)), 
        ]
      )
    );
  }
}

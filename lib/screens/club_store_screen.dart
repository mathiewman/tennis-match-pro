import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../services/push_notification_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODELO
// ─────────────────────────────────────────────────────────────────────────────
class StoreProduct {
  final String id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final String category;
  final int    stock;       // -1 = ilimitado
  final bool   available;

  const StoreProduct({
    required this.id, required this.name,
    required this.description, required this.price,
    required this.imageUrl,   required this.category,
    required this.stock,      required this.available,
  });

  factory StoreProduct.fromMap(String id, Map<String, dynamic> m) =>
      StoreProduct(
        id:          id,
        name:        m['name']?.toString()        ?? '',
        description: m['description']?.toString() ?? '',
        price:       (m['price']  ?? 0).toDouble(),
        imageUrl:    m['imageUrl']?.toString()    ?? '',
        category:    m['category']?.toString()    ?? 'Otros',
        stock:       (m['stock']  ?? -1) as int,
        available:   m['available'] != false,
      );

  Map<String, dynamic> toMap() => {
    'name': name, 'description': description, 'price': price,
    'imageUrl': imageUrl, 'category': category,
    'stock': stock, 'available': available,
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

const kCategories = [
  'Todo', 'Encordado', 'Raquetas', 'Pelotas',
  'Indumentaria', 'Accesorios', 'Otros',
];

// Estados de pedido
const kOrderStatus = {
  'pending':   ('PENDIENTE',   Colors.orangeAccent),
  'confirmed': ('CONFIRMADO',  Colors.blueAccent),
  'ready':     ('LISTO',       Colors.greenAccent),
  'delivered': ('ENTREGADO',   Colors.white38),
  'cancelled': ('CANCELADO',   Colors.redAccent),
};

// ─────────────────────────────────────────────────────────────────────────────
// ENTRY POINT — detecta rol y muestra la vista correcta
// ─────────────────────────────────────────────────────────────────────────────
class ClubStoreScreen extends StatelessWidget {
  final String clubId;
  final String clubName;
  const ClubStoreScreen(
      {super.key, required this.clubId, required this.clubName});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users').doc(uid).snapshots(),
      builder: (ctx, snap) {
        final role = snap.data?.get('role')?.toString() ?? 'player';
        final isAdmin =
            role == 'coordinator' || role == 'admin';
        return isAdmin
            ? AdminStoreScreen(
                clubId: clubId, clubName: clubName)
            : PlayerStoreScreen(
                clubId: clubId, clubName: clubName);
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// VISTA ADMIN — gestión de productos + pedidos entrantes
// ─────────────────────────────────────────────────────────────────────────────
class AdminStoreScreen extends StatefulWidget {
  final String clubId;
  final String clubName;
  const AdminStoreScreen(
      {super.key, required this.clubId, required this.clubName});

  @override
  State<AdminStoreScreen> createState() => _AdminStoreScreenState();
}

class _AdminStoreScreenState extends State<AdminStoreScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1F1A),
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.3),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(widget.clubName,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
          const Text('MI TIENDA',
              style: TextStyle(
                  color: Color(0xFFCCFF00),
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2)),
        ]),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_box_outlined,
                color: Color(0xFFCCFF00)),
            tooltip: 'Agregar producto',
            onPressed: () => _openEditor(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: const Color(0xFFCCFF00),
          indicatorWeight: 2,
          labelColor: const Color(0xFFCCFF00),
          unselectedLabelColor: Colors.white38,
          labelStyle: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 1),
          tabs: [
            const Tab(text: 'PRODUCTOS'),
            Tab(child: _OrdersBadge(clubId: widget.clubId)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _AdminProductsTab(
              clubId: widget.clubId,
              onEdit: (p) => _openEditor(context, product: p)),
          _AdminOrdersTab(clubId: widget.clubId),
        ],
      ),
    );
  }

  void _openEditor(BuildContext context, {StoreProduct? product}) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1F1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ProductEditorSheet(
          clubId: widget.clubId, product: product),
    );
  }
}

// Badge con contador de pedidos pendientes
class _OrdersBadge extends StatelessWidget {
  final String clubId;
  const _OrdersBadge({required this.clubId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('clubs').doc(clubId)
          .collection('orders')
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (ctx, snap) {
        final count = snap.data?.docs.length ?? 0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            const Padding(
              padding: EdgeInsets.only(right: 8),
              child: Text('PEDIDOS',
                  style: TextStyle(fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1)),
            ),
            if (count > 0)
              Positioned(
                right: 0, top: -4,
                child: Container(
                  width: 16, height: 16,
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text('$count',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB PRODUCTOS (admin)
// ─────────────────────────────────────────────────────────────────────────────
class _AdminProductsTab extends StatefulWidget {
  final String clubId;
  final Function(StoreProduct) onEdit;
  const _AdminProductsTab(
      {required this.clubId, required this.onEdit});

  @override
  State<_AdminProductsTab> createState() => _AdminProductsTabState();
}

class _AdminProductsTabState extends State<_AdminProductsTab> {
  String _cat = 'Todo';

  @override
  Widget build(BuildContext context) {
    Query q = FirebaseFirestore.instance
        .collection('clubs').doc(widget.clubId)
        .collection('products');
    if (_cat != 'Todo') q = q.where('category', isEqualTo: _cat);

    return Column(children: [
      // Filtro
      SizedBox(
        height: 44,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 6),
          itemCount: kCategories.length,
          itemBuilder: (ctx, i) {
            final c = kCategories[i];
            final sel = c == _cat;
            return GestureDetector(
              onTap: () => setState(() => _cat = c),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: sel
                      ? const Color(0xFFCCFF00).withOpacity(0.15)
                      : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: sel
                          ? const Color(0xFFCCFF00).withOpacity(0.4)
                          : Colors.transparent),
                ),
                child: Text(c,
                    style: TextStyle(
                        color: sel
                            ? const Color(0xFFCCFF00)
                            : Colors.white38,
                        fontSize: 11,
                        fontWeight: sel
                            ? FontWeight.bold
                            : FontWeight.normal)),
              ),
            );
          },
        ),
      ),

      // Grid de productos
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: q.snapshots(),
          builder: (ctx, snap) {
            if (!snap.hasData) return const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFFCCFF00)));

            final products = snap.data!.docs
                .map((d) => StoreProduct.fromMap(
                    d.id, d.data() as Map<String, dynamic>))
                .toList();

            if (products.isEmpty) {
              return Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  const Icon(Icons.inventory_2_outlined,
                      color: Colors.white24, size: 56),
                  const SizedBox(height: 12),
                  const Text('No hay productos todavía',
                      style: TextStyle(
                          color: Colors.white38, fontSize: 13)),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => widget.onEdit(StoreProduct(
                        id: '', name: '', description: '',
                        price: 0, imageUrl: '', category: 'Otros',
                        stock: -1, available: true)),
                    icon: const Icon(Icons.add,
                        color: Color(0xFFCCFF00)),
                    label: const Text('Agregar primer producto',
                        style: TextStyle(
                            color: Color(0xFFCCFF00))),
                  ),
                ]),
              );
            }

            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.68,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: products.length,
              itemBuilder: (ctx, i) => _AdminProductCard(
                product:  products[i],
                onEdit:   () => widget.onEdit(products[i]),
              ),
            );
          },
        ),
      ),
    ]);
  }
}

class _AdminProductCard extends StatelessWidget {
  final StoreProduct product;
  final VoidCallback onEdit;
  const _AdminProductCard(
      {required this.product, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final available = product.available;
    return GestureDetector(
      onTap: onEdit,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: available
                  ? Colors.white.withOpacity(0.08)
                  : Colors.redAccent.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Imagen
          Stack(children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16)),
              child: product.imageUrl.isNotEmpty
                  ? Image.network(product.imageUrl,
                      height: 110, width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imgPlaceholder())
                  : _imgPlaceholder(),
            ),
            // Badge disponibilidad
            Positioned(
              top: 8, right: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: available
                      ? Colors.greenAccent.withOpacity(0.9)
                      : Colors.redAccent.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  available ? 'ACTIVO' : 'OCULTO',
                  style: const TextStyle(
                      color: Colors.black,
                      fontSize: 7,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
            // Ícono editar
            Positioned(
              top: 8, left: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.edit,
                    color: Colors.white, size: 12),
              ),
            ),
          ]),

          // Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Text(product.category.toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white24,
                        fontSize: 7,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8)),
                const SizedBox(height: 3),
                Text(product.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const Spacer(),
                Row(children: [
                  Expanded(
                    child: Text(
                      '\$${NumberFormat('#,###').format(product.price)}',
                      style: const TextStyle(
                          color: Color(0xFFCCFF00),
                          fontSize: 14,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (product.stock >= 0)
                    Text('${product.stock} uds',
                        style: TextStyle(
                            color: product.stock < 3
                                ? Colors.redAccent
                                : Colors.white38,
                            fontSize: 9)),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _imgPlaceholder() => Container(
    height: 110, width: double.infinity,
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.06),
      borderRadius: const BorderRadius.vertical(
          top: Radius.circular(16)),
    ),
    child: const Center(child: Icon(Icons.image_outlined,
        color: Colors.white24, size: 32)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// TAB PEDIDOS (admin)
// ─────────────────────────────────────────────────────────────────────────────
class _AdminOrdersTab extends StatefulWidget {
  final String clubId;
  const _AdminOrdersTab({required this.clubId});

  @override
  State<_AdminOrdersTab> createState() => _AdminOrdersTabState();
}

class _AdminOrdersTabState extends State<_AdminOrdersTab> {
  String _filter = 'pending';

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Filtro por estado
      SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 6),
          children: kOrderStatus.entries.map((e) {
            final sel = e.key == _filter;
            final color = e.value.$2;
            return GestureDetector(
              onTap: () => setState(() => _filter = e.key),
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: sel
                      ? color.withOpacity(0.15)
                      : Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: sel
                          ? color.withOpacity(0.4)
                          : Colors.transparent),
                ),
                child: Text(e.value.$1,
                    style: TextStyle(
                        color: sel ? color : Colors.white38,
                        fontSize: 10,
                        fontWeight: sel
                            ? FontWeight.bold
                            : FontWeight.normal)),
              ),
            );
          }).toList(),
        ),
      ),

      // Lista de pedidos
      Expanded(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('clubs').doc(widget.clubId)
              .collection('orders')
              .where('status', isEqualTo: _filter)
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (ctx, snap) {
            if (!snap.hasData) return const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFFCCFF00)));

            final orders = snap.data!.docs;
            if (orders.isEmpty) {
              return Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                  Icon(Icons.receipt_long_outlined,
                      color: Colors.white24, size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'No hay pedidos ${kOrderStatus[_filter]?.$1.toLowerCase() ?? ''}',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 13)),
                ]),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              itemBuilder: (ctx, i) => _AdminOrderCard(
                doc:    orders[i],
                clubId: widget.clubId,
              ),
            );
          },
        ),
      ),
    ]);
  }
}

class _AdminOrderCard extends StatelessWidget {
  final QueryDocumentSnapshot doc;
  final String                clubId;
  const _AdminOrderCard(
      {required this.doc, required this.clubId});

  @override
  Widget build(BuildContext context) {
    final data      = doc.data() as Map<String, dynamic>;
    final buyer     = data['buyerName']?.toString()  ?? 'Jugador';
    final total     = (data['total'] ?? 0).toDouble();
    final status    = data['status']?.toString()     ?? 'pending';
    final items     = (data['items'] as List?)        ?? [];
    final createdAt = data['createdAt'] as Timestamp?;
    final timeStr   = createdAt != null
        ? DateFormat('dd/MM HH:mm').format(createdAt.toDate())
        : '';

    final statusInfo = kOrderStatus[status] ??
        ('PENDIENTE', Colors.orangeAccent);
    final statusLabel = statusInfo.$1;
    final statusColor = statusInfo.$2;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: statusColor.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Header
          Row(children: [
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Text(buyer, style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
              Text(timeStr, style: const TextStyle(
                  color: Colors.white38, fontSize: 10)),
            ])),
            Column(crossAxisAlignment: CrossAxisAlignment.end,
                children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(statusLabel, style: TextStyle(
                    color: statusColor,
                    fontSize: 9,
                    fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 4),
              Text(
                '\$${NumberFormat('#,###').format(total)}',
                style: const TextStyle(
                    color: Color(0xFFCCFF00),
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
            ]),
          ]),
          const SizedBox(height: 10),

          // Items del pedido
          ...items.map((item) {
            final iName = item['name']?.toString() ?? '';
            final iQty  = item['qty']              ?? 1;
            final iPrice = (item['price'] ?? 0).toDouble();
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                Text('$iQty×',
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 11)),
                const SizedBox(width: 6),
                Expanded(child: Text(iName,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 11))),
                Text(
                  '\$${NumberFormat('#,###').format(iPrice * iQty)}',
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 11)),
              ]),
            );
          }),

          // Notas del comprador
          if ((data['note'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(children: [
                const Icon(Icons.comment_outlined,
                    color: Colors.white24, size: 12),
                const SizedBox(width: 8),
                Expanded(child: Text(
                    data['note']?.toString() ?? '',
                    style: const TextStyle(
                        color: Colors.white54, fontSize: 11))),
              ]),
            ),
          ],

          const SizedBox(height: 12),

          // Botones de acción
          _OrderActions(
              docId:  doc.id,
              clubId: clubId,
              status: status,
              buyer:  buyer,
              total:  total),
        ]),
      ),
    );
  }
}

class _OrderActions extends StatefulWidget {
  final String docId, clubId, status, buyer;
  final double total;
  const _OrderActions({
    required this.docId, required this.clubId,
    required this.status, required this.buyer,
    required this.total,
  });

  @override
  State<_OrderActions> createState() => _OrderActionsState();
}

class _OrderActionsState extends State<_OrderActions> {
  bool _loading = false;

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _loading = true);

    // Leer datos del pedido para obtener buyerUid y nombre del club
    final orderDoc = await FirebaseFirestore.instance
        .collection('clubs').doc(widget.clubId)
        .collection('orders').doc(widget.docId).get();
    final orderData = orderDoc.data() ?? {};
    final buyerUid  = orderData['buyerUid']?.toString()  ?? '';

    // Leer nombre del club
    final clubDoc  = await FirebaseFirestore.instance
        .collection('clubs').doc(widget.clubId).get();
    final clubName = clubDoc.data()?['name']?.toString() ?? 'El club';

    await FirebaseFirestore.instance
        .collection('clubs').doc(widget.clubId)
        .collection('orders').doc(widget.docId)
        .update({'status': newStatus,
                 'updatedAt': FieldValue.serverTimestamp()});

    // Notificar al jugador
    if (buyerUid.isNotEmpty) {
      await PushNotificationService.notifyOrderUpdate(
        buyerUid:  buyerUid,
        status:    newStatus,
        clubName:  clubName,
      );
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(
        child: SizedBox(width: 20, height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Color(0xFFCCFF00))));

    // Botones según estado actual
    final actions = <Widget>[];

    if (widget.status == 'pending') {
      actions.add(_btn('CONFIRMAR', Colors.blueAccent,
          () => _updateStatus('confirmed')));
      actions.add(_btn('CANCELAR', Colors.redAccent,
          () => _updateStatus('cancelled')));
    } else if (widget.status == 'confirmed') {
      actions.add(_btn('LISTO PARA ENTREGAR',
          Colors.greenAccent, () => _updateStatus('ready')));
      actions.add(_btn('CANCELAR', Colors.redAccent,
          () => _updateStatus('cancelled')));
    } else if (widget.status == 'ready') {
      actions.add(_btn('MARCAR ENTREGADO',
          const Color(0xFFCCFF00),
          () => _updateStatus('delivered')));
    }

    if (actions.isEmpty) return const SizedBox();

    return Wrap(spacing: 8, children: actions);
  }

  Widget _btn(String label, Color color, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Text(label, style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold)),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// VISTA JUGADOR — grilla de productos + carrito
// ─────────────────────────────────────────────────────────────────────────────
class PlayerStoreScreen extends StatefulWidget {
  final String clubId;
  final String clubName;
  const PlayerStoreScreen(
      {super.key, required this.clubId, required this.clubName});

  @override
  State<PlayerStoreScreen> createState() => _PlayerStoreScreenState();
}

class _PlayerStoreScreenState extends State<PlayerStoreScreen> {
  String _cat = 'Todo';
  final Map<String, int> _cart = {};

  int get _cartCount => _cart.values.fold(0, (a, b) => a + b);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1F1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Text(widget.clubName,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
          const Text('TIENDA OFICIAL',
              style: TextStyle(
                  color: Color(0xFFCCFF00),
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2)),
        ]),
        actions: [
          if (_cartCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Stack(alignment: Alignment.topRight,
                  children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart_outlined,
                      color: Colors.white),
                  onPressed: () => _openCart(context),
                ),
                Positioned(
                  right: 4, top: 4,
                  child: Container(
                    width: 16, height: 16,
                    decoration: const BoxDecoration(
                        color: Color(0xFFCCFF00),
                        shape: BoxShape.circle),
                    child: Center(child: Text('$_cartCount',
                        style: const TextStyle(
                            color: Colors.black,
                            fontSize: 9,
                            fontWeight: FontWeight.bold))),
                  ),
                ),
              ]),
            ),
        ],
      ),
      body: Column(children: [
        // Filtro de categorías
        SizedBox(
          height: 44,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 6),
            itemCount: kCategories.length,
            itemBuilder: (ctx, i) {
              final c = kCategories[i];
              final sel = c == _cat;
              return GestureDetector(
                onTap: () => setState(() => _cat = c),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: sel
                        ? const Color(0xFFCCFF00).withOpacity(0.15)
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: sel
                            ? const Color(0xFFCCFF00).withOpacity(0.4)
                            : Colors.transparent),
                  ),
                  child: Text(c, style: TextStyle(
                      color: sel
                          ? const Color(0xFFCCFF00)
                          : Colors.white38,
                      fontSize: 11,
                      fontWeight: sel
                          ? FontWeight.bold
                          : FontWeight.normal)),
                ),
              );
            },
          ),
        ),

        // Productos
        Expanded(child: _buildGrid()),
      ]),

      // Botón carrito flotante
      floatingActionButton: _cartCount > 0
          ? FloatingActionButton.extended(
              backgroundColor: const Color(0xFFCCFF00),
              onPressed: () => _openCart(context),
              icon: const Icon(Icons.shopping_cart,
                  color: Colors.black),
              label: Text(
                'Ver pedido ($_cartCount)',
                style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );
  }

  Widget _buildGrid() {
    Query q = FirebaseFirestore.instance
        .collection('clubs').doc(widget.clubId)
        .collection('products')
        .where('available', isEqualTo: true);
    if (_cat != 'Todo') q = q.where('category', isEqualTo: _cat);

    return StreamBuilder<QuerySnapshot>(
      stream: q.snapshots(),
      builder: (ctx, snap) {
        if (!snap.hasData) return const Center(
            child: CircularProgressIndicator(
                color: Color(0xFFCCFF00)));

        final products = snap.data!.docs
            .map((d) => StoreProduct.fromMap(
                d.id, d.data() as Map<String, dynamic>))
            .toList();

        if (products.isEmpty) {
          return Center(
            child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
              const Icon(Icons.storefront_outlined,
                  color: Colors.white24, size: 56),
              const SizedBox(height: 12),
              Text(
                _cat == 'Todo'
                    ? 'La tienda no tiene productos aún'
                    : 'No hay productos en esta categoría',
                style: const TextStyle(
                    color: Colors.white38, fontSize: 13)),
            ]),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.7,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: products.length,
          itemBuilder: (ctx, i) {
            final p = products[i];
            return _PlayerProductCard(
              product:  p,
              qty:      _cart[p.id] ?? 0,
              onAdd:    () => setState(() =>
                  _cart[p.id] = (_cart[p.id] ?? 0) + 1),
              onRemove: () => setState(() {
                final q = (_cart[p.id] ?? 0) - 1;
                if (q <= 0) _cart.remove(p.id);
                else _cart[p.id] = q;
              }),
              onDetail: () => _showDetail(context, p),
            );
          },
        );
      },
    );
  }

  void _showDetail(BuildContext context, StoreProduct p) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1F1A),
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          if (p.imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(p.imageUrl,
                  width: double.infinity,
                  height: 200,
                  fit: BoxFit.cover),
            ),
          const SizedBox(height: 16),
          Text(p.name, style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(p.category.toUpperCase(),
              style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 10,
                  letterSpacing: 1.5)),
          if (p.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(p.description,
                style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 13,
                    height: 1.5)),
          ],
          const SizedBox(height: 16),
          Row(children: [
            Text('\$${NumberFormat('#,###').format(p.price)}',
                style: const TextStyle(
                    color: Color(0xFFCCFF00),
                    fontSize: 26,
                    fontWeight: FontWeight.bold)),
            const Spacer(),
            if (p.stock >= 0)
              Text('${p.stock} disponibles',
                  style: TextStyle(
                      color: p.stock < 3
                          ? Colors.redAccent
                          : Colors.white38,
                      fontSize: 12)),
          ]),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCCFF00),
                padding: const EdgeInsets.symmetric(
                    vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.add_shopping_cart,
                  color: Colors.black),
              label: const Text('AGREGAR AL PEDIDO',
                  style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold)),
              onPressed: () {
                setState(() =>
                    _cart[p.id] = (_cart[p.id] ?? 0) + 1);
                Navigator.pop(context);
              },
            ),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  void _openCart(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D1F1A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _CartSheet(
        cart:    _cart,
        clubId:  widget.clubId,
        onClear: () => setState(() => _cart.clear()),
        onQtyChanged: (id, q) => setState(() {
          if (q <= 0) _cart.remove(id);
          else _cart[id] = q;
        }),
      ),
    );
  }
}

class _PlayerProductCard extends StatelessWidget {
  final StoreProduct product;
  final int          qty;
  final VoidCallback onAdd, onRemove, onDetail;
  const _PlayerProductCard({
    required this.product, required this.qty,
    required this.onAdd,   required this.onRemove,
    required this.onDetail,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onDetail,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: qty > 0
                  ? const Color(0xFFCCFF00).withOpacity(0.3)
                  : Colors.white.withOpacity(0.07)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Imagen
          Stack(children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16)),
              child: product.imageUrl.isNotEmpty
                  ? Image.network(product.imageUrl,
                      height: 120, width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _placeholder())
                  : _placeholder(),
            ),
            if (qty > 0)
              Positioned(
                top: 8, right: 8,
                child: Container(
                  width: 22, height: 22,
                  decoration: const BoxDecoration(
                      color: Color(0xFFCCFF00),
                      shape: BoxShape.circle),
                  child: Center(child: Text('$qty',
                      style: const TextStyle(
                          color: Colors.black,
                          fontSize: 11,
                          fontWeight: FontWeight.bold))),
                ),
              ),
          ]),

          // Info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Text(product.category.toUpperCase(),
                    style: const TextStyle(
                        color: Colors.white24,
                        fontSize: 7,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8)),
                const SizedBox(height: 3),
                Expanded(child: Text(product.name,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis)),
                Row(children: [
                  Text(
                    '\$${NumberFormat('#,###').format(product.price)}',
                    style: const TextStyle(
                        color: Color(0xFFCCFF00),
                        fontSize: 13,
                        fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  // Control de cantidad
                  if (qty == 0)
                    GestureDetector(
                      onTap: onAdd,
                      child: Container(
                        width: 28, height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFFCCFF00),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.add,
                            color: Colors.black, size: 16),
                      ),
                    )
                  else
                    Row(mainAxisSize: MainAxisSize.min,
                        children: [
                      _qtyBtn(Icons.remove, onRemove,
                          Colors.white.withOpacity(0.1),
                          Colors.white),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 5),
                        child: Text('$qty',
                            style: const TextStyle(
                                color: Color(0xFFCCFF00),
                                fontWeight: FontWeight.bold,
                                fontSize: 12)),
                      ),
                      _qtyBtn(Icons.add, onAdd,
                          const Color(0xFFCCFF00),
                          Colors.black),
                    ]),
                ]),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _placeholder() => Container(
    height: 120, color: Colors.white.withOpacity(0.06),
    child: const Center(child: Icon(Icons.image_outlined,
        color: Colors.white24, size: 32)),
  );

  Widget _qtyBtn(IconData icon, VoidCallback onTap,
      Color bg, Color fg) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 22, height: 22,
          decoration: BoxDecoration(
              color: bg, borderRadius: BorderRadius.circular(6)),
          child: Icon(icon, color: fg, size: 13),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// CARRITO Y CHECKOUT
// ─────────────────────────────────────────────────────────────────────────────
class _CartSheet extends StatefulWidget {
  final Map<String, int> cart;
  final String           clubId;
  final VoidCallback     onClear;
  final Function(String id, int qty) onQtyChanged;
  const _CartSheet({
    required this.cart,    required this.clubId,
    required this.onClear, required this.onQtyChanged,
  });

  @override
  State<_CartSheet> createState() => _CartSheetState();
}

class _CartSheetState extends State<_CartSheet> {
  final _noteCtrl = TextEditingController();
  bool   _placing      = false;
  String _storePayment = 'club'; // 'club' or 'coins'
  int    _userCoins    = 0;

  @override
  void initState() {
    super.initState();
    _loadCoins();
  }

  Future<void> _loadCoins() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (uid.isEmpty) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (mounted) setState(() => _userCoins = ((doc.data()?['balance_coins']) ?? 0) as int);
  }

  @override
  void dispose() { _noteCtrl.dispose(); super.dispose(); }

  Future<void> _placeOrder(
      BuildContext context, List<StoreProduct> products) async {
    setState(() => _placing = true);

    final user = FirebaseAuth.instance.currentUser;
    double total = 0;
    final items = <Map<String, dynamic>>[];

    for (final p in products) {
      final qty = widget.cart[p.id] ?? 0;
      if (qty == 0) continue;
      total += p.price * qty;
      items.add({
        'productId': p.id,
        'name':      p.name,
        'price':     p.price,
        'qty':       qty,
        'imageUrl':  p.imageUrl,
      });
    }

    try {
      await FirebaseFirestore.instance
          .collection('clubs').doc(widget.clubId)
          .collection('orders').add({
        'buyerUid':     user?.uid   ?? '',
        'buyerName':    user?.displayName ?? 'Jugador',
        'buyerEmail':   user?.email ?? '',
        'items':        items,
        'total':        total,
        'note':         _noteCtrl.text.trim(),
        'status':       'pending',
        'paymentMethod': _storePayment,
        'createdAt':    FieldValue.serverTimestamp(),
      });

      // Si pagó con coins, descontar
      if (_storePayment == 'coins') {
        final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
        final totalInt = total.toInt();
        if (uid.isNotEmpty && totalInt > 0) {
          await FirebaseFirestore.instance
              .collection('users').doc(uid)
              .update({'balance_coins': FieldValue.increment(-totalInt)});
          await FirebaseFirestore.instance
              .collection('users').doc(uid)
              .collection('coin_transactions').add({
            'amount':      -totalInt,
            'type':        'purchase',
            'description': 'Compra en tienda del club',
            'createdAt':   FieldValue.serverTimestamp(),
            'date':        DateTime.now().toIso8601String(),
          });
          if (mounted) setState(() => _userCoins -= totalInt);
        }
      }

      widget.onClear();
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Pedido enviado — total \$${NumberFormat('#,###').format(total)}. '
              'El club lo va a confirmar pronto.',
            ),
            backgroundColor: const Color(0xFF1A3A34),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _placing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (ctx, ctrl) => FutureBuilder<List<StoreProduct>>(
        future: _loadProducts(),
        builder: (ctx, snap) {
          if (!snap.hasData) return const Center(
              child: CircularProgressIndicator(
                  color: Color(0xFFCCFF00)));

          final products = snap.data!
              .where((p) => widget.cart.containsKey(p.id))
              .toList();

          double total = 0;
          for (final p in products) {
            total += p.price * (widget.cart[p.id] ?? 0);
          }

          return Column(children: [
            // Handle
            Padding(
              padding: const EdgeInsets.symmetric(
                  vertical: 12),
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20),
              child: Row(children: [
                const Text('TU PEDIDO',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    widget.onClear();
                    Navigator.pop(context);
                  },
                  child: const Text('Vaciar',
                      style: TextStyle(
                          color: Colors.redAccent)),
                ),
              ]),
            ),

            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.symmetric(
                    horizontal: 20),
                children: [
                  // Items
                  ...products.map((p) {
                    final qty = widget.cart[p.id] ?? 0;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: p.imageUrl.isNotEmpty
                              ? Image.network(p.imageUrl,
                                  width: 52, height: 52,
                                  fit: BoxFit.cover)
                              : Container(
                                  width: 52, height: 52,
                                  color: Colors.white10,
                                  child: const Icon(
                                      Icons.image_outlined,
                                      color: Colors.white24)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                          Text(p.name,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13)),
                          Text(
                            '\$${NumberFormat('#,###').format(p.price)}',
                            style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 11)),
                        ])),
                        // Control cantidad
                        Row(children: [
                          _qBtn(Icons.remove, () {
                            widget.onQtyChanged(p.id, qty - 1);
                            setState(() {});
                          }),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10),
                            child: Text('$qty',
                                style: const TextStyle(
                                    color: Color(0xFFCCFF00),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14)),
                          ),
                          _qBtn(Icons.add, () {
                            widget.onQtyChanged(p.id, qty + 1);
                            setState(() {});
                          }),
                        ]),
                      ]),
                    );
                  }),

                  // Nota
                  const SizedBox(height: 12),
                  TextField(
                    controller: _noteCtrl,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText:
                          'Nota para el club (opcional)...',
                      hintStyle: const TextStyle(
                          color: Colors.white24),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),

            // Footer con total y botón
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF061410),
                border: Border(top: BorderSide(
                    color: Colors.white.withOpacity(0.08))),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                Row(children: [
                  const Text('TOTAL',
                      style: TextStyle(
                          color: Colors.white54,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1)),
                  const Spacer(),
                  Text(
                    '\$${NumberFormat('#,###').format(total)}',
                    style: const TextStyle(
                        color: Color(0xFFCCFF00),
                        fontSize: 24,
                        fontWeight: FontWeight.bold),
                  ),
                ]),
                const SizedBox(height: 12),
                // Selector de pago
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('FORMA DE PAGO',
                        style: TextStyle(
                            color: Colors.white38,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5)),
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: GestureDetector(
                        onTap: () => setState(() => _storePayment = 'club'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _storePayment == 'club'
                                ? Colors.white.withOpacity(0.1)
                                : Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _storePayment == 'club'
                                  ? Colors.white54
                                  : Colors.white12,
                            ),
                          ),
                          child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.store, color: Colors.white54, size: 18),
                            SizedBox(height: 4),
                            Text('EN CLUB', style: TextStyle(
                                color: Colors.white54, fontSize: 10,
                                fontWeight: FontWeight.bold)),
                          ]),
                        ),
                      )),
                      const SizedBox(width: 10),
                      Expanded(child: GestureDetector(
                        onTap: () => setState(() => _storePayment = 'coins'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _storePayment == 'coins'
                                ? const Color(0xFFCCFF00).withOpacity(0.12)
                                : Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _storePayment == 'coins'
                                  ? const Color(0xFFCCFF00).withOpacity(0.5)
                                  : Colors.white12,
                            ),
                          ),
                          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.monetization_on,
                                color: _storePayment == 'coins'
                                    ? const Color(0xFFCCFF00)
                                    : Colors.white38,
                                size: 18),
                            const SizedBox(height: 4),
                            Text('$_userCoins COINS',
                                style: TextStyle(
                                    color: _storePayment == 'coins'
                                        ? const Color(0xFFCCFF00)
                                        : Colors.white38,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ]),
                        ),
                      )),
                    ]),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFCCFF00),
                      padding: const EdgeInsets.symmetric(
                          vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: _placing
                        ? null
                        : () => _placeOrder(context, products),
                    child: _placing
                        ? const SizedBox(width: 22, height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.black))
                        : const Text('ENVIAR PEDIDO AL CLUB',
                            style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                letterSpacing: 0.5)),
                  ),
                ),
              ]),
            ),
          ]);
        },
      ),
    );
  }

  Future<List<StoreProduct>> _loadProducts() async {
    final ids = widget.cart.keys.toList();
    if (ids.isEmpty) return [];
    final snap = await FirebaseFirestore.instance
        .collection('clubs').doc(widget.clubId)
        .collection('products')
        .where(FieldPath.documentId, whereIn: ids)
        .get();
    return snap.docs.map((d) => StoreProduct.fromMap(
        d.id, d.data() as Map<String, dynamic>)).toList();
  }

  Widget _qBtn(IconData icon, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white60, size: 14),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// EDITOR DE PRODUCTO (admin)
// ─────────────────────────────────────────────────────────────────────────────
class _ProductEditorSheet extends StatefulWidget {
  final String        clubId;
  final StoreProduct? product;
  const _ProductEditorSheet(
      {required this.clubId, this.product});

  @override
  State<_ProductEditorSheet> createState() =>
      _ProductEditorSheetState();
}

class _ProductEditorSheetState
    extends State<_ProductEditorSheet> {
  late final TextEditingController _nameCtrl, _descCtrl,
      _priceCtrl, _stockCtrl;
  String _category   = 'Accesorios';
  bool   _available  = true;
  bool   _unlimited  = true;
  bool   _saving     = false;
  File?  _imageFile;
  String _imageUrl   = '';

  @override
  void initState() {
    super.initState();
    final p    = widget.product;
    _nameCtrl  = TextEditingController(text: p?.name ?? '');
    _descCtrl  = TextEditingController(text: p?.description ?? '');
    _priceCtrl = TextEditingController(
        text: p != null && p.price > 0
            ? p.price.toInt().toString() : '');
    final stock = p?.stock ?? -1;
    _unlimited  = stock < 0;
    _stockCtrl  = TextEditingController(
        text: stock >= 0 ? stock.toString() : '');
    _category   = p?.category  ?? 'Accesorios';
    _available  = p?.available ?? true;
    _imageUrl   = p?.imageUrl  ?? '';
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _descCtrl.dispose();
    _priceCtrl.dispose(); _stockCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker()
        .pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (picked != null && mounted) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El nombre es requerido')));
      return;
    }
    setState(() => _saving = true);
    try {
      if (_imageFile != null) {
        final ref = FirebaseStorage.instance.ref().child(
            'clubs/${widget.clubId}/store/'
            '${DateTime.now().millisecondsSinceEpoch}.jpg');
        await ref.putFile(_imageFile!);
        _imageUrl = await ref.getDownloadURL();
      }

      final data = {
        'name':        _nameCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'price':       double.tryParse(_priceCtrl.text) ?? 0,
        'stock':       _unlimited
            ? -1
            : (int.tryParse(_stockCtrl.text) ?? 0),
        'category':    _category,
        'available':   _available,
        'imageUrl':    _imageUrl,
        'updatedAt':   FieldValue.serverTimestamp(),
      };

      final coll = FirebaseFirestore.instance
          .collection('clubs').doc(widget.clubId)
          .collection('products');

      if (widget.product != null && widget.product!.id.isNotEmpty) {
        await coll.doc(widget.product!.id).update(data);
      } else {
        data['createdAt'] = FieldValue.serverTimestamp();
        await coll.add(data);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(widget.product?.id.isNotEmpty == true
              ? 'Producto actualizado ✓'
              : 'Producto agregado a la tienda ✓'),
          backgroundColor: const Color(0xFF1A3A34),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _delete() async {
    if (widget.product == null ||
        widget.product!.id.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A3A34),
        title: const Text('Eliminar',
            style: TextStyle(color: Colors.white)),
        content: Text(
            '¿Eliminar "${widget.product!.name}"?',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('ELIMINAR',
                  style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (ok == true && mounted) {
      await FirebaseFirestore.instance
          .collection('clubs').doc(widget.clubId)
          .collection('products').doc(widget.product!.id)
          .delete();
      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.product?.id.isNotEmpty == true;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          24, 24, 24,
          MediaQuery.of(context).viewInsets.bottom + 24),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

          // Header
          Row(children: [
            Text(isEdit ? 'EDITAR PRODUCTO' : 'NUEVO PRODUCTO',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const Spacer(),
            if (isEdit)
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: Colors.redAccent),
                onPressed: _delete,
              ),
          ]),
          const SizedBox(height: 16),

          // Imagen
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 150, width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: const Color(0xFFCCFF00)
                        .withOpacity(0.2)),
              ),
              child: _imageFile != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.file(_imageFile!,
                          fit: BoxFit.cover))
                  : _imageUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(_imageUrl,
                              fit: BoxFit.cover))
                      : const Column(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                          Icon(Icons.add_photo_alternate,
                              color: Color(0xFFCCFF00), size: 32),
                          SizedBox(height: 8),
                          Text('Tocar para agregar imagen',
                              style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 12)),
                        ]),
            ),
          ),
          const SizedBox(height: 14),

          // Nombre
          _field('Nombre del producto', _nameCtrl),
          const SizedBox(height: 10),
          _field('Descripción (opcional)', _descCtrl,
              maxLines: 2),
          const SizedBox(height: 10),

          // Precio + Stock
          Row(children: [
            Expanded(child: _field('Precio \$', _priceCtrl,
                keyboard: TextInputType.number)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(children: [
                Row(children: [
                  const Text('Stock ilimitado',
                      style: TextStyle(
                          color: Colors.white54,
                          fontSize: 11)),
                  const Spacer(),
                  Transform.scale(
                    scale: 0.8,
                    child: Switch(
                      value: _unlimited,
                      activeColor: const Color(0xFFCCFF00),
                      onChanged: (v) =>
                          setState(() => _unlimited = v),
                    ),
                  ),
                ]),
                if (!_unlimited)
                  _field('Stock', _stockCtrl,
                      keyboard: TextInputType.number),
              ]),
            ),
          ]),
          const SizedBox(height: 12),

          // Categoría
          const Text('CATEGORÍA',
              style: TextStyle(
                  color: Colors.white38,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8,
            children: kCategories
                .where((c) => c != 'Todo')
                .map((c) {
              final sel = c == _category;
              return GestureDetector(
                onTap: () => setState(() => _category = c),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: sel
                        ? const Color(0xFFCCFF00)
                            .withOpacity(0.15)
                        : Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: sel
                            ? const Color(0xFFCCFF00)
                                .withOpacity(0.4)
                            : Colors.transparent),
                  ),
                  child: Text(c, style: TextStyle(
                      color: sel
                          ? const Color(0xFFCCFF00)
                          : Colors.white38,
                      fontSize: 11,
                      fontWeight: sel
                          ? FontWeight.bold
                          : FontWeight.normal)),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),

          // Disponible
          Row(children: [
            const Text('Visible en la tienda',
                style: TextStyle(
                    color: Colors.white60, fontSize: 13)),
            const Spacer(),
            Switch(
              value: _available,
              activeColor: const Color(0xFFCCFF00),
              onChanged: (v) => setState(() => _available = v),
            ),
          ]),
          const SizedBox(height: 16),

          // Guardar
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCCFF00),
                padding: const EdgeInsets.symmetric(
                    vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(width: 22, height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.black))
                  : Text(isEdit ? 'GUARDAR CAMBIOS' : 'PUBLICAR PRODUCTO',
                      style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 15)),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl,
      {TextInputType? keyboard, int maxLines = 1}) =>
      TextField(
        controller: ctrl, keyboardType: keyboard,
        maxLines: maxLines,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white38),
          filled: true,
          fillColor: Colors.white.withOpacity(0.06),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                  color: const Color(0xFFCCFF00).withOpacity(0.4))),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 12),
        ),
      );
}

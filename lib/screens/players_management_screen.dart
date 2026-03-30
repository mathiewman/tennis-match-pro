import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'player_home_screen.dart' show catColor;

// ─────────────────────────────────────────────────────────────────────────────
// PLAYERS MANAGEMENT SCREEN — coordinador gestiona categorías de jugadores
// ─────────────────────────────────────────────────────────────────────────────
class PlayersManagementScreen extends StatelessWidget {
  final String clubId;
  const PlayersManagementScreen({super.key, required this.clubId});

  static const _categories = [
    '1era', '2nda', '3era', '4ta', '5ta', '6ta'
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B2218),
        foregroundColor: Colors.white,
        title: const Text('JUGADORES',
            style: TextStyle(
                fontWeight: FontWeight.w900,
                letterSpacing: 1)),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('homeClubId', isEqualTo: clubId)
            .where('role', isEqualTo: 'player')
            .snapshots(),
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return const Center(
                child: CircularProgressIndicator(
                    color: Color(0xFFCCFF00)));
          }

          final docs = snap.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'No hay jugadores asignados a este club.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: Colors.white38, fontSize: 14),
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 16),
            itemCount: docs.length,
            itemBuilder: (ctx, i) {
              final data = docs[i].data() as Map<String, dynamic>;
              return _PlayerCategoryTile(
                  uid: docs[i].id, data: data);
            },
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PLAYER CATEGORY TILE
// ─────────────────────────────────────────────────────────────────────────────
class _PlayerCategoryTile extends StatefulWidget {
  final String uid;
  final Map<String, dynamic> data;
  const _PlayerCategoryTile({required this.uid, required this.data});

  @override
  State<_PlayerCategoryTile> createState() => _PlayerCategoryTileState();
}

class _PlayerCategoryTileState extends State<_PlayerCategoryTile> {
  static const _categories = [
    '1era', '2nda', '3era', '4ta', '5ta', '6ta'
  ];

  bool _saving = false;

  Future<void> _changeCategory(String newCategory) async {
    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.uid)
          .update({'category': newCategory});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name     = widget.data['displayName']?.toString() ?? 'Jugador';
    final photo    = widget.data['photoUrl']?.toString()    ?? '';
    final category = widget.data['category']?.toString()    ?? '';
    final level    = widget.data['tennisLevel']?.toString() ?? '';

    final catIndex = _categories.indexOf(category);

    // +1 categoría = subir (ir hacia '1era', índice menor)
    final canPromote = catIndex > 0;
    // -1 categoría = bajar (ir hacia '6ta', índice mayor)
    final canDemote  = catIndex < _categories.length - 1 &&
        catIndex >= 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(
          horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: const Color(0xFF1A3A34),
          backgroundImage:
              photo.isNotEmpty ? NetworkImage(photo) : null,
          child: photo.isEmpty
              ? const Icon(Icons.person,
                  size: 22, color: Colors.white38)
              : null,
        ),
        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(level,
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 11)),
            ],
          ),
        ),

        if (_saving)
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFCCFF00)),
          )
        else ...[
          // Bajar categoría (→ 6ta)
          _ArrowButton(
            icon: Icons.remove,
            color: Colors.redAccent,
            enabled: canDemote,
            onTap: () => _changeCategory(
                _categories[catIndex + 1]),
          ),
          const SizedBox(width: 8),

          // Badge de categoría actual
          Builder(builder: (_) {
            final cc = category.isEmpty
                ? Colors.white24
                : catColor(category);
            return Container(
              width: 52,
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: cc.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: cc.withOpacity(0.35)),
              ),
              child: Text(
                category.isEmpty ? '—' : category,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: cc,
                    fontSize: 12,
                    fontWeight: FontWeight.bold),
              ),
            );
          }),
          const SizedBox(width: 8),

          // Subir categoría (→ 1era)
          _ArrowButton(
            icon: Icons.add,
            color: Colors.greenAccent,
            enabled: canPromote,
            onTap: () => _changeCategory(
                _categories[catIndex - 1]),
          ),
        ],
      ]),
    );
  }
}

class _ArrowButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;
  const _ArrowButton({
    required this.icon,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: enabled
              ? color.withOpacity(0.1)
              : Colors.white.withOpacity(0.03),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: enabled
                ? color.withOpacity(0.3)
                : Colors.white.withOpacity(0.05),
          ),
        ),
        child: Icon(icon,
            size: 16,
            color: enabled ? color : Colors.white12),
      ),
    );
  }
}

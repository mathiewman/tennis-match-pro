import 'package:flutter/material.dart';
import '../services/database_service.dart';

class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dbService = DatabaseService();

    return Scaffold(
      backgroundColor: const Color(0xFF1A3A34),
      appBar: AppBar(
        title: const Text('Panel de Admin General', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildAdminTile(
              context,
              icon: Icons.monetization_on,
              title: 'Asignar Coins',
              subtitle: 'Cargar saldo manualmente a un jugador.',
              onTap: () => _showAssignCoinsDialog(context, dbService),
            ),
            const SizedBox(height: 16),
            _buildAdminTile(
              context,
              icon: Icons.group_add,
              title: 'Crear Jugadores Ficticios',
              subtitle: 'Genera 5 usuarios de prueba para ranking.',
              onTap: () async {
                await dbService.createMockUsers(5);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('5 Jugadores creados con éxito')),
                  );
                }
              },
            ),
            const SizedBox(height: 16),
            _buildAdminTile(
              context,
              icon: Icons.stadium,
              title: 'Agregar Clubes Ficticios',
              subtitle: 'Genera 3 estadios de prueba para la oferta.',
              onTap: () async {
                await dbService.createMockStadiums(3);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('3 Estadios creados con éxito')),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminTile(BuildContext context,
      {required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          children: [
            Icon(icon, size: 40, color: const Color(0xFFCCFF00)),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(subtitle, style: const TextStyle(color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white24),
          ],
        ),
      ),
    );
  }

  void _showAssignCoinsDialog(BuildContext context, DatabaseService dbService) async {
    final users = await dbService.getAllUsers();
    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Seleccionar Usuario'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return ListTile(
                title: Text(user['displayName'] ?? 'Sin Nombre'),
                subtitle: Text(user['email'] ?? ''),
                onTap: () {
                  Navigator.pop(context);
                  _showAmountInput(context, dbService, user['uid']);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showAmountInput(BuildContext context, DatabaseService dbService, String uid) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Monto a sumar'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'Ej: 5000'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
          TextButton(
            onPressed: () async {
              final amount = int.tryParse(controller.text) ?? 0;
              await dbService.assignCoins(uid, amount);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coins asignados')));
              }
            },
            child: const Text('Asignar'),
          ),
        ],
      ),
    );
  }
}

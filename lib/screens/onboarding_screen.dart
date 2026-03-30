import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/push_notification_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ONBOARDING SCREEN — 3 pasos: nivel · categoría · notificaciones
// ─────────────────────────────────────────────────────────────────────────────
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int    _currentPage      = 0;
  String _selectedLevel    = '';
  String _selectedCategory = '';
  String _selectedClubId   = '';
  String _selectedClubName = '';
  bool   _isSaving         = false;

  static const _levels = [
    ('Principiante',  'Empezando a aprender · primeros torneos',        Icons.sports_tennis),
    ('Intermedio',    'Jugás seguido · torneos locales',                 Icons.emoji_events),
    ('Avanzado',      'Competitivo · torneos federados o de alto nivel', Icons.military_tech),
  ];

  static const _categories = [
    ('1era', '1ª Categoría', 'Élite · Alto nivel competitivo',             Icons.military_tech),
    ('2nda', '2ª Categoría', 'Competitivo avanzado',                       Icons.emoji_events),
    ('3era', '3ª Categoría', 'Intermedio-alto · torneos locales',          Icons.sports_tennis),
    ('4ta',  '4ª Categoría', 'Intermedio',                                 Icons.directions_run),
    ('5ta',  '5ª Categoría', 'Principiante-intermedio',                   Icons.school),
    ('6ta',  '6ª Categoría', 'Principiante · primera competencia',         Icons.star_border),
  ];

  Future<void> _finish() async {
    if (_selectedLevel.isEmpty || _selectedCategory.isEmpty) return;
    setState(() => _isSaving = true);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      await AuthService().saveOnboardingData(
        uid, _selectedLevel, _selectedCategory,
        homeClubId:   _selectedClubId.isNotEmpty   ? _selectedClubId   : null,
        homeClubName: _selectedClubName.isNotEmpty ? _selectedClubName : null,
      );
      await PushNotificationService.refreshToken();
      // AuthGate detecta onboardingDone=true y redirige automáticamente
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1F1A),
      body: SafeArea(
        child: Column(
          children: [
            // Indicador de 4 páginas
            Padding(
              padding: const EdgeInsets.only(top: 24, bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _currentPage == i ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _currentPage == i
                        ? const Color(0xFFCCFF00)
                        : Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                )),
              ),
            ),

            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  // Página 1: Nivel de tenis
                  _LevelPage(
                    levels: _levels,
                    selected: _selectedLevel,
                    onSelect: (l) => setState(() => _selectedLevel = l),
                    onNext: _selectedLevel.isNotEmpty ? _nextPage : null,
                  ),
                  // Página 2: Categoría
                  _CategoryPage(
                    categories: _categories,
                    selected: _selectedCategory,
                    onSelect: (c) => setState(() => _selectedCategory = c),
                    onNext: _selectedCategory.isNotEmpty ? _nextPage : null,
                  ),
                  // Página 3: Club
                  _ClubSelectionPage(
                    selectedClubId: _selectedClubId,
                    onSelect: (id, name) => setState(() {
                      _selectedClubId   = id;
                      _selectedClubName = name;
                    }),
                    onNext: _nextPage,
                  ),
                  // Página 4: Notificaciones
                  _PermissionsPage(
                    onFinish: _isSaving ? null : _finish,
                    isSaving: _isSaving,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── PÁGINA 1: NIVEL DE TENIS ─────────────────────────────────────────────────
class _LevelPage extends StatelessWidget {
  final List<(String, String, IconData)> levels;
  final String   selected;
  final void Function(String) onSelect;
  final VoidCallback? onNext;

  const _LevelPage({
    required this.levels,
    required this.selected,
    required this.onSelect,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          const Text(
            '¿Cuál es tu nivel\nde tenis?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Lo usamos para emparejarte con rivales de tu nivel.',
            style: TextStyle(color: Colors.white54, fontSize: 15),
          ),
          const SizedBox(height: 40),
          ...levels.map((l) {
            final isSelected = selected == l.$1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: InkWell(
                onTap: () => onSelect(l.$1),
                borderRadius: BorderRadius.circular(18),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFCCFF00).withOpacity(0.12)
                        : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFCCFF00)
                          : Colors.white12,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(children: [
                    Icon(l.$3,
                        size: 36,
                        color: isSelected
                            ? const Color(0xFFCCFF00)
                            : Colors.white38),
                    const SizedBox(width: 18),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.$1,
                            style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white70,
                                fontSize: 18,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(l.$2,
                            style: const TextStyle(
                                color: Colors.white38, fontSize: 13)),
                      ],
                    )),
                    if (isSelected)
                      const Icon(Icons.check_circle,
                          color: Color(0xFFCCFF00), size: 22),
                  ]),
                ),
              ),
            );
          }),
          const Spacer(),
          ElevatedButton(
            onPressed: onNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFCCFF00),
              disabledBackgroundColor: Colors.white12,
              minimumSize: const Size(double.infinity, 58),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: Text('CONTINUAR',
                style: TextStyle(
                    color: onNext != null ? Colors.black : Colors.white38,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    letterSpacing: 1.2)),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ─── PÁGINA 2: CATEGORÍA ──────────────────────────────────────────────────────
class _CategoryPage extends StatelessWidget {
  final List<(String, String, String, IconData)> categories;
  final String   selected;
  final void Function(String) onSelect;
  final VoidCallback? onNext;

  const _CategoryPage({
    required this.categories,
    required this.selected,
    required this.onSelect,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          const Text(
            '¿Cuál es tu\ncategoría?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'El coordinador puede ajustarla más adelante.',
            style: TextStyle(color: Colors.white54, fontSize: 15),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: categories.map((c) {
                  final isSelected = selected == c.$1;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () => onSelect(c.$1),
                      borderRadius: BorderRadius.circular(16),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 14),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFCCFF00).withOpacity(0.10)
                              : Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFCCFF00)
                                : Colors.white12,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(0xFFCCFF00).withOpacity(0.15)
                                  : Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(c.$4,
                                size: 22,
                                color: isSelected
                                    ? const Color(0xFFCCFF00)
                                    : Colors.white38),
                          ),
                          const SizedBox(width: 14),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(c.$2,
                                  style: TextStyle(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.white70,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 2),
                              Text(c.$3,
                                  style: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 12)),
                            ],
                          )),
                          if (isSelected)
                            const Icon(Icons.check_circle,
                                color: Color(0xFFCCFF00), size: 20),
                        ]),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFCCFF00),
              disabledBackgroundColor: Colors.white12,
              minimumSize: const Size(double.infinity, 58),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: Text('CONTINUAR',
                style: TextStyle(
                    color: onNext != null ? Colors.black : Colors.white38,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    letterSpacing: 1.2)),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ─── PÁGINA 3: PERMISOS ───────────────────────────────────────────────────────
class _PermissionsPage extends StatelessWidget {
  final VoidCallback? onFinish;
  final bool isSaving;

  const _PermissionsPage({required this.onFinish, required this.isSaving});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          const Icon(Icons.notifications_active,
              color: Color(0xFFCCFF00), size: 64),
          const SizedBox(height: 28),
          const Text(
            'Activá las notificaciones',
            style: TextStyle(
                color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 14),
          const Text(
            'Te avisamos cuando:',
            style: TextStyle(color: Colors.white54, fontSize: 15),
          ),
          const SizedBox(height: 24),
          _PermissionItem(icon: Icons.emoji_events,
              text: 'Se crea un torneo nuevo en tu club'),
          _PermissionItem(icon: Icons.sports_tennis,
              text: 'Un jugador te desafía a un partido'),
          _PermissionItem(icon: Icons.calendar_today,
              text: 'Te asignan un turno en el bracket'),
          _PermissionItem(icon: Icons.timer,
              text: 'Tu ronda de torneo está por vencer'),
          const Spacer(),
          ElevatedButton(
            onPressed: onFinish,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFCCFF00),
              minimumSize: const Size(double.infinity, 58),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: isSaving
                ? const SizedBox(
                    width: 22, height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.black, strokeWidth: 2.5))
                : const Text('ACTIVAR Y EMPEZAR',
                    style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        letterSpacing: 1.2)),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onFinish,
            child: const Text('Ahora no',
                style: TextStyle(color: Colors.white38, fontSize: 13)),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

// ─── PÁGINA 3: SELECCIÓN DE CLUB ─────────────────────────────────────────────
class _ClubSelectionPage extends StatelessWidget {
  final String selectedClubId;
  final void Function(String id, String name) onSelect;
  final VoidCallback onNext;

  const _ClubSelectionPage({
    required this.selectedClubId,
    required this.onSelect,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          const Text(
            '¿En qué club\njugás?',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Te mostramos los torneos y canchas de tu club.',
            style: TextStyle(color: Colors.white54, fontSize: 15),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('clubs')
                  .where('isActive', isEqualTo: true)
                  .snapshots(),
              builder: (ctx, snap) {
                if (!snap.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(
                        color: Color(0xFFCCFF00)),
                  );
                }
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      'No hay clubes registrados aún.',
                      style: TextStyle(color: Colors.white38),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (ctx2, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final id   = docs[i].id;
                    final name = data['name']?.toString() ?? 'Club';
                    final addr = data['address']?.toString() ?? '';
                    final isSelected = selectedClubId == id;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        onTap: () => onSelect(id, name),
                        borderRadius: BorderRadius.circular(16),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFFCCFF00).withOpacity(0.10)
                                : Colors.white.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFFCCFF00)
                                  : Colors.white12,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(children: [
                            Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFCCFF00).withOpacity(0.15)
                                    : Colors.white.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.sports_tennis,
                                  size: 22,
                                  color: isSelected
                                      ? const Color(0xFFCCFF00)
                                      : Colors.white38),
                            ),
                            const SizedBox(width: 14),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(name, style: TextStyle(
                                    color: isSelected
                                        ? Colors.white : Colors.white70,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold)),
                                if (addr.isNotEmpty)
                                  Text(addr, style: const TextStyle(
                                      color: Colors.white38, fontSize: 12)),
                              ],
                            )),
                            if (isSelected)
                              const Icon(Icons.check_circle,
                                  color: Color(0xFFCCFF00), size: 20),
                          ]),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: onNext,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFCCFF00),
              minimumSize: const Size(double.infinity, 58),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text(
              'CONTINUAR',
              style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  letterSpacing: 1.2),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onNext,
            child: const Text('Saltar por ahora',
                style: TextStyle(color: Colors.white38, fontSize: 13)),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _PermissionItem extends StatelessWidget {
  final IconData icon;
  final String   text;
  const _PermissionItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFCCFF00).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: const Color(0xFFCCFF00), size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(child: Text(text,
            style: const TextStyle(color: Colors.white70, fontSize: 14))),
      ]),
    );
  }
}

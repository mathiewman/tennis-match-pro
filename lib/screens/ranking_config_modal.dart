import 'package:flutter/material.dart';
import 'stats_calculator.dart';

const Color _kBg     = Color(0xFF0A0F1E);
const Color _kCard   = Color(0xFF0D1220);
const Color _kYellow = Color(0xFFE3FF00);

class RankingConfigModal extends StatefulWidget {
  final RankingConfig initial;
  final void Function(RankingConfig) onSaved;

  const RankingConfigModal({
    super.key,
    required this.initial,
    required this.onSaved,
  });

  @override
  State<RankingConfigModal> createState() => _RankingConfigModalState();
}

class _RankingConfigModalState extends State<RankingConfigModal> {
  late final TextEditingController _winner;
  late final TextEditingController _runnerUp;
  late final TextEditingController _semi;
  late final TextEditingController _quarter;
  late final TextEditingController _r16; // ADDED
  late final TextEditingController _r32; // ADDED
  late final TextEditingController _r1;

  @override
  void initState() {
    super.initState();
    _winner   = TextEditingController(text: widget.initial.winner.toString());
    _runnerUp = TextEditingController(text: widget.initial.runnerUp.toString());
    _semi     = TextEditingController(text: widget.initial.semi.toString());
    _quarter  = TextEditingController(text: widget.initial.quarter.toString());
    _r16      = TextEditingController(text: widget.initial.r16.toString()); // ADDED
    _r32      = TextEditingController(text: widget.initial.r32.toString()); // ADDED
    _r1       = TextEditingController(text: widget.initial.r1.toString());
  }

  @override
  void dispose() {
    _winner.dispose(); _runnerUp.dispose(); _semi.dispose();
    _quarter.dispose(); _r16.dispose(); _r32.dispose(); _r1.dispose(); // UPDATED
    super.dispose();
  }

  void _save() {
    final cfg = RankingConfig(
      winner:   int.tryParse(_winner.text)   ?? 100,
      runnerUp: int.tryParse(_runnerUp.text) ?? 60,
      semi:     int.tryParse(_semi.text)     ?? 40,
      quarter:  int.tryParse(_quarter.text)  ?? 20,
      r16:      int.tryParse(_r16.text)      ?? 15, // ADDED
      r32:      int.tryParse(_r32.text)      ?? 10, // ADDED
      r1:       int.tryParse(_r1.text)       ?? 5,  // UPDATED default
    );
    widget.onSaved(cfg);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: 360,
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kYellow.withAlpha(51)),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(179),
                blurRadius: 40, spreadRadius: 8),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _header(),
          Expanded( // ADDED: Make the content scrollable
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Column(children: [
                _subtitle(),
                const SizedBox(height: 20),
                _field('🏆  CAMPEÓN',       _winner,   100),
                const SizedBox(height: 10),
                _field('🥈  FINALISTA',     _runnerUp, 60),
                const SizedBox(height: 10),
                _field('🥉  SEMIFINALISTA',   _semi,   40),
                const SizedBox(height: 10),
                _field('●   CUARTOS',       _quarter,  20),
                const SizedBox(height: 10),
                _field('●   8AVOS',         _r16,      15), // ADDED
                const SizedBox(height: 10),
                _field('●   16AVOS',        _r32,      10), // ADDED
                const SizedBox(height: 10),
                _field('●   PRIMERA RONDA', _r1,     5),  // UPDATED default
                const SizedBox(height: 24),
                _buttons(),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _header() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: Colors.white.withAlpha(18))),
    ),
    child: Row(children: [
      Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: _kYellow.withAlpha(26),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Icon(Icons.settings_rounded, color: _kYellow, size: 14),
      ),
      const SizedBox(width: 10),
      const Text('CONFIG. PUNTOS', style: TextStyle(
          color: Colors.white, fontSize: 12,
          fontWeight: FontWeight.bold, letterSpacing: 2)),
      const Spacer(),
      GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(13),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Icon(Icons.close, color: Colors.white38, size: 14),
        ),
      ),
    ]),
  );

  Widget _subtitle() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: _kYellow.withAlpha(10),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: _kYellow.withAlpha(30)),
    ),
    child: Row(children: [
      const Icon(Icons.info_outline, color: _kYellow, size: 12),
      const SizedBox(width: 8),
      const Expanded(
        child: Text(
          'Los puntos se aplican según el mejor resultado alcanzado en el torneo.',
          style: TextStyle(color: Colors.white54, fontSize: 10,
              letterSpacing: 0.3),
        ),
      ),
    ]),
  );

  Widget _field(String label, TextEditingController ctrl, int defaultVal) {
    return Row(children: [
      Expanded(
        child: Text(label, style: const TextStyle(
            color: Colors.white70, fontSize: 11,
            fontWeight: FontWeight.w500, letterSpacing: 0.5)),
      ),
      Container(
        width: 72, height: 38,
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(102),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: Colors.white.withAlpha(26)),
        ),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: _kYellow, fontWeight: FontWeight.bold, fontSize: 16),
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                counterText: '',
              ),
              maxLength: 4,
            ),
          ),
          // Stepper botones
          Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            GestureDetector(
              onTap: () {
                final v = (int.tryParse(ctrl.text) ?? 0) + 5;
                ctrl.text = v.toString();
              },
              child: const Icon(Icons.keyboard_arrow_up_rounded,
                  color: Colors.white38, size: 14),
            ),
            GestureDetector(
              onTap: () {
                final v = ((int.tryParse(ctrl.text) ?? 0) - 5).clamp(0, 9999);
                ctrl.text = v.toString();
              },
              child: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: Colors.white38, size: 14),
            ),
          ]),
          const SizedBox(width: 2),
        ]),
      ),
    ]);
  }

  Widget _buttons() => Row(children: [
    Expanded(
      child: TextButton(
        onPressed: () => Navigator.pop(context),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.white.withAlpha(31)),
          ),
        ),
        child: const Text('CANCELAR',
            style: TextStyle(color: Colors.white38,
                fontSize: 10, letterSpacing: 1.5)),
      ),
    ),
    const SizedBox(width: 12),
    Expanded(
      flex: 2,
      child: ElevatedButton(
        onPressed: _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: _kYellow,
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
        child: const Text('GUARDAR',
            style: TextStyle(color: Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 11, letterSpacing: 2)),
      ),
    ),
  ]);
}

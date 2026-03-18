import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// CustomPainter para dibujar las líneas del bracket
class MatchBracketPainter extends CustomPainter {
  final bool hasOutgoingLine;
  final Color lineColor;
  final double strokeWidth;
  final double matchHeight;
  final double matchWidth;

  MatchBracketPainter({
    required this.hasOutgoingLine,
    required this.lineColor,
    this.strokeWidth = 1.5,
    required this.matchHeight,
    required this.matchWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final double playerLineEnd = matchWidth - 30.0; // Punto donde termina la línea horizontal de los jugadores y empieza la vertical
    final double midHeight = matchHeight / 2;

    // Línea horizontal para el Jugador 1
    canvas.drawLine(const Offset(0, 0), Offset(playerLineEnd, 0), paint);

    // Línea horizontal para el Jugador 2
    canvas.drawLine(Offset(0, matchHeight), Offset(playerLineEnd, matchHeight), paint);

    // Línea vertical que conecta a los jugadores
    canvas.drawLine(Offset(playerLineEnd, 0), Offset(playerLineEnd, matchHeight), paint);

    if (hasOutgoingLine) {
      // Línea horizontal que sale hacia la siguiente ronda
      canvas.drawLine(Offset(playerLineEnd, midHeight), Offset(matchWidth, midHeight), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    MatchBracketPainter oldPainter = oldDelegate as MatchBracketPainter;
    return oldPainter.hasOutgoingLine != hasOutgoingLine ||
           oldPainter.lineColor != lineColor ||
           oldPainter.strokeWidth != strokeWidth ||
           oldPainter.matchHeight != matchHeight ||
           oldPainter.matchWidth != matchWidth;
  }
}

class TournamentPizarraViewScreen extends StatefulWidget {
  final String clubId;
  final String tournamentId;
  final String tournamentName;
  final int playerCount;

  const TournamentPizarraViewScreen({
    super.key,
    required this.clubId,
    required this.tournamentId,
    required this.tournamentName,
    required this.playerCount,
  });

  @override
  State<TournamentPizarraViewScreen> createState() => _TournamentPizarraViewScreenState();
}

class _TournamentPizarraViewScreenState extends State<TournamentPizarraViewScreen> {
  bool _isInitializing = true;
  final Color _chalkWhite = Colors.white; // Color tiza
  final double _matchHeight = 180.0;
  final double _matchWidth = 220.0; // Ancho total para la carta del partido, incluyendo la línea que sale

  final TransformationController _transformationController = TransformationController();

  @override
  void initState() {
    super.initState();
    _setInitialZoom();
    setState(() { _isInitializing = false; });
  }

  void _setInitialZoom() {
    _transformationController.value = Matrix4.identity()..scale(0.4); // Ajusta este factor de escala según sea necesario
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFFCCFF00))));

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('tournaments').doc(widget.tournamentId).collection('temp_layout').doc('current').snapshots(),
      builder: (context, snapshot) {
        Map<int, Map<String, dynamic>> currentSlots = {};
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>?;
          if (data != null && data['slots'] != null) {
            final Map<String, dynamic> loadedSlots = data['slots'];
            currentSlots = loadedSlots.map((k, v) => MapEntry(int.parse(k), Map<String, dynamic>.from(v)));
          }
        }

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              // FONDO: Pizarrón
              Positioned.fill(
                child: Image.asset(
                  'assets/images/pizarron.png',
                  fit: BoxFit.cover,
                ),
              ),
              // AREA DE JUEGO (Brackets) con escalado
              InteractiveViewer(
                transformationController: _transformationController,
                boundaryMargin: const EdgeInsets.all(500),
                minScale: 0.1,
                maxScale: 2.0,
                child: FittedBox(
                  fit: BoxFit.contain,
                  alignment: Alignment.center,
                  child: Container(
                    padding: const EdgeInsets.only(left: 140, top: 100, right: 100, bottom: 100),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: _buildRounds(currentSlots),
                    ),
                  ),
                ),
              ),
              // Botonera superior
              Positioned(
                top: 40,
                left: 20,
                right: 20,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Text(
                      widget.tournamentName.toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(width: 48), // Spacer
                  ],
                ),
              ),
            ],
          ),
        );
      }
    );
  }

  List<Widget> _buildRounds(Map<int, Map<String, dynamic>> slots) {
    List<Widget> rounds = [];
    int currentSize = widget.playerCount;
    int offset = 0;
    int nextOffset = currentSize;
    int roundIdx = 0;
    while (currentSize >= 2) {
      rounds.add(_buildRoundColumn(roundIdx, currentSize, offset, nextOffset, slots));
      offset = nextOffset;
      currentSize ~/= 2;
      nextOffset += currentSize;
      roundIdx++;
    }
    return rounds;
  }

  Widget _buildRoundColumn(int roundIdx, int count, int offset, int nextOffset, Map<int, Map<String, dynamic>> slots) {
    double initialSpacer = (pow(2, roundIdx) - 1).toDouble() * (_matchHeight / 2);
    double gapBetween = (pow(2, roundIdx) - 1).toDouble() * _matchHeight;
    String rName = _getRoundNameLabel(roundIdx);
    
    // Dynamic font size for round names
    double roundNameFontSize = 12; // Default
    if (rName == "FINAL") roundNameFontSize = 15;
    else if (rName == "SEMIFINAL") roundNameFontSize = 13;
    else if (rName == "CUARTOS") roundNameFontSize = 13;
    else if (rName == "OCTAVOS") roundNameFontSize = 12;
    else if (rName.startsWith("RONDA 1")) roundNameFontSize = 10;
    else if (rName.startsWith("RONDA 2")) roundNameFontSize = 12;

    return Container(
      width: _matchWidth, 
      margin: const EdgeInsets.only(right: 60), // Margen para la línea que sale hacia la siguiente ronda
      child: Column(
        children: [
          Text(rName, style: TextStyle(color: _chalkWhite, fontWeight: FontWeight.bold, fontSize: roundNameFontSize)), 
          SizedBox(height: 20 + initialSpacer), 
          ...List.generate(count ~/ 2, (i) { 
            int p1 = offset + (i * 2); 
            int p2 = offset + (i * 2) + 1; 
            int next = (count == 2) ? -1 : (nextOffset + i); 
            return Column(children: [_buildMatchCard(p1, p2, next, roundIdx, slots), SizedBox(height: 20 + gapBetween)]); 
          })
        ]
      )
    );
  }

  String _getRoundNameLabel(int roundIdx) { 
    int tr = (log(widget.playerCount)/log(2)).round(); 
    int rem = tr - roundIdx; 
    if (rem == 1) return "FINAL"; 
    if (rem == 2) return "SEMIFINAL"; 
    if (rem == 3) return "CUARTOS"; 
    if (rem == 4) return "OCTAVOS"; 
    return "RONDA ${roundIdx+1}"; 
  }

  String _formatDisplayScore(List<dynamic> score, bool isWinner) {
    return score.map((s) {
      List<String> pts = s.toString().split('-');
      if (pts.length != 2) return s;
      int s1 = int.tryParse(pts[0]) ?? 0;
      int s2 = int.tryParse(pts[1]) ?? 0;
      // In pizarra view, we just show the score as it was recorded
      return "$s1-$s2";
    }).join(' / ');
  }

  // Widget simplificado para mostrar solo el nombre del jugador
  Widget _buildSlotPlayerName(int index, int roundIdx, Map<int, Map<String, dynamic>> slots) {
    final p = slots[index];
    bool isWinner = p?['winner'] == true;
    bool isPlayed = slots[(index % 2 == 0) ? index : index - 1]?['locked'] == true;
    
    // Jerarquía de fuentes por ronda
    double fSize = 10;
    String rName = _getRoundNameLabel(roundIdx);
    if (rName == "FINAL") fSize = 15;
    else if (rName == "SEMIFINAL") fSize = 13;
    else if (rName == "CUARTOS") fSize = 13;
    else if (rName == "OCTAVOS") fSize = 12;
    else if (rName.startsWith("RONDA 1")) fSize = 10;
    else if (rName.startsWith("RONDA 2")) fSize = 12;

    return Align(
      alignment: Alignment.centerLeft, // Alinea el nombre del jugador a la izquierda
      child: Opacity(
        opacity: (isPlayed && !isWinner) ? 0.4 : 1.0, 
        child: Text(
          p == null ? "A CONFIRMAR" : (p['name']?.toString().toUpperCase() ?? "VACÍO"), 
          style: TextStyle(
            color: isWinner ? _chalkWhite : Colors.white, 
            fontWeight: (isWinner || rName == "FINAL") ? FontWeight.bold : FontWeight.normal, 
            fontSize: fSize
          ), 
          overflow: TextOverflow.ellipsis
        )
      )
    );
  }

  Widget _buildMatchCard(int p1, int p2, int next, int roundIdx, Map<int, Map<String, dynamic>> slots) {
    bool isPlayed = (slots[p1]?['locked'] == true) || (slots[p2]?['locked'] == true);
    String winnerName = "";
    if (isPlayed) {
      if (slots[p1]?['winner'] == true) winnerName = slots[p1]?['name'] ?? "";
      else if (slots[p2]?['winner'] == true) winnerName = slots[p2]?['name'] ?? "";
    }
    List score = isPlayed ? (slots[p1]?['score'] ?? slots[p2]?['score'] ?? []) : [];
    
    final bool hasOutgoingLine = next != -1;

    return SizedBox(
      height: _matchHeight,
      width: _matchWidth, // Usa el ancho definido
      child: Stack(
        clipBehavior: Clip.none, 
        children: [
          // CustomPainter para dibujar las líneas
          Positioned.fill(
            child: CustomPaint(
              painter: MatchBracketPainter(
                hasOutgoingLine: hasOutgoingLine,
                lineColor: Colors.white24, // Líneas tipo tiza
                matchHeight: _matchHeight,
                matchWidth: _matchWidth,
              ),
            ),
          ),
          
          // Nombre del Jugador 1
          Positioned(
            top: 0,
            left: 0,
            width: _matchWidth - 30, // Deja espacio para la línea vertical
            height: _matchHeight / 2,
            child: Padding(
              padding: const EdgeInsets.only(left: 12.0), // Padding consistente
              child: _buildSlotPlayerName(p1, roundIdx, slots),
            ),
          ),

          // Nombre del Jugador 2
          Positioned(
            bottom: 0,
            left: 0,
            width: _matchWidth - 30, // Deja espacio para la línea vertical
            height: _matchHeight / 2,
            child: Padding(
              padding: const EdgeInsets.only(left: 12.0), // Padding consistente
              child: _buildSlotPlayerName(p2, roundIdx, slots),
            ),
          ),

          // Nombre del ganador (apoyado sobre la línea horizontal)
          if (isPlayed && hasOutgoingLine)
            Positioned(
              left: _matchWidth - 30.0 + 5, // Comienza después de la línea vertical con un pequeño offset
              top: (_matchHeight / 2) - 16, // Posiciona el texto arriba de la línea de salida
              child: Text(
                winnerName.toUpperCase(), 
                style: TextStyle(color: _chalkWhite, fontSize: 10, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          
          // Resultado del partido (debajo de la línea horizontal)
          if (isPlayed && hasOutgoingLine)
            Positioned(
              left: _matchWidth - 30.0 + 5, // Comienza después de la línea vertical con un pequeño offset
              top: (_matchHeight / 2) + 2, // Posiciona el texto debajo de la línea de salida
              child: Text(
                _formatDisplayScore(score, false), // 'false' porque el reordenamiento ya no es relevante aquí
                style: const TextStyle(color: Colors.white70, fontSize: 9),
                overflow: TextOverflow.ellipsis,
              ),
            ),

          // Si no se ha jugado, muestra "VS"
          if (!isPlayed && hasOutgoingLine)
            Positioned(
              left: _matchWidth - 30.0, // Comienza donde la línea vertical se encuentra con la horizontal saliente
              top: (_matchHeight / 2) - 10, // Centrado verticalmente con la línea de salida
              width: 30, // Ancho del espacio para "VS"
              child: Center(
                child: const Text(
                  "VS", 
                  style: TextStyle(color: Colors.white24, fontSize: 9, fontWeight: FontWeight.bold)
                ),
              ),
            ),
        ],
      ),
    );
  }
}

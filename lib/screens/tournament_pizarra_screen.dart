
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'tournament_pizarra_view_screen.dart'; // Importa la nueva vista del pizarrón

// CustomPainter para dibujar las líneas del match box y las conexiones estilo "Kings Slam / ATP"
class MatchBoxPainter extends CustomPainter {
  final Color lineColor;
  final double strokeWidth;
  final double matchHeight; // Altura total de un match (e.g., 100.0)
  final double playerCardWidth; // Ancho del espacio para la tarjeta de jugador (e.g., 220.0)
  final double connectorLineWidth; // Ancho del espacio para las líneas conectoras (e.g., 60.0)
  final bool isFinalRound;
  final double playerRowHeight; // Altura de una fila de jugador (matchHeight / 2)

  MatchBoxPainter({
    required this.lineColor,
    this.strokeWidth = 1.5,
    required this.matchHeight,
    required this.playerCardWidth,
    required this.connectorLineWidth,
    this.isFinalRound = false,
    required this.playerRowHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final double halfMatchHeight = matchHeight / 2;
    final double playerRowMidpoint = playerRowHeight / 2;

    // Lineas horizontales de cada jugador (dentro del playerCardWidth)
    canvas.drawLine(Offset(0, 0), Offset(playerCardWidth, 0), paint); // Top player top line
    canvas.drawLine(Offset(0, matchHeight), Offset(playerCardWidth, matchHeight), paint); // Bottom player bottom line

    // Linea vertical derecha que une las dos filas de jugadores
    canvas.drawLine(Offset(playerCardWidth, 0), Offset(playerCardWidth, matchHeight), paint);

    // Conectores estilo '}' desde el borde derecho del playerCardWidth
    Path connectorPath = Path();
    // Top player connector
    connectorPath.moveTo(playerCardWidth, playerRowMidpoint);
    connectorPath.lineTo(playerCardWidth + connectorLineWidth * 0.5, playerRowMidpoint);
    connectorPath.lineTo(playerCardWidth + connectorLineWidth * 0.5, halfMatchHeight);
    canvas.drawPath(connectorPath, paint);

    // Bottom player connector
    connectorPath.reset();
    connectorPath.moveTo(playerCardWidth, matchHeight - playerRowMidpoint);
    connectorPath.lineTo(playerCardWidth + connectorLineWidth * 0.5, matchHeight - playerRowMidpoint);
    connectorPath.lineTo(playerCardWidth + connectorLineWidth * 0.5, halfMatchHeight);
    canvas.drawPath(connectorPath, paint);

    // Outgoing horizontal line if not final round
    if (!isFinalRound) {
      canvas.drawLine(
        Offset(playerCardWidth + connectorLineWidth * 0.5, halfMatchHeight),
        Offset(playerCardWidth + connectorLineWidth, halfMatchHeight), // Extends to the end of the connector space
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant MatchBoxPainter oldDelegate) {
    return oldDelegate.lineColor != lineColor ||
           oldDelegate.strokeWidth != strokeWidth ||
           oldDelegate.matchHeight != matchHeight ||
           oldDelegate.playerCardWidth != playerCardWidth ||
           oldDelegate.connectorLineWidth != connectorLineWidth ||
           oldDelegate.isFinalRound != isFinalRound ||
           oldDelegate.playerRowHeight != playerRowHeight;
  }
}

class TournamentManagementScreen extends StatefulWidget {
  final String clubId;
  final String tournamentId;
  final String tournamentName;
  final int playerCount;

  const TournamentManagementScreen({
    super.key,
    required this.clubId,
    required this.tournamentId,
    required this.tournamentName,
    required this.playerCount,
  });

  @override
  State<TournamentManagementScreen> createState() => _TournamentManagementScreenState();
}

class _TournamentManagementScreenState extends State<TournamentManagementScreen> {
  bool _isInitializing = true;
  int _setsPerMatch = 3;
  String _userRole = 'player';
  final Color _almazaraYellow = const Color(0xFFE3FF00); // Se mantiene para botones interactivos
  final Color _chalkWhite = Colors.white; // Color tiza para el fixture
  final double _matchHeight = 100.0; // Altura ajustada para el estilo ATP
  final double _matchCardWidth = 220.0; // Ancho para las tarjetas de match (jugadores + scores)
  final double _connectorLineWidth = 60.0; // Ancho para las líneas conectoras
  
  @override
  void initState() {
    super.initState();
    _loadInitialConfig();
  }

  Future<void> _loadInitialConfig() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (userDoc.exists) {
          if (mounted) setState(() { _userRole = userDoc.data()?['role'] ?? 'player'; });
        }
      }
      final tDoc = await FirebaseFirestore.instance.collection('tournaments').doc(widget.tournamentId).get();
      if (tDoc.exists) {
        if (mounted) {
          setState(() {
            _setsPerMatch = tDoc.data()?['setsPerMatch'] ?? 3;
            _isInitializing = false;
          });
        }
      } else {
        if (mounted) setState(() => _isInitializing = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isInitializing = false);
    }
  }

  bool get _isAdmin => _userRole == 'admin' || _userRole == 'coordinator';

  Future<void> _persistLayout(Map<int, Map<String, dynamic>> slotsToSave) async {
    if (!_isAdmin) return;
    await FirebaseFirestore.instance
        .collection('tournaments')
        .doc(widget.tournamentId)
        .collection('temp_layout')
        .doc('current')
        .set({'slots': slotsToSave.map((k, v) => MapEntry(k.toString(), v))});
  }

  void _invalidateDownstream(int slotIndex, Map<int, Map<String, dynamic>> slots) {
    int currentSize = widget.playerCount;
    int offset = 0;
    while (currentSize >= 2) {
      if (slotIndex >= offset && slotIndex < offset + currentSize) {
        int nextOffset = offset + currentSize;
        int matchIdxInRound = (slotIndex - offset) ~/ 2;
        int nextSlotIdx = nextOffset + matchIdxInRound;
        if (slots.containsKey(nextSlotIdx)) {
          slots.remove(nextSlotIdx);
          _invalidateDownstream(nextSlotIdx, slots);
        }
        break;
      }
      offset += currentSize;
      currentSize ~/= 2;
    }
  }

  void _onSaveScore(int p1Idx, int p2Idx, int nextIdx, List<String> score, int winnerIdx, Map<int, Map<String, dynamic>> slots) {
    if (nextIdx != -1) _invalidateDownstream(nextIdx, slots);

    if (slots[p1Idx] != null) {
      slots[p1Idx]!['isPlayed'] = true;
      slots[p1Idx]!['winner'] = (p1Idx == winnerIdx);
      slots[p1Idx]!['score'] = score;
      slots[p1Idx]!['locked'] = true;
    }

    if (slots[p2Idx] != null) {
      slots[p2Idx]!['isPlayed'] = true;
      slots[p2Idx]!['winner'] = (p2Idx == winnerIdx);
      slots[p2Idx]!['score'] = score;
      slots[p2Idx]!['locked'] = true;
    }

    if (nextIdx != -1 && winnerIdx != -1 && slots.containsKey(winnerIdx)) { // Asegurar que winnerIdx es válido
      slots[nextIdx] = {
        'name': slots[winnerIdx]!['name']?.toString().toUpperCase() ?? "VACÍO",
        'phone': slots[winnerIdx]!['phone'],
        'isPlayed': false,
        'locked': false,
      };
    } else if (nextIdx != -1 && winnerIdx != -1) { // Caso BYE donde winnerIdx existe pero no en slots directamente (ej. p1 es bye, p2 gana)
       final winnerSlot = (winnerIdx == p1Idx) ? slots[p1Idx] : slots[p2Idx];
       if (winnerSlot != null) {
          slots[nextIdx] = {
            'name': winnerSlot['name']?.toString().toUpperCase() ?? "VACÍO",
            'phone': winnerSlot['phone'],
            'isPlayed': false,
            'locked': false,
          };
       }
    }
    _persistLayout(slots);
  }

  void _onDeleteScore(int p1Idx, int p2Idx, int nextIdx, Map<int, Map<String, dynamic>> slots) {
    if (nextIdx != -1) {
      _invalidateDownstream(nextIdx, slots);
      slots.remove(nextIdx);
    }
    if (slots[p1Idx] != null) {
      slots[p1Idx]!.remove('winner');
      slots[p1Idx]!.remove('score');
      slots[p1Idx]!['isPlayed'] = false;
      slots[p1Idx]!['locked'] = false;
    }
    if (slots[p2Idx] != null) {
      slots[p2Idx]!.remove('winner');
      slots[p2Idx]!.remove('score');
      slots[p2Idx]!['isPlayed'] = false;
      slots[p2Idx]!['locked'] = false;
    }
    _persistLayout(slots);
  }

  Future<void> _launchWhatsApp(String? playerPhone, String playerName, String? opponentName, bool isMatchPlayed, List<dynamic> score) async {
    if (playerPhone == null || playerPhone.isEmpty) return;
    String cleanPhone = playerPhone.replaceAll(RegExp(r'[^0-9]'), '');
    if (!cleanPhone.startsWith('54')) cleanPhone = '549$cleanPhone';
    
    String message;
    if (isMatchPlayed) {
      message = "Hola ${playerName.toUpperCase()}, el resultado de tu partido fue: ${_formatDisplayScore(score, false)}. Ya puedes ver el cuadro actualizado en la app.";
    } else {
      // Mensaje dinámico para partidos no jugados (próximo partido)
      message = "Hola ${playerName.toUpperCase()}, tu próximo partido es contra ${opponentName?.toUpperCase() ?? 'un oponente por definir'}. ¡Mucha suerte!";
    }
    
    final url = Uri.parse("https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}");
    if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  String _formatDisplayScore(List<dynamic> score, bool isWinner) {
    return score.map((s) {
      List<String> pts = s.toString().split('-');
      if (pts.length != 2) return s;
      int s1 = int.tryParse(pts[0]) ?? 0;
      int s2 = int.tryParse(pts[1]) ?? 0;
      // En la vista de gestión, para el resultado mostrado, no reordenamos
      return "$s1-$s2";
    }).join(' / ');
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing) return Scaffold(body: Center(child: CircularProgressIndicator(color: _almazaraYellow))); // Usar amarillo Almazara
    
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
          backgroundColor: const Color(0xFF0A0F1E), // Azul oscuro profundo
          appBar: AppBar(
            backgroundColor: Colors.black,
            title: Text(
              widget.tournamentName.toUpperCase(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TournamentPizarraViewScreen(
                        clubId: widget.clubId,
                        tournamentId: widget.tournamentId,
                        tournamentName: widget.tournamentName,
                        playerCount: widget.playerCount,
                      ),
                    ),
                  );
                },
                child: Text('Ver Pizarrón', style: TextStyle(color: _almazaraYellow, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          body: InteractiveViewer( // Added InteractiveViewer
            boundaryMargin: const EdgeInsets.all(80.0),
            minScale: 0.1,
            maxScale: 2.5,
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Container(
                  padding: const EdgeInsets.all(20), // Padding ajustado para vista de gestión
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _buildRounds(currentSlots),
                  ),
                ),
              ),
            ),
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
      width: _matchCardWidth + _connectorLineWidth, // Ancho de match + espacio para la línea de conexión
      margin: const EdgeInsets.only(right: 20), // Reduced margin to make space for connectors
      child: Column(
        children: [
          Text(rName, style: TextStyle(color: _chalkWhite, fontWeight: FontWeight.bold, fontSize: roundNameFontSize)), 
          SizedBox(height: 20 + initialSpacer), 
          ...List.generate(count ~/ 2, (i) {
            int p1 = offset + (i * 2); 
            int p2 = offset + (i * 2) + 1; 
            int next = (count == 2) ? -1 : (nextOffset + i); 
            return Column(children: [
              _buildMatchCard(p1, p2, next, roundIdx, slots), 
              SizedBox(height: 20 + gapBetween)
            ]); 
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

  Widget _buildMatchCard(int p1, int p2, int next, int roundIdx, Map<int, Map<String, dynamic>> slots) {
    bool isPlayed = (slots[p1]?['locked'] == true) || (slots[p2]?['locked'] == true);
    List score = isPlayed ? (slots[p1]?['score'] ?? slots[p2]?['score'] ?? []) : [];
    
    final bool hasOutgoingLine = next != -1;
    final bool isFinalRound = (next == -1);

    return SizedBox(
      height: _matchHeight, // Altura total del bloque de match
      width: _matchCardWidth + _connectorLineWidth, // Ancho total incluyendo la línea de salida
      child: Stack(
        clipBehavior: Clip.none, // Permite que los elementos se dibujen fuera de los límites del Stack
        children: [
          // CustomPainter para dibujar las líneas del match box y los conectores
          Positioned.fill(
            child: CustomPaint(
              painter: MatchBoxPainter(
                lineColor: Colors.white54, // Líneas más visibles
                matchHeight: _matchHeight,
                playerCardWidth: _matchCardWidth,
                connectorLineWidth: _connectorLineWidth,
                isFinalRound: isFinalRound,
                playerRowHeight: _matchHeight / 2,
              ),
            ),
          ),
          
          // Column que contiene las dos filas de jugadores
          Column(
            children: [
              // Fila del Jugador 1
              PlayerRowWidget(
                playerData: slots[p1],
                opponentName: slots[p2]?['name']?.toString().toUpperCase(),
                isWinner: slots[p1]?['winner'] == true,
                isPlayed: isPlayed,
                isAdmin: _isAdmin,
                almazaraYellow: _almazaraYellow,
                chalkWhite: _chalkWhite,
                playerRowHeight: _matchHeight / 2,
                setsPerMatch: _setsPerMatch,
                onAddPlayer: (slots[p1] == null && _isAdmin) ? () => _showAddPlayerDialog(p1, slots) : null,
                onLaunchWhatsApp: (phone, name, oppName, played, scores) => _launchWhatsApp(phone, name, oppName, played, scores),
                onShowScoreModal: _isAdmin && (isPlayed || (slots[p1] != null && slots[p2] != null)) ? () => _showScoreModal(p1, p2, next, slots) : null,
              ),
              // Fila del Jugador 2
              PlayerRowWidget(
                playerData: slots[p2],
                opponentName: slots[p1]?['name']?.toString().toUpperCase(),
                isWinner: slots[p2]?['winner'] == true,
                isPlayed: isPlayed,
                isAdmin: _isAdmin,
                almazaraYellow: _almazaraYellow,
                chalkWhite: _chalkWhite,
                playerRowHeight: _matchHeight / 2,
                setsPerMatch: _setsPerMatch,
                onAddPlayer: (slots[p2] == null && _isAdmin) ? () => _showAddPlayerDialog(p2, slots) : null,
                onLaunchWhatsApp: (phone, name, oppName, played, scores) => _launchWhatsApp(phone, name, oppName, played, scores),
                onShowScoreModal: _isAdmin && (isPlayed || (slots[p1] != null && slots[p2] != null)) ? () => _showScoreModal(p1, p2, next, slots) : null,
              ),
            ],
          ),

          // Score button/display on the connector line
          if (hasOutgoingLine && (isPlayed || (_isAdmin && slots[p1] != null && slots[p2] != null)))
            Positioned(
              left: _matchCardWidth + (_connectorLineWidth * 0.5) - 20, // Centered on the vertical line segment
              top: (_matchHeight / 2) - 15,
              width: 40,
              height: 30,
              child: _isAdmin && !isPlayed && (slots[p1] != null && slots[p2] != null)
                  ? TextButton(
                      onPressed: () => _showScoreModal(p1, p2, next, slots),
                      child: Text(
                        "SCORE",
                        style: TextStyle(color: _almazaraYellow, fontSize: 8, fontWeight: FontWeight.bold),
                      ),
                    )
                  : Center(
                      child: Text(
                        isPlayed ? _formatDisplayScore(score, false) : "VS",
                        style: TextStyle(
                          color: isPlayed ? _chalkWhite : Colors.white24,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
            ),
        ],
      ),
    );
  }

  void _showAddPlayerDialog(int index, Map<int, Map<String, dynamic>> slots) { 
    final nC = TextEditingController(); 
    final pC = TextEditingController(); 
    showDialog(
      context: context, 
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF2C4A44), 
        title: const Text("REGISTRAR JUGADOR"), 
        content: Column(
          mainAxisSize: MainAxisSize.min, 
          children: [
            TextField(controller: nC, style: const TextStyle(color: Colors.white), textCapitalization: TextCapitalization.characters, decoration: const InputDecoration(labelText: "NOMBRE Y APELLIDO")), 
            TextField(controller: pC, keyboardType: TextInputType.phone, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: "WHATSAPP"))
          ]
        ), 
        actions: [
          ElevatedButton(
            onPressed: () { 
              if (nC.text.isNotEmpty) { 
                setState(() { slots[index] = {'name': nC.text.toUpperCase(), 'phone': pC.text, 'isPlayed': false, 'locked': false}; }); 
                _persistLayout(slots); 
                Navigator.pop(context); 
              } 
            }, 
            child: const Text("GUARDAR")
          )
        ]
      )
    ); 
  }

  void _showScoreModal(int p1, int p2, int next, Map<int, Map<String, dynamic>> slots) {
    final s1p1 = TextEditingController(); final s1p2 = TextEditingController();
    final s2p1 = TextEditingController(); final s2p2 = TextEditingController();
    final s3p1 = TextEditingController(); final s3p2 = TextEditingController();
    
    // Default values for player names to avoid red screen
    final String p1Name = slots[p1]?['name']?.toString().toUpperCase() ?? "P1 (VACÍO)";
    final String p2Name = slots[p2]?['name']?.toString().toUpperCase() ?? "P2 (VACÍO)";

    // Pre-fill scores if they exist
    if (slots[p1]?['score'] != null) { 
      List sc = slots[p1]!['score']; 
      if (sc.length >= 1) { var pts = sc[0].split('-'); s1p1.text = pts[0]; s1p2.text = pts[1]; } 
      if (sc.length >= 2) { var pts = sc[1].split('-'); s2p1.text = pts[0]; s2p2.text = pts[1]; } 
      if (sc.length >= 3) { var pts = sc[2].split('-'); s3p1.text = pts[0]; s3p2.text = pts[1]; } 
    }

    showDialog(context: context, builder: (context) => StatefulBuilder(builder: (context, setModalState) {
      
      // LÓGICA DE GANADOR ROBUSTA Y VALIDACIÓN
      int determineWinner() {
        // BYE rule (case-insensitive)
        final bool p1IsBye = p1Name.toLowerCase().contains("bye");
        final bool p2IsBye = p2Name.toLowerCase().contains("bye");

        if (p1IsBye && !p2IsBye) return p2;
        if (p2IsBye && !p1IsBye) return p1;
        if (p1IsBye && p2IsBye) return -1; // Ambos BYE, estado inválido o necesita manejo específico.

        int setsP1 = 0;
        int setsP2 = 0;
        
        // Helper para parsear scores y validar un set
        bool _isValidSetScore(int s1, int s2) {
          if (s1 == 0 && s2 == 0) return true; // Set vacío
          final int diff = (s1 - s2).abs();
          if ((s1 >= 6 || s2 >= 6) && diff >= 2) return true; // Ganador de set
          if (s1 == 7 && s2 == 6) return true; // Tie-break 7-6
          if (s2 == 7 && s1 == 6) return true; // Tie-break 6-7
          return false; // Score de set inválido
        }

        // Set 1
        int g1s1 = int.tryParse(s1p1.text) ?? 0;
        int g2s1 = int.tryParse(s1p2.text) ?? 0;
        if (!_isValidSetScore(g1s1, g2s1) && (g1s1 != 0 || g2s1 != 0)) return -1; // Validación
        if (g1s1 > g2s1) setsP1++; else if (g2s1 > g1s1) setsP2++;
        
        // Set 2
        int g1s2 = int.tryParse(s2p1.text) ?? 0;
        int g2s2 = int.tryParse(s2p2.text) ?? 0;
        if (!_isValidSetScore(g1s2, g2s2) && (g1s2 != 0 || g2s2 != 0)) return -1; // Validación
        if (g1s2 > g2s2) setsP1++; else if (g2s2 > g1s1) setsP2++;
        
        // Super Tie-break (Set 3) si es necesario (solo si sets son 1-1)
        if (setsP1 == 1 && setsP2 == 1) {
          int g1s3 = int.tryParse(s3p1.text) ?? 0;
          int g2s3 = int.tryParse(s3p2.text) ?? 0;
          
          // Validación de Super Tie-break (10 puntos, diferencia de 2)
          if ((g1s3 >= 10 && (g1s3 - g2s3) >= 2)) return p1;
          if ((g2s3 >= 10 && (g2s3 - g1s3) >= 2)) return p2;
          
          if ((g1s3 != 0 || g2s3 != 0) && (g1s3 < 10 && g2s3 < 10)) return -1; // Tiebreak no terminado o inválido
          if ((g1s3 != 0 || g2s3 != 0) && (g1s3 >= 10 || g2s3 >= 10) && (g1s3 - g2s3).abs() < 2) return -1; // Tiebreak no terminado
          return -1; // Aun no termina el tiebreak o scores inválidos
        }
        
        // Si no hay tie-break y alguien ganó 2 sets
        if (setsP1 == 2) return p1;
        if (setsP2 == 2) return p2;
        
        return -1; // No hay ganador aún o sets incompletos
      }

      int winnerIdx = determineWinner();
      bool hasWinner = winnerIdx != -1;

      return AlertDialog(
        backgroundColor: const Color(0xFF2C4A44), 
        title: const Text("RESULTADO DEL PARTIDO"), 
        content: Column(
          mainAxisSize: MainAxisSize.min, 
          children: [
            _buildModalRow(p1Name, s1p1, s2p1, s3p1, winnerIdx == p1, setModalState), 
            const SizedBox(height: 10), 
            _buildModalRow(p2Name, s1p2, s2p2, s3p2, winnerIdx == p2, setModalState)
          ]
        ), 
        actions: [
          TextButton(onPressed: () { _onDeleteScore(p1, p2, next, slots); Navigator.pop(context); }, child: const Text("ELIMINAR", style: TextStyle(color: Colors.redAccent))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: hasWinner ? _almazaraYellow : Colors.grey), 
            onPressed: hasWinner ? () { 
              List<String> res = [];
              if (s1p1.text.isNotEmpty || s1p2.text.isNotEmpty) res.add("${s1p1.text}-${s1p2.text}"); 
              if (s2p1.text.isNotEmpty || s2p2.text.isNotEmpty) res.add("${s2p1.text}-${s2p2.text}"); 
              if (s3p1.text.isNotEmpty || s3p2.text.isNotEmpty) res.add("${s3p1.text}-${s3p2.text}"); 
              _onSaveScore(p1, p2, next, res, winnerIdx, slots); 
              Navigator.pop(context); 
            } : null, 
            child: const Text("GUARDAR", style: TextStyle(color: Colors.black))
          )
        ]
      );
    }));
  }

  Widget _buildModalRow(String n, TextEditingController c1, TextEditingController c2, TextEditingController c3, bool win, StateSetter setState) {
    return Container(
      padding: const EdgeInsets.all(8), 
      decoration: BoxDecoration(color: win ? _almazaraYellow.withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(10), border: Border.all(color: win ? _almazaraYellow : Colors.white10)), 
      child: Row(children: [Expanded(child: Text(n, style: TextStyle(color: win ? _almazaraYellow : Colors.white, fontSize: 10, fontWeight: FontWeight.bold))), _box(c1, setState), _box(c2, setState), _box(c3, setState, isTiebreak: true)])
    );
  }

  Widget _box(TextEditingController c, StateSetter setState, {bool isTiebreak = false}) { 
    return Container(
      width: 35, 
      margin: const EdgeInsets.only(left: 5), 
      child: TextField(
        controller: c, 
        keyboardType: TextInputType.number, 
        textAlign: TextAlign.center, 
        style: TextStyle(color: isTiebreak ? _almazaraYellow : Colors.white, fontSize: 14), 
        decoration: const InputDecoration(contentPadding: EdgeInsets.zero, border: OutlineInputBorder()), 
        onChanged: (v) => setState(() {})
      )
    ); 
  }
}

// Widget para mostrar una fila de jugador estilo ATP
class PlayerRowWidget extends StatelessWidget {
  final Map<String, dynamic>? playerData;
  final String? opponentName;
  final bool isWinner;
  final bool isPlayed;
  final bool isAdmin;
  final Color almazaraYellow;
  final Color chalkWhite;
  final double playerRowHeight;
  final int setsPerMatch;
  final VoidCallback? onAddPlayer;
  final Function(String? playerPhone, String playerName, String? opponentName, bool isMatchPlayed, List<dynamic> score) onLaunchWhatsApp;
  final VoidCallback? onShowScoreModal;


  const PlayerRowWidget({
    Key? key,
    required this.playerData,
    this.opponentName,
    required this.isWinner,
    required this.isPlayed,
    required this.isAdmin,
    required this.almazaraYellow,
    required this.chalkWhite,
    required this.playerRowHeight,
    required this.setsPerMatch,
    this.onAddPlayer,
    required this.onLaunchWhatsApp,
    this.onShowScoreModal,
  }) : super(key: key);

  String _formatDisplayScorePlayerRow(String scoreSet, bool isWinner) {
    List<String> pts = scoreSet.split('-');
    if (pts.length != 2) return scoreSet;
    int s1 = int.tryParse(pts[0]) ?? 0;
    int s2 = int.tryParse(pts[1]) ?? 0;
    // En la vista de gestión, para el resultado mostrado, no reordenamos
    return "$s1-$s2";
  }

  @override
  Widget build(BuildContext context) {
    final String playerName = playerData?['name']?.toString().toUpperCase() ?? "VACÍO";
    final String? playerPhone = playerData?['phone']?.toString();
    final String? photoUrl = playerData?['photoUrl']?.toString();
    
    List<dynamic> matchScores = playerData?['score'] ?? [];

    // Estilo para el nombre (negrita para ganador, gris para BYE)
    TextStyle nameTextStyle = TextStyle(
      color: playerName.toLowerCase().contains("bye") ? Colors.grey : chalkWhite,
      fontWeight: (isWinner && isPlayed) ? FontWeight.bold : FontWeight.normal,
      fontSize: 12,
    );

    return InkWell(
      onTap: onAddPlayer, // Only callable if isAdmin and player is null
      child: Container(
        height: playerRowHeight,
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        // Eliminamos el BoxDecoration del Container para que el MatchBoxPainter dibuje las líneas
        child: Row(
          children: [
            // Avatar/Foto
            Container( // Wrap CircleAvatar to apply conditional border
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isWinner && isPlayed ? const Color(0xFF00FFCC) : Colors.transparent, // Verde neón brillante
                  width: isWinner && isPlayed ? 2.0 : 0.0,
                ),
              ),
              child: CircleAvatar(
                radius: 15,
                backgroundColor: Colors.grey.shade800,
                backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                    ? NetworkImage(photoUrl) as ImageProvider
                    : null,
                child: photoUrl == null || photoUrl.isEmpty
                    ? Icon(Icons.person, color: chalkWhite.withOpacity(0.6), size: 20)
                    : null,
              ),
            ),
            // Icono WhatsApp (moved next to name)
            if (playerData != null && isAdmin && playerPhone != null && playerPhone.isNotEmpty)
              InkWell(
                onTap: () => onLaunchWhatsApp(playerPhone, playerName, opponentName, isPlayed, matchScores),
                child: const Padding(
                  padding: EdgeInsets.only(left: 6.0, right: 4.0), // Smaller padding to be closer
                  child: Icon(Icons.message_rounded, color: Colors.greenAccent, size: 16), // Cambiado a Icons.message_rounded
                ),
              ),
            // Contenedor de Nombre
            Expanded(
              child: Opacity(
                opacity: (isPlayed && !isWinner) ? 0.4 : 1.0,
                child: Text(
                  playerName,
                  style: nameTextStyle,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            // Celdas de Score (siempre 3, ajustando si menos sets se juegan)
            ...List.generate(3, (setIndex) {
              String scoreText = '';
              if (matchScores.length > setIndex) {
                scoreText = _formatDisplayScorePlayerRow(matchScores[setIndex].toString(), isWinner);
              }
              // Making score cells interactive for admin
              return InkWell(
                onTap: isAdmin && onShowScoreModal != null ? onShowScoreModal : null,
                child: Container(
                  width: 35, // Ancho fijo para las celdas de score
                  alignment: Alignment.center,
                  margin: const EdgeInsets.only(left: 4.0),
                  decoration: BoxDecoration(
                    color: Colors.white10, // Fondo sutil muy oscuro
                    borderRadius: BorderRadius.circular(4), // Bordes redondeados
                    border: Border.all(color: Colors.white10, width: 0.5), // Bordes finos
                  ),
                  child: Text(
                    scoreText,
                    style: TextStyle(
                      color: chalkWhite.withOpacity((isPlayed && !isWinner) ? 0.4 : 1.0),
                      fontSize: 10,
                      fontWeight: (isWinner && isPlayed) ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
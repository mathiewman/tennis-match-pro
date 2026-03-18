import 'dart:convert';
import 'package:http/http.dart' as http;

class MercadoPagoService {
  // TODO: Reemplazar con credenciales reales de Mercado Pago
  final String _accessToken = "TEST-YOUR-ACCESS-TOKEN";
  final String _publicKey = "TEST-YOUR-PUBLIC-KEY";

  Future<Map<String, dynamic>?> createPreference({
    required String title,
    required double tournamentPrice,
    required String tournamentId,
    required String userId,
  }) async {
    final double platformFee = tournamentPrice * 0.10;
    final double totalAmount = tournamentPrice + platformFee;

    final url = Uri.parse('https://api.mercadopago.com/checkout/preferences');

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $_accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "items": [
            {
              "title": title,
              "quantity": 1,
              "unit_price": tournamentPrice,
              "currency_id": "ARS",
              "description": "Inscripción a Torneo"
            },
            {
              "title": "Tasa de Servicio App",
              "quantity": 1,
              "unit_price": platformFee,
              "currency_id": "ARS",
              "description": "Gestión de plataforma"
            }
          ],
          "payer": {
            "email": "test_user@test.com" // TODO: Usar el mail del usuario actual
          },
          "back_urls": {
            "success": "https://yourapp.com/success",
            "failure": "https://yourapp.com/failure",
            "pending": "https://yourapp.com/pending"
          },
          "auto_return": "approved",
          "external_reference": jsonEncode({
            "tournamentId": tournamentId,
            "userId": userId,
            "netAmount": tournamentPrice,
            "platformFee": platformFee
          }),
          "notification_url": "https://your-webhook-url.com/mercadopago",
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print("Error MP: ${response.body}");
        return null;
      }
    } catch (e) {
      print("Exception MP: $e");
      return null;
    }
  }
}

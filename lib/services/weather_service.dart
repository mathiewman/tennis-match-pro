import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class WeatherService {
  Future<DateTime?> getSunsetTime(double lat, double lng, DateTime date) async {
    try {
      final String dateStr = DateFormat('yyyy-MM-dd').format(date);
      final response = await http.get(Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lng&daily=sunset&timezone=auto&start_date=$dateStr&end_date=$dateStr'));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final String sunsetStr = data['daily']['sunset'][0];
        return DateTime.parse(sunsetStr);
      }
    } catch (e) {
      print('Error fetching sunset: $e');
    }
    return null;
  }
}

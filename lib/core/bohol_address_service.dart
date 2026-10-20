import 'dart:convert';

import 'package:http/http.dart' as http;

class BoholArea {
  const BoholArea({required this.code, required this.name});

  final String code;
  final String name;
}

class BoholAddressService {
  static const municipalities = <BoholArea>[
    BoholArea(code: '071201000', name: 'Alburquerque'),
    BoholArea(code: '071202000', name: 'Alicia'),
    BoholArea(code: '071203000', name: 'Anda'),
    BoholArea(code: '071204000', name: 'Antequera'),
    BoholArea(code: '071205000', name: 'Baclayon'),
    BoholArea(code: '071206000', name: 'Balilihan'),
    BoholArea(code: '071207000', name: 'Batuan'),
    BoholArea(code: '071208000', name: 'Bilar'),
    BoholArea(code: '071209000', name: 'Buenavista'),
    BoholArea(code: '071210000', name: 'Calape'),
    BoholArea(code: '071211000', name: 'Candijay'),
    BoholArea(code: '071212000', name: 'Carmen'),
    BoholArea(code: '071213000', name: 'Catigbian'),
    BoholArea(code: '071214000', name: 'Clarin'),
    BoholArea(code: '071215000', name: 'Corella'),
    BoholArea(code: '071216000', name: 'Cortes'),
    BoholArea(code: '071217000', name: 'Dagohoy'),
    BoholArea(code: '071218000', name: 'Danao'),
    BoholArea(code: '071219000', name: 'Dauis'),
    BoholArea(code: '071220000', name: 'Dimiao'),
    BoholArea(code: '071221000', name: 'Duero'),
    BoholArea(code: '071222000', name: 'Garcia Hernandez'),
    BoholArea(code: '071223000', name: 'Guindulman'),
    BoholArea(code: '071224000', name: 'Inabanga'),
    BoholArea(code: '071225000', name: 'Jagna'),
    BoholArea(code: '071226000', name: 'Getafe'),
    BoholArea(code: '071227000', name: 'Lila'),
    BoholArea(code: '071228000', name: 'Loay'),
    BoholArea(code: '071229000', name: 'Loboc'),
    BoholArea(code: '071230000', name: 'Loon'),
    BoholArea(code: '071231000', name: 'Mabini'),
    BoholArea(code: '071232000', name: 'Maribojoc'),
    BoholArea(code: '071233000', name: 'Panglao'),
    BoholArea(code: '071234000', name: 'Pilar'),
    BoholArea(code: '071235000', name: 'President Carlos P. Garcia'),
    BoholArea(code: '071236000', name: 'Sagbayan'),
    BoholArea(code: '071237000', name: 'San Isidro'),
    BoholArea(code: '071238000', name: 'San Miguel'),
    BoholArea(code: '071239000', name: 'Sevilla'),
    BoholArea(code: '071240000', name: 'Sierra Bullones'),
    BoholArea(code: '071241000', name: 'Sikatuna'),
    BoholArea(code: '071242000', name: 'Tagbilaran City'),
    BoholArea(code: '071243000', name: 'Talibon'),
    BoholArea(code: '071244000', name: 'Trinidad'),
    BoholArea(code: '071245000', name: 'Tubigon'),
    BoholArea(code: '071246000', name: 'Ubay'),
    BoholArea(code: '071247000', name: 'Valencia'),
    BoholArea(code: '071248000', name: 'Bien Unido'),
  ];

  static final _barangayCache = <String, Future<List<BoholArea>>>{};

  static Future<List<BoholArea>> barangaysFor(BoholArea municipality) {
    if (!municipalities.any((area) => area.code == municipality.code)) {
      throw ArgumentError.value(municipality.code, 'municipality');
    }
    return _barangayCache.putIfAbsent(
      municipality.code,
      () => _fetchBarangays(municipality.code),
    );
  }

  static Future<List<BoholArea>> _fetchBarangays(
      String municipalityCode) async {
    try {
      final uri = Uri.https(
        'psgc.gitlab.io',
        '/api/cities-municipalities/$municipalityCode/barangays/',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw Exception('Could not load Bohol barangays. Try again.');
      }

      final decoded = jsonDecode(response.body);
      if (decoded is! List) {
        throw const FormatException('Invalid Bohol barangay response.');
      }

      final areas = decoded
          .whereType<Map<String, dynamic>>()
          .map((row) => BoholArea(
                code: row['code'].toString(),
                name: row['name'].toString(),
              ))
          .toList()
        ..sort((first, second) => first.name.compareTo(second.name));
      return areas;
    } catch (_) {
      _barangayCache.remove(municipalityCode);
      rethrow;
    }
  }
}

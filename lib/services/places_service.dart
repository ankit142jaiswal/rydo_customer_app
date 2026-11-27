import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class PlaceSuggestion {
  final String placeId;
  final String title;
  final String subtitle;

  /// Set for suggestions that already carry coordinates (OpenStreetMap fallback).
  final double? lat;
  final double? lng;
  const PlaceSuggestion(this.placeId, this.title, this.subtitle, {this.lat, this.lng});

  String get description => subtitle.isEmpty ? title : '$title, $subtitle';
}

/// Address autocomplete.
///
/// Uses Google Places API (New) when a real key is configured and working.
/// Otherwise falls back to OpenStreetMap Photon so suggestions still appear.
class PlacesService {
  static const _base = 'https://places.googleapis.com/v1';
  static const _photon = 'https://photon.komoot.io/api/';

  /// Last problem seen with the Google call (for debugging / UI hints).
  static String? lastError;

  static bool get _hasGoogleKey {
    final k = ApiConfig.googleMapsApiKey;
    return k.isNotEmpty && !k.startsWith('YOUR_');
  }

  static Map<String, String> _headers([String? fieldMask]) => {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': ApiConfig.googleMapsApiKey,
        if (fieldMask != null) 'X-Goog-FieldMask': fieldMask,
      };

  static Future<List<PlaceSuggestion>> autocomplete(
    String input, {
    double? lat,
    double? lng,
  }) async {
    if (input.trim().length < 2) return [];
    lastError = null;
    if (_hasGoogleKey) {
      final g = await _googleAutocomplete(input, lat: lat, lng: lng);
      if (g != null) return g;
    } else {
      lastError = 'No Google Maps API key set (use --dart-define=MAPS_API_KEY=...)';
      debugPrint('PlacesService: $lastError. Using OpenStreetMap fallback.');
    }
    return _photonAutocomplete(input, lat: lat, lng: lng);
  }

  /// Returns null when the Google request failed (so the caller can fall back).
  static Future<List<PlaceSuggestion>?> _googleAutocomplete(String input,
      {double? lat, double? lng}) async {
    try {
      final body = {
        'input': input,
        'includedRegionCodes': ['in'],
        if (lat != null && lng != null)
          'locationBias': {
            'circle': {
              'center': {'latitude': lat, 'longitude': lng},
              'radius': 50000.0,
            }
          },
      };
      final res = await http
          .post(Uri.parse('$_base/places:autocomplete'), headers: _headers(), body: jsonEncode(body))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) {
        lastError = 'Google Places ${res.statusCode}: ${res.body}';
        debugPrint('PlacesService: $lastError');
        return null;
      }
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final out = <PlaceSuggestion>[];
      for (final s in (data['suggestions'] as List? ?? [])) {
        final p = s['placePrediction'];
        if (p == null) continue;
        final sf = p['structuredFormat'];
        out.add(PlaceSuggestion(
          p['placeId'] as String,
          (sf?['mainText']?['text'] ?? p['text']?['text'] ?? '') as String,
          (sf?['secondaryText']?['text'] ?? '') as String,
        ));
      }
      return out;
    } catch (e) {
      lastError = 'Google Places failed: $e';
      debugPrint('PlacesService: $lastError');
      return null;
    }
  }

  static Future<List<PlaceSuggestion>> _photonAutocomplete(String input,
      {double? lat, double? lng}) async {
    try {
      final uri = Uri.parse(_photon).replace(queryParameters: {
        'q': input,
        'limit': '8',
        if (lat != null && lng != null) ...{'lat': '$lat', 'lon': '$lng'},
      });
      final res = await http.get(uri, headers: {'User-Agent': 'Rydo-customer-app'}).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) {
        debugPrint('PlacesService: Photon ${res.statusCode}');
        return [];
      }
      final features = (jsonDecode(res.body)['features'] as List? ?? []);
      final out = <PlaceSuggestion>[];
      for (final f in features) {
        final props = (f['properties'] ?? {}) as Map<String, dynamic>;
        if (props['countrycode'] != null && props['countrycode'] != 'IN') continue;
        final coords = f['geometry']?['coordinates'] as List?;
        if (coords == null || coords.length < 2) continue;

        final name = (props['name'] ?? props['street'] ?? '').toString();
        final street = props['name'] != null ? props['street'] : null;
        final parts = <String?>[
          street?.toString(),
          props['district']?.toString(),
          props['city']?.toString() ?? props['county']?.toString(),
          props['state']?.toString(),
        ].where((s) => s != null && s.isNotEmpty && s != name).cast<String>().toList();
        if (name.isEmpty && parts.isEmpty) continue;
        out.add(PlaceSuggestion(
          'osm_${props['osm_id']}_${coords[0]}_${coords[1]}',
          name.isEmpty ? parts.first : name,
          name.isEmpty ? parts.skip(1).join(', ') : parts.join(', '),
          lat: (coords[1] as num).toDouble(),
          lng: (coords[0] as num).toDouble(),
        ));
      }
      return out;
    } catch (e) {
      debugPrint('PlacesService: Photon failed: $e');
      return [];
    }
  }

  /// Reverse geocode via Photon (used when the platform geocoder is unavailable,
  /// e.g. Windows/web). Returns null on failure.
  static Future<String?> reverse(double lat, double lng) async {
    try {
      final uri = Uri.parse('${_photon}reverse').replace(queryParameters: {'lat': '$lat', 'lon': '$lng'});
      final res = await http.get(uri, headers: {'User-Agent': 'Rydo-customer-app'}).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return null;
      final features = jsonDecode(res.body)['features'] as List? ?? [];
      if (features.isEmpty) return null;
      final p = (features.first['properties'] ?? {}) as Map<String, dynamic>;
      final parts = <String>[
        for (final k in ['name', 'street', 'district', 'city', 'state'])
          if (p[k] != null && p[k].toString().isNotEmpty) p[k].toString(),
      ];
      final seen = <String>{};
      final unique = parts.where(seen.add).toList();
      return unique.isEmpty ? null : unique.join(', ');
    } catch (e) {
      debugPrint('PlacesService: reverse failed: $e');
      return null;
    }
  }

  /// Returns (lat, lng) for a Google place id, or null on failure.
  static Future<({double lat, double lng})?> details(PlaceSuggestion s) async {
    if (s.lat != null && s.lng != null) return (lat: s.lat!, lng: s.lng!);
    try {
      final res = await http
          .get(Uri.parse('$_base/places/${s.placeId}'), headers: _headers('location'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) {
        debugPrint('PlacesService: details ${res.statusCode}: ${res.body}');
        return null;
      }
      final loc = (jsonDecode(res.body) as Map<String, dynamic>)['location'];
      return (lat: (loc['latitude'] as num).toDouble(), lng: (loc['longitude'] as num).toDouble());
    } catch (e) {
      debugPrint('PlacesService: details failed: $e');
      return null;
    }
  }
}

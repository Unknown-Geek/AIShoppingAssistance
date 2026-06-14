import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/cart_item_model.dart';
import 'inventory_service.dart';

abstract class ProductDetectionService {
  Future<CartItemModel?> detectItem(XFile photo);
}

class HuggingFaceProxyDetectionService implements ProductDetectionService {
  final String _baseUrl;
  late final String _chromaApiKey;

  HuggingFaceProxyDetectionService({String? baseUrl})
      : _baseUrl = baseUrl ?? (dotenv.env['HF_SPACE_URL'] ?? '').replaceAll('/embed', '') {
    _chromaApiKey = dotenv.env['CHROMA_API_KEY'] ?? '';
    
    if (_baseUrl.isEmpty) {
      debugPrint('Warning: HF_SPACE_URL is not set in .env');
    }
  }

  @override
  Future<CartItemModel?> detectItem(XFile photo) async {
    debugPrint('--- UNIFIED DETECT START ---');
    debugPrint('Captured photo path: ${photo.path}');

    if (_baseUrl.isEmpty) {
      debugPrint('[ProductDetectionService] Error: Base URL is empty');
      return null;
    }

    final url = Uri.parse('$_baseUrl/detect');
    debugPrint('Request URL: $url');

    final overallStopwatch = Stopwatch()..start();
    try {
      final request = http.MultipartRequest('POST', url);
      final bytes = await photo.readAsBytes();
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: 'image.jpg',
          contentType: MediaType('image', 'jpeg'),
        ),
      );

      // Securely pass secrets in headers (omitting Supabase to bypass DB lookup latency)
      request.headers.addAll({
        'X-Chroma-Token': _chromaApiKey,
      });

      final networkStopwatch = Stopwatch()..start();
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      networkStopwatch.stop();

      debugPrint('Detect Response Status Code: ${response.statusCode}');
      debugPrint('Detect Response Body: ${response.body}');
      debugPrint('[ProductDetectionService] Network roundtrip took: ${networkStopwatch.elapsedMilliseconds}ms');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          final bool matchFound = data['match_found'] ?? false;
          if (!matchFound) {
            debugPrint('[ProductDetectionService] No confident match found on server. Reason: ${data['reason']}');
            overallStopwatch.stop();
            debugPrint('[ProductDetectionService] Overall detection took: ${overallStopwatch.elapsedMilliseconds}ms');
            return null;
          }

          final itemData = data['item'];
          if (itemData != null) {
            final String slug = itemData['slug'] ?? '';
            
            // Resolve product metadata locally in 0ms to bypass Supabase network query
            final inventoryService = InventoryService();
            final localProduct = inventoryService.getProductFromLocal(slug);
            
            final String sku = localProduct != null ? (localProduct['sku'] ?? 'UNLISTED') : (itemData['sku'] ?? 'UNLISTED');
            final String name = localProduct != null ? (localProduct['name'] ?? 'Unknown Product') : (itemData['name'] ?? 'Unknown Product');
            final double priceRupees = localProduct != null 
                ? (localProduct['price_rupees'] as num?)?.toDouble() ?? 0.0
                : (itemData['price_rupees'] as num?)?.toDouble() ?? 0.0;

            overallStopwatch.stop();
            debugPrint('[ProductDetectionService] Matched: $name (SLU: $slug, SKU: $sku, Price: ₹$priceRupees, LocalResolved: ${localProduct != null})');
            debugPrint('[ProductDetectionService] Overall detection took: ${overallStopwatch.elapsedMilliseconds}ms');

            // Fetch thumbnail_url from Supabase and cache it (non-blocking is
            // fine here — we await it so the image is ready for the confirm sheet)
            await inventoryService.getProductBySlug(slug);

            return CartItemModel(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              name: name,
              details: "SKU: $sku • ₹${priceRupees.toStringAsFixed(2)}",
              imageUrl: inventoryService.getImageUrl(slug),
              price: priceRupees,
              quantity: 1,
            );
          }
        } else {
          debugPrint('[ProductDetectionService] Server error: ${data['message']}');
        }
      } else {
        debugPrint('[ProductDetectionService] Network error: Status ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[ProductDetectionService] Exception during detect: $e');
    }
    
    overallStopwatch.stop();
    debugPrint('[ProductDetectionService] Overall detection took (failed/no-match): ${overallStopwatch.elapsedMilliseconds}ms');
    debugPrint('--- UNIFIED DETECT END (NO MATCH) ---');
    return null;
  }
}

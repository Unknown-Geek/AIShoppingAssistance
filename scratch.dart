import 'dart:convert';
import 'dart:io';

void main() {
  final file = File('inventory.json');
  final jsonStr = file.readAsStringSync();
  final data = jsonDecode(jsonStr);
  final items = data['items'] as List;
  
  for (var item in items) {
    if (item['name'].toString().toLowerCase().contains('multiple') || item['name'].toString().toLowerCase().contains('pack')) {
      print('${item['name']} - ${item['price_rupees']}');
    }
  }
}

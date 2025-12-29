import 'package:supabase_flutter/supabase_flutter.dart';

class KitProduct {
  final String id;
  final String category; // 'male', 'female', 'hoodie'
  final String productName;
  final double price;
  final String stripeUrl;
  final Map<String, int> stock; // Size -> quantity

  KitProduct({
    required this.id,
    required this.category,
    required this.productName,
    required this.price,
    required this.stripeUrl,
    required this.stock,
  });

  factory KitProduct.fromJson(Map<String, dynamic> json) {
    return KitProduct(
      id: json['id'] as String,
      category: json['category'] as String,
      productName: json['product_name'] as String,
      price: (json['price'] as num).toDouble(),
      stripeUrl: json['stripe_url'] as String,
      stock: {
        'XS': json['stock_xs'] as int? ?? 0,
        'S': json['stock_s'] as int? ?? 0,
        'M': json['stock_m'] as int? ?? 0,
        'L': json['stock_l'] as int? ?? 0,
        'XL': json['stock_xl'] as int? ?? 0,
        'XXL': json['stock_xxl'] as int? ?? 0,
      },
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'product_name': productName,
      'price': price,
      'stripe_url': stripeUrl,
      'stock_xs': stock['XS'] ?? 0,
      'stock_s': stock['S'] ?? 0,
      'stock_m': stock['M'] ?? 0,
      'stock_l': stock['L'] ?? 0,
      'stock_xl': stock['XL'] ?? 0,
      'stock_xxl': stock['XXL'] ?? 0,
    };
  }
}

class KitProductsService {
  final _supabase = Supabase.instance.client;

  Future<List<KitProduct>> getProductsByCategory(String category) async {
    try {
      final response = await _supabase
          .from('kit_products')
          .select()
          .eq('category', category)
          .order('product_name', ascending: true);

      final products = (response as List)
          .map((json) => KitProduct.fromJson(json))
          .toList();

      // Remove duplicates based on product name
      final seen = <String>{};
      return products
          .where((product) => seen.add(product.productName))
          .toList();
    } catch (e) {
      print('Error fetching products: $e');
      return [];
    }
  }

  Future<KitProduct?> getProductById(String id) async {
    try {
      final response = await _supabase
          .from('kit_products')
          .select()
          .eq('id', id)
          .single();
      return KitProduct.fromJson(response);
    } catch (e) {
      print('Error fetching product: $e');
      return null;
    }
  }

  Future<bool> updateProductStock(String id, Map<String, int> stock) async {
    try {
      await _supabase
          .from('kit_products')
          .update({
            'stock_xs': stock['XS'] ?? 0,
            'stock_s': stock['S'] ?? 0,
            'stock_m': stock['M'] ?? 0,
            'stock_l': stock['L'] ?? 0,
            'stock_xl': stock['XL'] ?? 0,
            'stock_xxl': stock['XXL'] ?? 0,
          })
          .eq('id', id);
      return true;
    } catch (e) {
      print('Error updating stock: $e');
      return false;
    }
  }

  Future<bool> updateProduct(String id, KitProduct product) async {
    try {
      await _supabase
          .from('kit_products')
          .update(product.toJson())
          .eq('id', id);
      return true;
    } catch (e) {
      print('Error updating product: $e');
      return false;
    }
  }

  Future<bool> addProduct(KitProduct product) async {
    try {
      await _supabase.from('kit_products').insert(product.toJson());
      return true;
    } catch (e) {
      print('Error adding product: $e');
      return false;
    }
  }

  Future<bool> deleteProduct(String id) async {
    try {
      await _supabase.from('kit_products').delete().eq('id', id);
      return true;
    } catch (e) {
      print('Error deleting product: $e');
      return false;
    }
  }
}

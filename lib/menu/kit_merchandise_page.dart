import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:runrank/services/kit_products_service.dart';
import 'package:runrank/services/user_service.dart';

class KitMerchandisePage extends StatefulWidget {
  const KitMerchandisePage({super.key});

  @override
  State<KitMerchandisePage> createState() => _KitMerchandisePageState();
}

class _KitMerchandisePageState extends State<KitMerchandisePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _service = KitProductsService();

  late Future<List<KitProduct>> _maleProducts;
  late Future<List<KitProduct>> _femaleProducts;
  late Future<List<KitProduct>> _hoodies;
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    _isAdmin = await UserService.isAdmin();
    _maleProducts = _service.getProductsByCategory('male');
    _femaleProducts = _service.getProductsByCategory('female');
    _hoodies = _service.getProductsByCategory('hoodie');
    setState(() {});
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showStripeCheckout(String stripeUrl) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        contentPadding: EdgeInsets.zero,
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.95,
          height: MediaQuery.of(context).size.height * 0.8,
          child: WebViewWidget(
            controller: WebViewController()
              ..setJavaScriptMode(JavaScriptMode.unrestricted)
              ..loadRequest(Uri.parse(stripeUrl)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Close',
              style: TextStyle(color: Color(0xFF0055FF)),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditStockDialog(KitProduct product) {
    if (!_isAdmin) return;

    final controllers = <String, TextEditingController>{};
    for (final entry in product.stock.entries) {
      controllers[entry.key] = TextEditingController(
        text: entry.value.toString(),
      );
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1D2E),
        title: Text(
          'Edit ${product.productName}',
          style: const TextStyle(color: Color(0xFFFFD700)),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ...controllers.entries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextField(
                    controller: entry.value,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Size ${entry.key}',
                      labelStyle: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final updatedStock = <String, int>{};
              controllers.forEach((size, controller) {
                updatedStock[size] = int.tryParse(controller.text) ?? 0;
              });

              final success = await _service.updateProductStock(
                product.id,
                updatedStock,
              );
              if (success && mounted) {
                Navigator.pop(context);
                _loadData();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: Colors.black,
            ),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        title: const Text(
          'Kit & Merchandise',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFFFD700),
          labelColor: const Color(0xFFFFD700),
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: 'Male Kit'),
            Tab(text: 'Female Kit'),
            Tab(text: 'Hoodies'),
          ],
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white.withValues(alpha: 0.05),
            child: Row(
              children: [
                const Icon(
                  Icons.local_shipping,
                  color: Color(0xFF0055FF),
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'All deliveries will be made to the tennis club',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                if (_isAdmin)
                  Tooltip(
                    message: 'Admin: Long-press to edit stock',
                    child: Icon(
                      Icons.edit,
                      color: const Color(0xFFFFD700).withValues(alpha: 0.6),
                      size: 18,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildProductTab(_maleProducts),
                _buildProductTab(_femaleProducts),
                _buildProductTab(_hoodies),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductTab(Future<List<KitProduct>> productsFuture) {
    return FutureBuilder<List<KitProduct>>(
      future: productsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF0055FF)),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Text(
              'No products available',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        final products = snapshot.data!;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: products
              .map((product) => _buildProductCard(product))
              .toList(),
        );
      },
    );
  }

  Widget _buildProductCard(KitProduct product) {
    final hasStock = product.stock.values.any((qty) => qty > 0);

    return GestureDetector(
      onLongPress: _isAdmin ? () => _showEditStockDialog(product) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withValues(alpha: 0.08),
              Colors.white.withValues(alpha: 0.02),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasStock
                ? const Color(0xFF0055FF).withValues(alpha: 0.3)
                : Colors.red.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      product.productName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFFFD700),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '£${product.price.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFFFD700),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Available Sizes:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: product.stock.entries.map((entry) {
                  final size = entry.key;
                  final qty = entry.value;
                  final inStock = qty > 0;

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: inStock
                          ? const Color(0xFF0055FF).withValues(alpha: 0.2)
                          : Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: inStock
                            ? const Color(0xFF0055FF).withValues(alpha: 0.5)
                            : Colors.red.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          size,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: inStock ? Colors.white : Colors.white38,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          inStock ? '$qty left' : 'Out',
                          style: TextStyle(
                            fontSize: 10,
                            color: inStock
                                ? const Color(0xFF0055FF)
                                : Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: hasStock
                      ? () => _showStripeCheckout(product.stripeUrl)
                      : null,
                  icon: Icon(
                    hasStock ? Icons.shopping_cart : Icons.block,
                    size: 18,
                  ),
                  label: Text(
                    hasStock ? 'Buy Now' : 'Out of Stock',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasStock
                        ? const Color(0xFFFFD700)
                        : Colors.grey.shade700,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: hasStock ? 4 : 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:runrank/services/kit_products_service.dart';
import 'package:runrank/services/payment_service.dart';
import 'package:runrank/services/user_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class KitMerchandisePage extends StatefulWidget {
  const KitMerchandisePage({super.key});

  @override
  State<KitMerchandisePage> createState() => _KitMerchandisePageState();
}

class _KitMerchandisePageState extends State<KitMerchandisePage>
    with SingleTickerProviderStateMixin {
  final _client = Supabase.instance.client;
  final _service = KitProductsService();

  late TabController _tabController;

  Future<List<KitProduct>>? _firstProducts;
  Future<List<KitProduct>>? _secondProducts;
  Future<List<KitProduct>>? _thirdProducts;

  bool _isAdmin = false;
  String? _clubName = UserService.cachedClubName;

  late List<_KitTabDefinition> _activeTabs;

  static const List<_KitTabDefinition> _loadingTabs = [
    _KitTabDefinition(title: 'Kit', category: 'loading-1'),
    _KitTabDefinition(title: 'Merch', category: 'loading-2'),
    _KitTabDefinition(title: 'Shop', category: 'loading-3'),
  ];

  static const List<String> _defaultSizes = ['XS', 'S', 'M', 'L', 'XL', 'XXL'];

  static const List<_KitTabDefinition> _nnbrTabs = [
    _KitTabDefinition(title: 'Male Kit', category: 'male'),
    _KitTabDefinition(title: 'Female Kit', category: 'female'),
    _KitTabDefinition(title: 'Hoodies', category: 'hoodie'),
  ];

  static const List<_KitTabDefinition> _nrrTabs = [
    _KitTabDefinition(title: 'Race Kits', category: 'race'),
    _KitTabDefinition(title: 'Training Kits', category: 'training'),
    _KitTabDefinition(title: 'Leisure Kit', category: 'leisure'),
  ];

  static const Map<String, List<_NrrKitItemConfig>> _nrrCatalog = {
    'race': [
      _NrrKitItemConfig(
        productName: 'Drylite Vest',
        price: 25,
        imageAssets: ['assets/images/dryVest.png'],
        sizes: _defaultSizes,
      ),
      _NrrKitItemConfig(
        productName: 'Drylite T-Shirt',
        price: 25,
        imageAssets: ['assets/images/dryT.png'],
        sizes: _defaultSizes,
      ),
      _NrrKitItemConfig(
        productName: 'Scimitar Vest',
        price: 30,
        imageAssets: [
          'assets/images/scimVest1.png',
          'assets/images/scimVest2.png',
        ],
        sizes: _defaultSizes,
      ),
      _NrrKitItemConfig(
        productName: 'Scimitar T-Shirt',
        price: 30,
        imageAssets: ['assets/images/scimT1.png', 'assets/images/scimT2.png'],
        sizes: _defaultSizes,
      ),
    ],
    'training': [
      _NrrKitItemConfig(
        productName: 'Training Top',
        price: 25,
        imageAssets: ['assets/images/trainT1.png', 'assets/images/trainT2.png'],
        sizes: _defaultSizes,
      ),
    ],
    'leisure': [
      _NrrKitItemConfig(
        productName: 'Leisure Hoodie',
        price: 35,
        imageAssets: ['assets/images/leisurehoody.png'],
        sizes: _defaultSizes,
      ),
      _NrrKitItemConfig(
        productName: 'Buff',
        price: 8,
        imageAssets: ['assets/images/buff.png'],
        sizes: ['OS'],
      ),
      _NrrKitItemConfig(
        productName: 'Beanie',
        price: 10,
        imageAssets: ['assets/images/beany.png'],
        sizes: ['OS'],
      ),
    ],
  };

  final List<_BasketItem> _basket = [];

  bool get _clubResolved => (_clubName ?? '').trim().isNotEmpty;

  bool get _isNrrClub {
    final lower = (_clubName ?? '').trim().toLowerCase();
    return lower == 'nrr' || lower.contains('norwich road runners');
  }

  @override
  void initState() {
    super.initState();
    _activeTabs = !_clubResolved
        ? _loadingTabs
        : (_isNrrClub ? _nrrTabs : _nnbrTabs);
    _tabController = TabController(length: _activeTabs.length, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final isAdmin = await UserService.isAdmin();
      final clubName = await UserService.currentClubName();

      final lower = (clubName ?? '').trim().toLowerCase();
      final isNrrClub =
          lower == 'nrr' || lower.contains('norwich road runners');

      Future<List<KitProduct>> first;
      Future<List<KitProduct>> second;
      Future<List<KitProduct>> third;

      if (isNrrClub) {
        first = _service.getProductsByCategory('race');
        second = _service.getProductsByCategory('training');
        third = _service.getProductsByCategory('leisure');
      } else {
        first = _service.getProductsByCategory('male');
        second = _service.getProductsByCategory('female');
        third = _service.getProductsByCategory('hoodie');
      }

      if (!mounted) return;

      setState(() {
        _isAdmin = isAdmin;
        _clubName = clubName;
        _activeTabs = isNrrClub ? _nrrTabs : _nnbrTabs;
        _firstProducts = first;
        _secondProducts = second;
        _thirdProducts = third;
      });
    } catch (e) {
      debugPrint('Error loading kit data: $e');
    }
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

    final priceController = TextEditingController(
      text: product.price.toStringAsFixed(2),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color.fromARGB(255, 51, 75, 213),
        title: Text(
          'Edit ${product.productName}',
          style: const TextStyle(color: Color(0xFFFFD700)),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: TextField(
                  controller: priceController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Price (£)',
                    labelStyle: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
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
              final navigator = Navigator.of(context);
              final updatedStock = <String, int>{};
              controllers.forEach((size, controller) {
                updatedStock[size] = int.tryParse(controller.text) ?? 0;
              });

              final rawPrice = priceController.text.trim().replaceAll('£', '');
              double? newPrice = double.tryParse(rawPrice);
              newPrice ??= product.price;

              final bool success;
              // For NRR catalog-only items we synthesise a local id ("local:...").
              // When an admin first adds stock for these, insert a real row instead
              // of trying to update a non-existent one.
              if (product.id.startsWith('local:')) {
                final newProduct = KitProduct(
                  id: product.id,
                  category: product.category,
                  productName: product.productName,
                  price: newPrice,
                  stripeUrl: product.stripeUrl,
                  stock: updatedStock,
                  updatedAt: null,
                );
                success = await _service.addProduct(newProduct);
              } else {
                success = await _service.updateProductStock(
                  product.id,
                  updatedStock,
                  price: newPrice,
                );
              }
              if (!mounted) return;
              if (success) {
                navigator.pop();
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

  Future<void> _openExternalLink(String url) async {
    final uri = Uri.parse(url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open link.')));
    }
  }

  void _addToBasket(KitProduct product, String size) {
    final existingIndex = _basket.indexWhere(
      (item) => item.product.id == product.id && item.size == size,
    );

    setState(() {
      if (existingIndex >= 0) {
        _basket[existingIndex].quantity++;
      } else {
        _basket.add(_BasketItem(product: product, size: size, quantity: 1));
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added ${product.productName} ($size) to basket.'),
      ),
    );
  }

  void _showAddToBasketDialog(KitProduct product) {
    final visibleSizes = _visibleSizesForProduct(product);
    final availableSizes = visibleSizes
        .where((size) => (product.stock[size] ?? 0) > 0)
        .toList();

    if (availableSizes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This item is currently out of stock.')),
      );
      return;
    }

    String selectedSize = availableSizes.first;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text(
          'Add ${product.productName} to basket',
          style: const TextStyle(color: Colors.white),
        ),
        content: DropdownButtonFormField<String>(
          initialValue: selectedSize,
          dropdownColor: Colors.black,
          decoration: const InputDecoration(
            labelText: 'Size',
            labelStyle: TextStyle(color: Colors.white70),
          ),
          items: [
            for (final size in availableSizes)
              DropdownMenuItem(
                value: size,
                child: Text(size, style: const TextStyle(color: Colors.white)),
              ),
          ],
          onChanged: (value) {
            if (value != null) {
              selectedSize = value;
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70),
            ),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _addToBasket(product, selectedSize);
            },
            icon: const Icon(Icons.add_shopping_cart_outlined),
            label: const Text('Add to Basket'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = !_clubResolved
        ? const Color(0xFF6A6A6A)
        : _isNrrClub
        ? const Color(0xFFD32F2F)
        : const Color(0xFFFFD700);
    final bannerIcon = !_clubResolved
        ? Colors.white70
        : _isNrrClub
        ? const Color(0xFFD32F2F)
        : const Color(0xFF0055FF);

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
          indicatorColor: accent,
          labelColor: accent,
          unselectedLabelColor: Colors.white60,
          tabs: [for (final tab in _activeTabs) Tab(text: tab.title)],
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white.withValues(alpha: 0.05),
            child: Row(
              children: [
                Icon(
                  !_clubResolved
                      ? Icons.shopping_bag_outlined
                      : _isNrrClub
                      ? Icons.shopping_bag_outlined
                      : Icons.local_shipping,
                  color: bannerIcon,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: !_clubResolved
                      ? const Text(
                          'Loading club kit catalogue...',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      : _isNrrClub
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              'Purchase kit directly through NRR club and pay in cash or PayPal',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                const Text(
                                  'Alternatively, visit ',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => _openExternalLink(
                                    'https://www.sportlink.co.uk/',
                                  ),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: const Text(
                                    'Sportlink',
                                    style: TextStyle(fontSize: 13),
                                  ),
                                ),
                                const Text(
                                  ' online or in person',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        )
                      : const Text(
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
                    message: 'Admin: Long-press to edit stock and prices',
                    child: Icon(
                      Icons.edit,
                      color: accent.withValues(alpha: 0.7),
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
                !_clubResolved
                    ? const Center(child: CircularProgressIndicator())
                    : _buildProductTab(_activeTabs[0], _firstProducts),
                !_clubResolved
                    ? const Center(child: CircularProgressIndicator())
                    : _buildProductTab(_activeTabs[1], _secondProducts),
                !_clubResolved
                    ? const Center(child: CircularProgressIndicator())
                    : _buildProductTab(_activeTabs[2], _thirdProducts),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _clubResolved && _isNrrClub
          ? _buildBasketFab(accent)
          : null,
    );
  }

  Widget _buildBasketFab(Color accent) {
    final itemCount = _basket.fold<int>(0, (sum, item) => sum + item.quantity);

    return FloatingActionButton.extended(
      onPressed: () {
        if (_basket.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Your basket is empty. Add some kit items first.'),
            ),
          );
          return;
        }
        _showBasketSheet();
      },
      backgroundColor: accent,
      icon: const Icon(Icons.shopping_basket_outlined),
      label: Text(itemCount > 0 ? 'Basket ($itemCount)' : 'Basket'),
    );
  }

  void _showBasketSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF111111),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        if (_basket.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text(
                'Your basket is empty.',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          );
        }

        final total = _basket.fold<double>(
          0,
          (sum, item) => sum + item.product.price * item.quantity,
        );

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Basket',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Review your items, then tap Send Order to email the kit secretary.',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _basket.length,
                  separatorBuilder: (_, __) =>
                      const Divider(color: Colors.white24, height: 12),
                  itemBuilder: (context, index) {
                    final item = _basket[index];
                    final lineTotal = item.product.price * item.quantity;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        item.product.productName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        'Size ${item.size} \nQty ${item.quantity} · £${lineTotal.toStringAsFixed(2)}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                        ),
                        onPressed: () {
                          setState(() {
                            _basket.removeAt(index);
                          });
                          if (_basket.isEmpty && Navigator.canPop(ctx)) {
                            Navigator.pop(ctx);
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Estimated total',
                    style: TextStyle(color: Colors.white70),
                  ),
                  Text(
                    '£${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _sendBasketOrder();
                  },
                  icon: const Icon(Icons.send_outlined),
                  label: const Text('Send Order'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD32F2F),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _sendBasketOrder() async {
    if (_basket.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Your basket is empty.')));
      return;
    }

    try {
      final clubName = await UserService.currentClubName();
      if (clubName == null || clubName.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to determine your club. Please contact an administrator.',
            ),
          ),
        );
        return;
      }

      final committeeRows = await _client
          .from('committee_roles')
          .select('role, email')
          .eq('club', clubName);

      String? kitSecretaryEmail;
      for (final row in committeeRows) {
        final role = ((row['role'] as String?) ?? '').toLowerCase();
        final email = (row['email'] as String?)?.trim();
        if (role.contains('kit') && email != null && email.isNotEmpty) {
          kitSecretaryEmail = email;
          break;
        }
      }

      if (kitSecretaryEmail == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No Kit Secretary email is configured yet in the admin committee roles.',
            ),
          ),
        );
        return;
      }

      final buffer = StringBuffer();
      buffer.writeln('I would like to order the following NRR kit items:');
      buffer.writeln('');
      for (final item in _basket) {
        buffer.writeln(
          '${item.product.productName} — size ${item.size} × ${item.quantity} ( £${item.product.price.toStringAsFixed(2)} each )',
        );
      }
      buffer.writeln('');
      buffer.writeln(
        'Please confirm availability, total cost, and payment details (cash or PayPal).',
      );

      final subject = Uri.encodeComponent('NRR Kit Order');
      final body = Uri.encodeComponent(buffer.toString());
      final uri = Uri.parse(
        'mailto:$kitSecretaryEmail?subject=$subject&body=$body',
      );

      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open your email app.')),
        );
        return;
      }

      if (!mounted) return;
      setState(() {
        _basket.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'We\'ve prepared your kit order email. Once you send it, the club kit secretary will receive your order.',
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error sending kit order email: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not prepare kit order email: $e')),
      );
    }
  }

  Widget _buildProductTab(
    _KitTabDefinition tab,
    Future<List<KitProduct>>? productsFuture,
  ) {
    if (productsFuture == null) {
      return Center(
        child: CircularProgressIndicator(
          color: _isNrrClub ? const Color(0xFFD32F2F) : const Color(0xFF0055FF),
        ),
      );
    }

    return FutureBuilder<List<KitProduct>>(
      future: productsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: _isNrrClub
                  ? const Color(0xFFD32F2F)
                  : const Color(0xFF0055FF),
            ),
          );
        }

        if (!_isNrrClub && snapshot.hasError) {
          return const Center(
            child: Text(
              'Error loading products',
              style: TextStyle(color: Colors.redAccent),
            ),
          );
        }

        final products = _resolveProductsForTab(tab, snapshot.data ?? const []);
        if (products.isEmpty) {
          return const Center(
            child: Text(
              'No products available',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: products.length,
          itemBuilder: (context, index) => _buildProductCard(products[index]),
        );
      },
    );
  }

  List<KitProduct> _resolveProductsForTab(
    _KitTabDefinition tab,
    List<KitProduct> loadedProducts,
  ) {
    if (!_isNrrClub) return loadedProducts;

    final configs = _nrrCatalog[tab.category] ?? const <_NrrKitItemConfig>[];
    final byName = {
      for (final product in loadedProducts) product.productName: product,
    };

    return [
      for (final config in configs)
        byName[config.productName] ??
            KitProduct(
              id: 'local:${tab.category}:${config.productName}',
              category: tab.category,
              productName: config.productName,
              price: config.price,
              stripeUrl: '',
              stock: {
                'XS': 0,
                'S': 0,
                'M': 0,
                'L': 0,
                'XL': 0,
                'XXL': 0,
                'OS': 0,
              },
              updatedAt: null,
            ),
    ];
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = (date.year % 100).toString().padLeft(2, '0');
    return '$day/$month/$year';
  }

  List<String> _visibleSizesForProduct(KitProduct product) {
    if (!_isNrrClub) return _defaultSizes;
    return _findNrrConfig(product.productName)?.sizes ?? _defaultSizes;
  }

  _NrrKitItemConfig? _findNrrConfig(String productName) {
    for (final items in _nrrCatalog.values) {
      for (final item in items) {
        if (item.productName == productName) return item;
      }
    }
    return null;
  }

  Widget _buildProductImages(_NrrKitItemConfig config) {
    if (config.imageAssets.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 190,
          width: double.infinity,
          color: Colors.white,
          child: Image.asset(config.imageAssets.first, fit: BoxFit.contain),
        ),
      );
    }

    return SizedBox(
      height: 190,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: config.imageAssets.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) => ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 220,
            color: Colors.white,
            child: Image.asset(config.imageAssets[index], fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(KitProduct product) {
    final visibleSizes = _visibleSizesForProduct(product);
    final hasStock = visibleSizes.any((size) => (product.stock[size] ?? 0) > 0);
    final nrrConfig = _isNrrClub ? _findNrrConfig(product.productName) : null;
    final showOnlineBackupCheckout =
        _isNrrClub &&
        PaymentService.nrrKitPaymentsEnabled &&
        product.stripeUrl.trim().isNotEmpty;
    final borderColor = _isNrrClub
        ? (hasStock ? const Color(0xFFD32F2F) : const Color(0x66D32F2F))
        : (hasStock
              ? const Color(0xFF0055FF).withValues(alpha: 0.3)
              : Colors.red.withValues(alpha: 0.3));

    return GestureDetector(
      onLongPress: _isAdmin ? () => _showEditStockDialog(product) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _isNrrClub
                ? const [Color(0xFF161616), Color(0xFF0F0F10)]
                : [
                    Colors.white.withValues(alpha: 0.08),
                    Colors.white.withValues(alpha: 0.02),
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_isNrrClub && nrrConfig != null) ...[
                _buildProductImages(nrrConfig),
                const SizedBox(height: 16),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      product.productName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _isNrrClub
                          ? const Color(0xFFD32F2F).withValues(alpha: 0.18)
                          : const Color(0xFFFFD700).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isNrrClub
                            ? const Color(0xFFD32F2F)
                            : const Color(0xFFFFD700),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      '£${product.price.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _isNrrClub
                            ? Colors.white
                            : const Color(0xFFFFD700),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _isNrrClub ? 'Stock by Size:' : 'Available Sizes:',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                  if (product.updatedAt != null)
                    Text(
                      'Updated: ${_formatDate(product.updatedAt!)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.white54,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  const double spacing = 6;
                  const double minBadgeWidth = 46;
                  const double maxBadgeWidth = 78;

                  final maxWidth = constraints.maxWidth;
                  final itemCount = visibleSizes.length;
                  int targetColumns = itemCount.clamp(1, 8);

                  while (targetColumns > 1) {
                    final requiredWidth =
                        targetColumns * minBadgeWidth +
                        (targetColumns - 1) * spacing;
                    if (requiredWidth <= maxWidth) {
                      break;
                    }
                    targetColumns--;
                  }

                  final rawWidth =
                      (maxWidth - (targetColumns - 1) * spacing) /
                      targetColumns;
                  final badgeWidth = rawWidth
                      .clamp(minBadgeWidth, maxBadgeWidth)
                      .toDouble();

                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: visibleSizes.map((size) {
                      final qty = product.stock[size] ?? 0;
                      final inStock = qty > 0;
                      return Container(
                        width: badgeWidth,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: inStock
                              ? (_isNrrClub
                                    ? const Color(
                                        0xFFD32F2F,
                                      ).withValues(alpha: 0.18)
                                    : const Color(
                                        0xFF0055FF,
                                      ).withValues(alpha: 0.2))
                              : Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: inStock
                                ? (_isNrrClub
                                      ? const Color(
                                          0xFFD32F2F,
                                        ).withValues(alpha: 0.45)
                                      : const Color(
                                          0xFF0055FF,
                                        ).withValues(alpha: 0.5))
                                : Colors.red.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          children: [
                            Text(
                              size,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: inStock ? Colors.white : Colors.white38,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '$qty',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: inStock
                                    ? Colors.white
                                    : Colors.redAccent,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: hasStock
                      ? () {
                          if (_isNrrClub) {
                            _showAddToBasketDialog(product);
                          } else {
                            _showStripeCheckout(product.stripeUrl);
                          }
                        }
                      : null,
                  icon: Icon(
                    hasStock
                        ? (_isNrrClub
                              ? Icons.add_shopping_cart_outlined
                              : Icons.shopping_cart)
                        : Icons.block,
                    size: 18,
                  ),
                  label: Text(
                    hasStock
                        ? (_isNrrClub ? 'Add to Basket' : 'Buy Now')
                        : 'Out of Stock',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasStock
                        ? (_isNrrClub
                              ? const Color(0xFFD32F2F)
                              : const Color(0xFFFFD700))
                        : Colors.grey.shade700,
                    foregroundColor: _isNrrClub ? Colors.white : Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: hasStock ? 4 : 0,
                  ),
                ),
              ),
              if (showOnlineBackupCheckout) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: hasStock
                        ? () => _showStripeCheckout(product.stripeUrl)
                        : null,
                    icon: const Icon(Icons.payment_outlined, size: 18),
                    label: const Text(
                      'Backup Online Checkout',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFFD32F2F)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _KitTabDefinition {
  final String title;
  final String category;

  const _KitTabDefinition({required this.title, required this.category});
}

class _NrrKitItemConfig {
  final String productName;
  final double price;
  final List<String> imageAssets;
  final List<String> sizes;

  const _NrrKitItemConfig({
    required this.productName,
    required this.price,
    required this.imageAssets,
    required this.sizes,
  });
}

class _BasketItem {
  final KitProduct product;
  final String size;
  int quantity;

  _BasketItem({
    required this.product,
    required this.size,
    required this.quantity,
  });
}

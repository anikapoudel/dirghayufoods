import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/filter_provider.dart';
import '../services/api_service.dart';
import '../services/app_cache.dart';
import '../models/product_models.dart';
import '../models/category_models.dart';
import 'product_detail_screen.dart';
import '../providers/cart_provider.dart';
import 'cart_screen.dart';

class HomeScreen extends StatefulWidget {
  final ScrollController? scrollController;
  final VoidCallback? onNavigateToProducts;
  final Function(String)? onCategorySelected;

  const HomeScreen({
    super.key,
    this.scrollController,
    this.onNavigateToProducts,
    this.onCategorySelected,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  int _refreshTick = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    if (hour < 21) return 'Good Evening';
    return 'Good Night';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green[900],
        elevation: 1,
        toolbarHeight: 56,
        title: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dirghayu Foods',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Proud Nepali Brand',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.75),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Expanded(
            //   child: Align(
            //     alignment: Alignment.centerLeft,
            //     child: Image.asset(
            //       'assets/dirghayulogo.png',
            //       height: 34,
            //       fit: BoxFit.contain,
            //     ),
            //   ),
            // ),
            // Cart Icon
            Consumer<CartProvider>(
              builder: (context, cart, _) {
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.shopping_cart,
                        color: Colors.white,
                        size: 26,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const CartScreen(),
                          ),
                        );
                      },
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 40,
                      ),
                    ),
                    if (cart.itemCount > 0)
                      Positioned(
                        right: 4,
                        top: 4,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 16,
                          ),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${cart.itemCount}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF1E5038),
        onRefresh: () async {
          AppCache.instance.invalidateWhere(
            (key) => key.startsWith('home:') || key == 'catalog:categories',
          );
          await prefetchHomeScreenData();
          if (mounted) setState(() => _refreshTick++);
        },
        child: SingleChildScrollView(
          controller: widget.scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section 0: Search Bar
              _SearchBarSection(
                controller: _searchController,
                onSubmitted: (value) {
                  final query = value.trim();
                  if (query.isEmpty) return;
                  Provider.of<FilterProvider>(
                    context,
                    listen: false,
                  ).setSearchQuery(query);
                  widget.onNavigateToProducts?.call();
                  _searchController.clear();
                },
              ),
              // Section 1: Hero Section
              _HeroSection(onNavigateToProducts: widget.onNavigateToProducts),

              // Section 2: Catalog Section
              _CatalogSection(
                key: ValueKey('catalog-$_refreshTick'),
                onCategorySelected: widget.onCategorySelected,
              ),

              // Section 3: Featured Products Section
              _FeaturedProductsSection(
                key: ValueKey('featured-$_refreshTick'),
                onNavigateToProducts: widget.onNavigateToProducts,
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchBarSection extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;

  const _SearchBarSection({
    required this.controller,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300, width: 1),
        ),
        child: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Search products...',
            hintStyle: TextStyle(color: Colors.grey[600], fontSize: 13),
            prefixIcon: Icon(Icons.search, color: Colors.grey[600], size: 18),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 10,
            ),
            isDense: true,
          ),
          onSubmitted: onSubmitted,
        ),
      ),
    );
  }
}

// Section 1: Hero Section
class _HeroSection extends StatelessWidget {
  final VoidCallback? onNavigateToProducts;

  const _HeroSection({this.onNavigateToProducts});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: const TextSpan(
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                height: 1.25,
              ),
              children: [
                TextSpan(
                  text: 'Pure nutrition for every ',
                  style: TextStyle(color: Color(0xFF111827)),
                ),
                TextSpan(
                  text: 'baby, child & mother',
                  style: TextStyle(color: Color(0xFF1E5038)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '100% natural, sugar-free sprouted grain weaning porridges, dates sweeteners, and maternal recovery mixes handcrafted in Tilottama, Rupandehi.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => onNavigateToProducts?.call(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E5038),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                elevation: 0,
                minimumSize: const Size(0, 44),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Text(
                    'Explore Sourced Foods',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.arrow_forward, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          const _NutriFloorFeaturedCard(),
        ],
      ),
    );
  }
}

Future<void> prefetchHomeScreenData() async {
  await Future.wait([
    fetchHomeCategoriesDisplay(),
    fetchHomeFeaturedProducts(),
  ]);
}

Future<List<_CategoryDisplay>> fetchHomeCategoriesDisplay() {
  return AppCache.instance.getOrFetch('home:categories_display', () async {
    final results = await Future.wait([
      AppCache.instance.getOrFetch(
        'catalog:categories',
        () => ApiService.fetchCategories(),
      ),
      ApiService.fetchProductsPaginated(limit: _kThumbnailFetchWindow),
    ]);
    final categories = results[0] as List<Category>;
    final productsPage = results[1] as PaginatedProducts;

    final thumbnailByCategoryId = <String, String>{};
    for (final product in productsPage.products) {
      thumbnailByCategoryId.putIfAbsent(
        product.category.id,
        () => product.imageUrl,
      );
    }

    return categories.asMap().entries.map((entry) {
      final index = entry.key;
      final category = entry.value;
      final style = _kCategoryStyles[category.slug];
      final imageUrl = thumbnailByCategoryId[category.id];

      return _CategoryDisplay(
        category: category,
        imageUrl: imageUrl,
        color:
            style?.color ??
            _kFallbackCategoryPalette[index % _kFallbackCategoryPalette.length],
        subtext: style?.subtext ?? 'Explore our ${category.name} range.',
      );
    }).toList();
  });
}

const int _kThumbnailFetchWindow = 50;
const int _kFeaturedFetchWindow = 20;
const int _kFeaturedLimit = 8;

Future<List<Product>> fetchHomeFeaturedProducts() {
  return AppCache.instance.getOrFetch('home:featured', () async {
    final page = await ApiService.fetchProductsPaginated(
      page: 1,
      limit: _kFeaturedFetchWindow,
    );

    final discounted = page.products
        .where((p) => p.discountPrice != null)
        .toList();
    final rest = page.products.where((p) => p.discountPrice == null).toList();

    final featured = [...discounted, ...rest];
    return featured.take(_kFeaturedLimit).toList();
  });
}

class _CategoryStyle {
  final Color color;
  final String subtext;

  const _CategoryStyle({required this.color, required this.subtext});
}

const Map<String, _CategoryStyle> _kCategoryStyles = {
  'baby-weaning': _CategoryStyle(
    color: Colors.brown,
    subtext: 'Baked and processed sprouted...',
  ),
  'family-wellness': _CategoryStyle(
    color: Colors.brown,
    subtext: 'Premium daily grain options for...',
  ),
  'health-supplements': _CategoryStyle(
    color: Colors.orange,
    subtext: 'High protein and high energy natural...',
  ),
  'maternal-care': _CategoryStyle(
    color: Colors.brown,
    subtext: 'Nutritious mixes formulated for...',
  ),
  'sweeteners': _CategoryStyle(
    color: Colors.amber,
    subtext: 'Healthy, fiber-rich natural sweetness...',
  ),
  'oils-vinegars': _CategoryStyle(
    color: Colors.brown,
    subtext: 'Cold-pressed high antioxidant oils...',
  ),
};

const List<Color> _kFallbackCategoryPalette = [
  Colors.brown,
  Colors.teal,
  Colors.indigo,
  Colors.deepOrange,
  Colors.pink,
  Colors.blueGrey,
];

class _CategoryDisplay {
  final Category category;
  final String? imageUrl;
  final Color color;
  final String subtext;

  _CategoryDisplay({
    required this.category,
    required this.imageUrl,
    required this.color,
    required this.subtext,
  });
}

class _CatalogSection extends StatefulWidget {
  final Function(String)? onCategorySelected;

  const _CatalogSection({super.key, this.onCategorySelected});

  @override
  State<_CatalogSection> createState() => _CatalogSectionState();
}

class _CatalogSectionState extends State<_CatalogSection> {
  late Future<List<_CategoryDisplay>> _futureCategories;

  @override
  void initState() {
    super.initState();
    _futureCategories = _fetchCategoriesWithImages();
  }

  Future<List<_CategoryDisplay>> _fetchCategoriesWithImages() {
    return fetchHomeCategoriesDisplay();
  }

  Future<void> _retry() async {
    AppCache.instance.invalidate('home:categories_display');
    setState(() {
      _futureCategories = _fetchCategoriesWithImages();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFDFBF7),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Explore Our Nutrition Catalog',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0B132B),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Wholesome ingredients engineered for mental and physical development.',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FutureBuilder<List<_CategoryDisplay>>(
            future: _futureCategories,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF1E5038)),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: Colors.lightGreen.shade100,
                        size: 28,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Could not load categories',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      TextButton(onPressed: _retry, child: const Text('Retry')),
                    ],
                  ),
                );
              }

              final displays = snapshot.data ?? [];
              if (displays.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'No categories available yet',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                );
              }

              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.95,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: displays.length,
                itemBuilder: (context, index) {
                  final display = displays[index];
                  return GestureDetector(
                    onTap: () {
                      Provider.of<FilterProvider>(
                        context,
                        listen: false,
                      ).resetFilters();
                      widget.onCategorySelected?.call(display.category.name);
                    },
                    child: _CatalogCard(
                      title: display.category.name,
                      subtext: display.subtext,
                      color: display.color,
                      imageUrl: display.imageUrl,
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CatalogCard extends StatelessWidget {
  final String title;
  final String subtext;
  final Color color;
  final String? imageUrl;

  const _CatalogCard({
    required this.title,
    required this.subtext,
    required this.color,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedImage = (imageUrl != null && imageUrl!.isNotEmpty)
        ? _resolveImageUrl(imageUrl!)
        : null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            spreadRadius: 2,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 70,
            width: 70,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: ClipOval(
              child: resolvedImage == null
                  ? Icon(Icons.eco_outlined, color: color, size: 30)
                  : Image.network(
                      resolvedImage,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Center(
                          child: SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: color,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) =>
                          Icon(Icons.eco_outlined, color: color, size: 30),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0B132B),
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            subtext,
            style: TextStyle(fontSize: 10, color: Colors.grey[600]),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _FeaturedProductsSection extends StatefulWidget {
  final VoidCallback? onNavigateToProducts;

  const _FeaturedProductsSection({super.key, this.onNavigateToProducts});

  @override
  State<_FeaturedProductsSection> createState() =>
      _FeaturedProductsSectionState();
}

class _FeaturedProductsSectionState extends State<_FeaturedProductsSection> {
  static const int _kFeaturedLimit = 8;

  late Future<List<Product>> _futureFeatured;

  @override
  void initState() {
    super.initState();
    _futureFeatured = _fetchFeatured();
  }

  static const int _kFetchWindow = 20;

  Future<List<Product>> _fetchFeatured() async {
    return AppCache.instance.getOrFetch('home:featured', () async {
      final page = await ApiService.fetchProductsPaginated(
        page: 1,
        limit: _kFetchWindow,
      );

      final discounted = page.products
          .where((p) => p.discountPrice != null)
          .toList();
      final rest = page.products.where((p) => p.discountPrice == null).toList();

      final featured = [...discounted, ...rest];
      return featured.take(_kFeaturedLimit).toList();
    });
  }

  Future<void> _retry() async {
    AppCache.instance.invalidate('home:featured');
    setState(() {
      _futureFeatured = _fetchFeatured();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Featured Organic Products',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0B132B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Delicious sugar-free superfoods loved by families across Nepal.',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  widget.onNavigateToProducts?.call();
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Row(
                  children: [
                    Text(
                      'See Full Store',
                      style: TextStyle(
                        color: Colors.green[900],
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward,
                      color: Colors.green[900],
                      size: 14,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 260,
            child: FutureBuilder<List<Product>>(
              future: _futureFeatured,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF1E5038)),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.grey[400],
                          size: 28,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Could not load products',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextButton(
                          onPressed: _retry,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  );
                }

                final products = snapshot.data ?? [];
                if (products.isEmpty) {
                  return Center(
                    child: Text(
                      'No products available yet',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  );
                }

                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    return _ProductCard(product: products[index]);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

String _resolveImageUrl(String imageUrl) {
  if (imageUrl.isEmpty) return '';
  if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
    return imageUrl;
  }
  final base = ApiService.baseUrl.trim();
  final origin = base.replaceFirst(RegExp(r'/api/?$'), '');
  final path = imageUrl.startsWith('/') ? imageUrl : '/$imageUrl';
  return '$origin$path';
}

String _stripHtml(String input) {
  if (input.isEmpty) return input;
  final withoutTags = input.replaceAll(RegExp(r'<[^>]*>'), '');
  final withoutEntities = withoutTags
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");
  return withoutEntities.replaceAll(RegExp(r'\s+'), ' ').trim();
}

class _ProductCard extends StatelessWidget {
  final Product product;

  const _ProductCard({required this.product});

  bool get _isUnavailable =>
      product.stock <= 0 || product.status.toLowerCase() != 'active';

  bool get _isLowStock =>
      !_isUnavailable && product.stock > 0 && product.stock <= 5;

  bool get _hasDiscount =>
      product.discountPrice != null && product.discountPrice! < product.price;

  int get _discountPercent {
    if (!_hasDiscount) return 0;
    return (((product.price - product.discountPrice!) / product.price) * 100)
        .round();
  }

  @override
  Widget build(BuildContext context) {
    final resolvedImage = _resolveImageUrl(product.imageUrl);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailScreen(product: product),
          ),
        );
      },
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Stack
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: Container(
                    height: 100,
                    width: double.infinity,
                    color: Colors.grey.shade100,
                    child: resolvedImage.isEmpty
                        ? Icon(
                            Icons.image_outlined,
                            color: Colors.grey[400],
                            size: 32,
                          )
                        : Image.network(
                            resolvedImage,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return Center(
                                child: SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.green[700],
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) =>
                                Center(
                                  child: Icon(
                                    Icons.image_outlined,
                                    color: Colors.grey[400],
                                    size: 32,
                                  ),
                                ),
                          ),
                  ),
                ),
                if (_hasDiscount)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: _DiscountBadge(percent: _discountPercent),
                  ),
                if (_isLowStock)
                  Positioned(
                    bottom: 6,
                    left: 6,
                    child: _LowStockBadge(stock: product.stock),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          product.category.name.toUpperCase(),
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (product.weight.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            product.weight,
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0B132B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _stripHtml(product.description),
                    style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_hasDiscount)
                            Text(
                              'Rs. ${product.price.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[400],
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                          Text(
                            'Rs. ${(_hasDiscount ? product.discountPrice! : product.price).toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0B132B),
                            ),
                          ),
                        ],
                      ),
                      if (!_isUnavailable)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.green.shade300,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: InkWell(
                            onTap: () {
                              Provider.of<CartProvider>(
                                context,
                                listen: false,
                              ).addItem(product.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${product.title} added to cart',
                                  ),
                                  backgroundColor: const Color(0xFF1E5038),
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            },
                            child: Row(
                              children: [
                                Icon(
                                  Icons.shopping_cart_outlined,
                                  color: Colors.green[700],
                                  size: 12,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  'Add',
                                  style: TextStyle(
                                    color: Colors.green[700],
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        Text(
                          'UNAVAILABLE',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiscountBadge extends StatelessWidget {
  final int percent;

  const _DiscountBadge({required this.percent});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFDC3545),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        'SAVE $percent%',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _LowStockBadge extends StatelessWidget {
  final int stock;

  const _LowStockBadge({required this.stock});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFD7E14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.white,
            size: 10,
          ),
          const SizedBox(width: 2),
          Text(
            'ONLY $stock LEFT',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 7,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _NutriFloorFeaturedCard extends StatelessWidget {
  const _NutriFloorFeaturedCard();

  static const _forestGreen = Color(0xFF1E5038);
  static const _mint = Color(0xFFB9E4C9);
  static const _mintDark = Color(0xFF1F7A4D);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
      child: SizedBox(
        height: 340,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              height: 320,
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: Colors.grey.shade200,
                image: const DecorationImage(
                  image: AssetImage('assets/bestseller.png'),
                  fit: BoxFit.cover,
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0),
                      Colors.black.withOpacity(0.55),
                    ],
                    stops: const [0.5, 1.0],
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
                alignment: Alignment.bottomLeft,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _mint,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'SPROUTED & SUGAR-FREE',
                        style: TextStyle(
                          color: _mintDark,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Nutri Flour Lito (6+ Months)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Handcrafted in Rupandehi, Nepal',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: -6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _forestGreen,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Text(
                      'BEST SELLER',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.6,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Rs. 320',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 1),
                    Text(
                      'Lito Baby Food',
                      style: TextStyle(color: Colors.white70, fontSize: 9),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 0,
              top: 150,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: _mint,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.12),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_user, color: _mintDark, size: 13),
                    const SizedBox(width: 5),
                    Text(
                      '100% Sugar Free',
                      style: TextStyle(
                        color: _mintDark,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 14,
              bottom: -20,
              child: Container(
                width: 220,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.10),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: _mint,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.favorite, color: _mintDark, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'NUTRITION FOCUS',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Calcium • Iron • Fiber',
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

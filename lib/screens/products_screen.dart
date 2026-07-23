import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../widgets/product_card.dart';
import '../widgets/loading_widget.dart';
import '../widgets/custom_error_widget.dart';
import '../widgets/pagination_bar.dart';
import '../models/product_models.dart';
import '../models/category_models.dart';
import '../providers/filter_provider.dart';
import '../providers/cart_provider.dart';
import '../services/api_service.dart';
import '../services/app_cache.dart';
import 'cart_screen.dart';

class ProductsScreen extends StatefulWidget {
  final String? initialCategory;

  const ProductsScreen({super.key, this.initialCategory});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  List<Product> products = [];
  List<Category> categories = [];
  bool isLoading = true;
  bool isError = false;
  String errorMessage = '';

  static const int _pageLimit = 10;
  int _currentPage = 1;
  int _totalPages = 1;
  bool _isPageLoading = false;

  Map<String, int> _categoryCounts = {};

  static const int _kFullCatalogWindow = 100;
  List<Product>? _fullCatalog;
  bool _isFullCatalogLoading = false;
  bool _isFullCatalogError = false;

  bool _isFilterActive(FilterProvider fp) =>
      fp.selectedCategory != 'All Categories' || fp.searchQuery.isNotEmpty;

  Future<void> _loadFullCatalog() async {
    const key = 'products:full_catalog';

    if (AppCache.instance.has(key)) {
      setState(() {
        _fullCatalog = AppCache.instance.get<List<Product>>(key);
        _isFullCatalogLoading = false;
        _isFullCatalogError = false;
      });
      return;
    }

    setState(() {
      _isFullCatalogLoading = true;
      _isFullCatalogError = false;
    });
    try {
      final fullCatalog = await AppCache.instance.getOrFetch<List<Product>>(
        key,
        () async {
          final result = await ApiService.fetchProductsPaginated(
            page: 1,
            limit: _kFullCatalogWindow,
          );
          return result.products;
        },
      );
      if (!mounted) return;
      setState(() {
        _fullCatalog = fullCatalog;
        _isFullCatalogLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isFullCatalogLoading = false;
        _isFullCatalogError = true;
      });
    }
  }

  Future<void> _loadCategoryCounts() async {
    try {
      const key = 'products:full_catalog';
      final fullCatalog = await AppCache.instance.getOrFetch<List<Product>>(
        key,
        () async {
          final result = await ApiService.fetchProductsPaginated(
            page: 1,
            limit: _kFullCatalogWindow,
          );
          return result.products;
        },
      );
      final counts = <String, int>{};
      for (final p in fullCatalog) {
        counts[p.category.id] = (counts[p.category.id] ?? 0) + 1;
      }
      if (mounted) setState(() => _categoryCounts = counts);
    } catch (_) {}
  }

  String _pageKey(int page) => 'products:page=$page:limit=$_pageLimit';

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(covariant ProductsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialCategory == oldWidget.initialCategory) return;

    final filterProvider = Provider.of<FilterProvider>(context, listen: false);
    filterProvider.applyFilters(
      category: widget.initialCategory ?? 'All Categories',
      price: filterProvider.maxPrice,
      sort: filterProvider.selectedSort,
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _fullImageUrl(Product product) {
    final String baseUrl = dotenv.env['API_URL'] ?? 'http://10.0.2.2:5000/api';
    final String imageBaseUrl = baseUrl.replaceFirst(RegExp(r'/api$'), '');
    return product.imageUrl.startsWith('http')
        ? product.imageUrl
        : '$imageBaseUrl${product.imageUrl}';
  }

  void _precacheImages(List<Product> loadedProducts) {
    for (final product in loadedProducts) {
      if (product.imageUrl.isEmpty) continue;
      precacheImage(
        CachedNetworkImageProvider(_fullImageUrl(product)),
        context,
      ).catchError((_) {});
    }
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
      isError = false;
    });

    try {
      final page1Key = _pageKey(1);
      final results = await Future.wait([
        AppCache.instance.getOrFetch(
          'catalog:categories',
          () => ApiService.fetchCategories(),
        ),
        AppCache.instance.getOrFetch(
          page1Key,
          () => ApiService.fetchProductsPaginated(page: 1, limit: _pageLimit),
        ),
      ]);

      final categoriesResult = results[0] as List<Category>;
      final paginatedResult = results[1] as PaginatedProducts;

      setState(() {
        categories = categoriesResult;
        products = paginatedResult.products;
        _currentPage = paginatedResult.pagination.page;
        _totalPages = paginatedResult.pagination.totalPages;
        isLoading = false;
      });

      if (mounted) _precacheImages(paginatedResult.products);
      _prefetchPage(2);
      _loadCategoryCounts();

      if (widget.initialCategory != null && mounted) {
        final filterProvider = Provider.of<FilterProvider>(
          context,
          listen: false,
        );
        filterProvider.applyFilters(
          category: widget.initialCategory!,
          price: filterProvider.maxPrice,
          sort: filterProvider.selectedSort,
        );
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        isError = true;
        errorMessage = e.toString();
      });
    }
  }

  Future<void> _goToPage(int page) async {
    if (page == _currentPage || page < 1 || page > _totalPages) return;

    final key = _pageKey(page);
    final cached = AppCache.instance.get<PaginatedProducts>(key);
    if (cached != null) {
      setState(() {
        products = cached.products;
        _currentPage = cached.pagination.page;
      });
      _scrollToTop();
      _prefetchPage(page + 1);
      _prefetchPage(page - 1);
      return;
    }

    setState(() => _isPageLoading = true);

    try {
      final paginatedResult = await ApiService.fetchProductsPaginated(
        page: page,
        limit: _pageLimit,
      );

      AppCache.instance.put(key, paginatedResult);

      setState(() {
        products = paginatedResult.products;
        _currentPage = paginatedResult.pagination.page;
        _totalPages = paginatedResult.pagination.totalPages;
        _isPageLoading = false;
      });

      if (mounted) _precacheImages(paginatedResult.products);
      _scrollToTop();
      _prefetchPage(page + 1);
    } catch (e) {
      setState(() => _isPageLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not load page $page. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _prefetchPage(int page) async {
    if (page < 1 || page > _totalPages) return;
    AppCache.instance.prefetch(
      _pageKey(page),
      () => ApiService.fetchProductsPaginated(page: page, limit: _pageLimit),
    );
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  List<Product> getFilteredProducts() {
    final filterProvider = Provider.of<FilterProvider>(context, listen: false);
    final bool filtering = _isFilterActive(filterProvider);

    List<Product> filtered = List.from(
      filtering ? (_fullCatalog ?? []) : products,
    );

    if (filterProvider.selectedCategory != 'All Categories') {
      filtered = filtered
          .where((p) => p.category.name == filterProvider.selectedCategory)
          .toList();
    }

    if (filterProvider.searchQuery.isNotEmpty) {
      final query = filterProvider.searchQuery.toLowerCase();
      filtered = filtered
          .where(
            (p) =>
                p.title.toLowerCase().contains(query) ||
                p.description.toLowerCase().contains(query),
          )
          .toList();
    }

    filtered = filtered.where((p) {
      final effectivePrice = p.discountPrice ?? p.price;
      return effectivePrice <= filterProvider.maxPrice;
    }).toList();

    switch (filterProvider.selectedSort) {
      case 'Price: Low to High':
        filtered.sort(
          (a, b) => (a.discountPrice ?? a.price).compareTo(
            b.discountPrice ?? b.price,
          ),
        );
        break;
      case 'Price: High to Low':
        filtered.sort(
          (a, b) => (b.discountPrice ?? b.price).compareTo(
            a.discountPrice ?? a.price,
          ),
        );
        break;
      case 'Best Sellers':
        filtered.sort((a, b) => b.orderQuantity.compareTo(a.orderQuantity));
        break;
      case 'Biggest Savings':
        filtered.sort((a, b) {
          final double discountA = a.discountPrice != null
              ? ((a.price - a.discountPrice!) / a.price) * 100
              : 0;
          final double discountB = b.discountPrice != null
              ? ((b.price - b.discountPrice!) / b.price) * 100
              : 0;
          return discountB.compareTo(discountA);
        });
        break;
      default:
        break;
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final filterProvider = Provider.of<FilterProvider>(context);
    final bool filtering = _isFilterActive(filterProvider);

    if (filtering &&
        _fullCatalog == null &&
        !_isFullCatalogLoading &&
        !_isFullCatalogError) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadFullCatalog());
    }

    final filteredProducts = getFilteredProducts();
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF7),
      appBar: AppBar(
        backgroundColor: Colors.green[900],
        elevation: 1,
        title: const Text(
          'Products',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          Consumer<CartProvider>(
            builder: (context, cart, _) => Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.shopping_cart_outlined,
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
                ),
                if (cart.itemCount > 0)
                  Positioned(
                    top: 8,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC3545),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(minWidth: 16),
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
            ),
          ),
          if (!isLoading && !isError)
            IconButton(
              icon: const Icon(
                Icons.filter_list,
                color: Colors.white,
                size: 26,
              ),
              onPressed: _showFilterBottomSheet,
            ),
        ],
      ),
      body: _buildBody(filteredProducts, filterProvider),
    );
  }

  Widget _buildBody(
    List<Product> filteredProducts,
    FilterProvider filterProvider,
  ) {
    final bool filtering = _isFilterActive(filterProvider);

    if (isLoading) {
      return const LoadingWidget(message: 'Loading products...');
    }

    if (isError) {
      return CustomErrorWidget(message: errorMessage, onRetry: _loadData);
    }

    if (filtering && _isFullCatalogLoading) {
      return const LoadingWidget(message: 'Loading matching products...');
    }

    if (filtering && _isFullCatalogError) {
      return CustomErrorWidget(
        message: 'Could not load products for this filter.',
        onRetry: _loadFullCatalog,
      );
    }

    if (products.isEmpty && !filtering) {
      return _emptyState(
        icon: Icons.inbox_outlined,
        title: 'No products available',
        subtitle: 'Check back later for new products',
      );
    }

    if (filteredProducts.isEmpty) {
      final bool isSearch = filterProvider.searchQuery.isNotEmpty;
      return _emptyState(
        icon: Icons.search_off,
        title: isSearch
            ? 'No results for "${filterProvider.searchQuery}"'
            : 'No products found',
        subtitle: isSearch
            ? 'Try a different search term'
            : 'Try adjusting your filters',
        showClearFilters: true,
        onClearFilters: () {
          filterProvider.resetFilters();
          setState(() => _fullCatalog = null);
        },
      );
    }

    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: GridView.builder(
                  key: ValueKey(
                    filtering
                        ? 'filtered-${filterProvider.selectedCategory}-${filterProvider.searchQuery}'
                        : _currentPage,
                  ),
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.7,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  itemCount: filteredProducts.length,
                  itemBuilder: (context, index) =>
                      ProductCard(product: filteredProducts[index]),
                ),
              ),
              if (_isPageLoading)
                Container(
                  color: Colors.white.withOpacity(0.6),
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.green[700]),
                  ),
                ),
            ],
          ),
        ),
        if (!filtering)
          PaginationBar(
            currentPage: _currentPage,
            totalPages: _totalPages,
            onPageChanged: _goToPage,
          ),
      ],
    );
  }

  Widget _emptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    bool showClearFilters = false,
    VoidCallback? onClearFilters,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
          if (showClearFilters) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: onClearFilters,
              child: const Text('Clear Filters'),
            ),
          ],
        ],
      ),
    );
  }

  void _showFilterBottomSheet() {
    final filterProvider = Provider.of<FilterProvider>(context, listen: false);
    final totalCount = _categoryCounts.values.fold<int>(0, (sum, c) => sum + c);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FilterBottomSheet(
        categories: categories,
        categoryCounts: _categoryCounts,
        allCategoriesCount: totalCount,
        selectedCategory: filterProvider.selectedCategory,
        maxPrice: filterProvider.maxPrice,
        selectedSort: filterProvider.selectedSort,
        sortOptions: sortOptions,
        onApplyFilters: (category, price, sort) {
          filterProvider.applyFilters(
            category: category,
            price: price,
            sort: sort,
          );
        },
      ),
    );
  }

  final List<String> sortOptions = [
    'Featured / Default',
    'Best Sellers',
    'Price: Low to High',
    'Price: High to Low',
    'Biggest Savings',
  ];
}

class _FilterBottomSheet extends StatefulWidget {
  final List<Category> categories;
  final Map<String, int> categoryCounts;
  final int allCategoriesCount;
  final String selectedCategory;
  final double maxPrice;
  final String selectedSort;
  final List<String> sortOptions;
  final Function(String, double, String) onApplyFilters;

  const _FilterBottomSheet({
    required this.categories,
    required this.categoryCounts,
    required this.allCategoriesCount,
    required this.selectedCategory,
    required this.maxPrice,
    required this.selectedSort,
    required this.sortOptions,
    required this.onApplyFilters,
  });

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  late String tempSelectedCategory;
  late double tempMaxPrice;
  late String tempSelectedSort;

  @override
  void initState() {
    super.initState();
    tempSelectedCategory = widget.selectedCategory;
    tempMaxPrice = widget.maxPrice;
    tempSelectedSort = widget.selectedSort;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.tune, color: Colors.green[900], size: 24),
                    const SizedBox(width: 10),
                    const Text(
                      'Filters & Sorting',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ],
                ),
                TextButton(
                  onPressed: _resetFilters,
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  child: Row(
                    children: [
                      Icon(Icons.refresh, color: Colors.grey[600], size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'RESET',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF3F4F6)),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PRODUCT CATEGORIES',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4B5563),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildCategoryRow(
                    'All Categories',
                    widget.allCategoriesCount,
                    tempSelectedCategory == 'All Categories',
                    () =>
                        setState(() => tempSelectedCategory = 'All Categories'),
                  ),
                  ...widget.categories.map(
                    (cat) => _buildCategoryRow(
                      cat.name,
                      widget.categoryCounts[cat.id] ?? 0,
                      tempSelectedCategory == cat.name,
                      () => setState(() => tempSelectedCategory = cat.name),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'MAX PRICE RANGE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4B5563),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Max Price',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF111827),
                        ),
                      ),
                      Text(
                        'Rs. ${tempMaxPrice.toInt()}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E5038),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Slider(
                    value: tempMaxPrice,
                    min: 0,
                    max: 3000,
                    divisions: 30,
                    activeColor: const Color(0xFF1E5038),
                    inactiveColor: Colors.grey[300],
                    thumbColor: const Color(0xFF1E5038),
                    onChanged: (value) => setState(() => tempMaxPrice = value),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Rs. 0',
                        style: TextStyle(color: Colors.grey[500], fontSize: 10),
                      ),
                      Text(
                        'Rs. 3000',
                        style: TextStyle(color: Colors.grey[500], fontSize: 10),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'SORT OPTIONS',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4B5563),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!, width: 1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: tempSelectedSort,
                        isExpanded: true,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        icon: Icon(Icons.swap_vert, color: Colors.grey[600]),
                        iconSize: 24,
                        elevation: 4,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF111827),
                          fontWeight: FontWeight.w500,
                        ),
                        onChanged: (value) =>
                            setState(() => tempSelectedSort = value!),
                        items: widget.sortOptions.map((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(
                              value,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF111827),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        widget.onApplyFilters(
                          tempSelectedCategory,
                          tempMaxPrice,
                          tempSelectedSort,
                        );
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1E5038),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Apply Filters',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryRow(
    String label,
    int count,
    bool isSelected,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E5038) : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isSelected ? Colors.white : const Color(0xFF4B5563),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF1A452E)
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF111827),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _resetFilters() {
    setState(() {
      tempSelectedCategory = 'All Categories';
      tempMaxPrice = 3000;
      tempSelectedSort = 'Featured / Default';
    });
  }
}

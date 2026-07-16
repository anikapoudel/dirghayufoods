import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/filter_provider.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback? onNavigateToProducts;
  final Function(String)? onCategorySelected;

  const HomeScreen({super.key, this.onNavigateToProducts, this.onCategorySelected});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.green[900],
        elevation: 1,
        title: Row(
          children: [
            // Logo
            Image.asset(
              'assets/dirghayulogo.png',
              height: 45,
              width: 80,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 8),
            // Search Bar
            Expanded(
              child: Container(
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search products...',
                    hintStyle: TextStyle(
                      color: Colors.green[900],
                      fontSize: 13,
                    ),
                    prefixIcon: Icon(
                      Icons.search,
                      color: Colors.grey[600],
                      size: 18,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 6,
                    ),
                    isDense: true,
                  ),
                  onSubmitted: (value) {
                    print('Searching for: $value');
                  },
                ),
              ),
            ),
            const SizedBox(width: 4),
            // Cart Icon
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: Icon(
                    Icons.shopping_cart,
                    color: Colors.white,
                    size: 26,
                  ),
                  onPressed: () {
                    print('Cart clicked');
                  },
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                ),
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Text(
                      '3',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section 1: Hero Section
            _HeroSection(onNavigateToProducts: widget.onNavigateToProducts),

            // Section 2: Catalog Section
            _CatalogSection(onCategorySelected: widget.onCategorySelected),

            // Section 3: Featured Products Section
            _FeaturedProductsSection(onNavigateToProducts: widget.onNavigateToProducts),

            const SizedBox(height: 20),
          ],
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Headline
          RichText(
            text: const TextSpan(
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                height: 1.2,
              ),
              children: [
                TextSpan(
                  text: 'Pure nutrition for every ',
                  style: TextStyle(
                    color: Color(0xFF111827),
                  ),
                ),
                TextSpan(
                  text: 'baby, child & mother',
                  style: TextStyle(
                    color: Color(0xFF1E5038),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Subtitle
          Text(
            '100% natural, sugar-free sprouted grain weaning porridges, dates sweeteners, and maternal recovery mixes handcrafted in Tilottama, Rupandehi.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          // Buttons Row
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    onNavigateToProducts?.call();
                  },
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
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(
                        Icons.arrow_forward,
                        size: 16,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
            ],
          ),
        ],
      ),
    );
  }
}

// Section 2: Catalog Section
class _CatalogSection extends StatelessWidget {
  final Function(String)? onCategorySelected;

  const _CatalogSection({this.onCategorySelected});

  @override
  Widget build(BuildContext context) {
    // Define category data
    final List<Map<String, dynamic>> categories = [
      {
        'title': 'Baby Foods & Weaning',
        'subtext': 'Baked and processed sprouted...',
        'color': Colors.brown,
        'image': 'assets/babyfood.png',
      },
      {
        'title': 'Family Wellness',
        'subtext': 'Premium daily grain options for...',
        'color': Colors.brown,
        'image': 'assets/familywellness.png',
      },
      {
        'title': 'Health Supplements',
        'subtext': 'High protein and high energy natural...',
        'color': Colors.orange,
        'image': 'assets/healthsupplements.png',
      },
      {
        'title': 'Maternal Care',
        'subtext': 'Nutritious mixes formulated for...',
        'color': Colors.brown,
        'image': 'assets/maternalcare.png',
      },
      {
        'title': 'Natural Sweeteners',
        'subtext': 'Healthy, fiber-rich natural sweetness...',
        'color': Colors.amber,
        'image': 'assets/naturalsweetener.png',
      },
      {
        'title': 'Oils & Vinegars',
        'subtext': 'Cold-pressed high antioxidant oils...',
        'color': Colors.brown,
        'image': 'assets/oilandvinegar.png',
      },
    ];

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
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.78,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return GestureDetector(
                onTap: () {
                  // Reset filters first
                  Provider.of<FilterProvider>(context, listen: false).resetFilters();
                  // Then apply category filter
                  onCategorySelected?.call(category['title'] as String);
                },
                child: _CatalogCard(
                  title: category['title'] as String,
                  subtext: category['subtext'] as String,
                  color: category['color'] as Color,
                  imagePath: category['image'] as String,
                ),
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
  final String imagePath;

  const _CatalogCard({
    required this.title,
    required this.subtext,
    required this.color,
    required this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
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
              child: Padding(
                padding: const EdgeInsets.all(1),
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.contain,
                ),
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
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// Section 3: Featured Products Section
class _FeaturedProductsSection extends StatelessWidget {
  final VoidCallback? onNavigateToProducts;

  const _FeaturedProductsSection({this.onNavigateToProducts});

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
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  onNavigateToProducts?.call();
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
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 5,
              itemBuilder: (context, index) {
                return _ProductCard(index: index);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final int index;

  const _ProductCard({required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Stack
          Stack(
            children: [
              Container(
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.image_outlined,
                    color: Colors.grey[400],
                    size: 32,
                  ),
                ),
              ),
              // Discount Badge
              const Positioned(
                top: 6,
                left: 6,
                child: _DiscountBadge(),
              ),
              // Low Stock Badge
              if (index % 2 == 0)
                const Positioned(
                  bottom: 6,
                  left: 6,
                  child: _LowStockBadge(),
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
                    Text(
                      'BABY FOODS',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
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
                        '0.5 KG',
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
                  'Test Product ${index + 1}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0B132B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Premium organic baby food',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
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
                        Text(
                          'Rs. 1000',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[400],
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        const Text(
                          'Rs. 900',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0B132B),
                          ),
                        ),
                      ],
                    ),
                    if (index != 2)
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
    );
  }
}

class _DiscountBadge extends StatelessWidget {
  const _DiscountBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFDC3545),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        'SAVE 10%',
        style: TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _LowStockBadge extends StatelessWidget {
  const _LowStockBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 6,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFD7E14),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.white,
            size: 10,
          ),
          SizedBox(width: 2),
          Text(
            'ONLY 5 LEFT',
            style: TextStyle(
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
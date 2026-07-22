import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../providers/cart_provider.dart';
import '../models/cart_models.dart';
import '../services/auth_service.dart';
import 'auth_screen.dart';
import 'checkout_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final TextEditingController _promoController = TextEditingController();

  bool _checkingAuth = true;
  bool _isLoggedIn = false;

  // @override
  // void initState() {
  //   super.initState();
  //   _checkAuth();
  //
  //   WidgetsBinding.instance.addPostFrameCallback((_) {
  //     if (!mounted) return;
  //     _loadCartWithDiscounts();
  //   });
  // }
  @override
  void initState() {
    super.initState();
    _checkAuth();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // ✅ Just load the cart normally
      context.read<CartProvider>().loadCart();
    });
  }

  // ✅ FIXED: Uncommented _checkAuth()
  Future<void> _checkAuth() async {
    final loggedIn = await AuthService.isLoggedIn();
    if (!mounted) return;
    setState(() {
      _isLoggedIn = loggedIn;
      _checkingAuth = false;
    });
  }

  // ✅ This is the method we use
  Future<void> _loadCartWithDiscounts() async {
    final cartProvider = context.read<CartProvider>();
    await cartProvider.loadCart();
    await cartProvider.refreshCartWithDiscounts();
  }

  // ❌ DELETE THIS - Not needed
  // Future<void> _loadCartWithFreshPrices() async { ... }

  @override
  void dispose() {
    _promoController.dispose();
    super.dispose();
  }

  String _fullImageUrl(String imageUrl) {
    final String baseUrl = dotenv.env['API_URL'] ?? 'http://10.0.2.2:5000/api';
    final String imageBaseUrl = baseUrl.replaceFirst(RegExp(r'/api$'), '');
    return imageUrl.startsWith('http') ? imageUrl : '$imageBaseUrl$imageUrl';
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : const Color(0xFF1E5038),
      ),
    );
  }

  void _applyPromoCode(CartProvider cart) {
    final code = _promoController.text.trim();
    if (code.isEmpty) {
      _showSnack('Enter a promo code first', isError: true);
      return;
    }
    final normalized = code.toUpperCase();
    final coupon = CartProvider.availableCoupons[normalized];
    if (coupon == null) {
      _showSnack('Invalid or expired coupon code', isError: true);
      return;
    }
    if (cart.subtotal < coupon.minOrder) {
      _showSnack(
        'Add Rs. ${(coupon.minOrder - cart.subtotal).toStringAsFixed(0)} more to use "$normalized"',
        isError: true,
      );
      return;
    }
    cart.applyCoupon(normalized);
    _showSnack('Coupon "$normalized" applied!');
  }

  void _confirmClearCart(CartProvider cart) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cart'),
        content: const Text('Remove all items from your cart?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await cart.clearCart();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC3545),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: const Text('Clear Cart'),
          ),
        ],
      ),
    );
  }

  Future<void> _goToLogin() async {
    final cartProvider = context.read<CartProvider>();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (screenContext) => AuthScreen(
          onLoginSuccess: (Map<String, dynamic> userData) {
            Navigator.of(screenContext).pop();
          },
        ),
      ),
    );
    if (!mounted) return;
    await _checkAuth();
    if (!mounted || !_isLoggedIn) return;

    // Merges whatever was in the local guest cart into the real server
    // cart, clears local guest storage, and switches CartProvider into
    // server-backed mode. Same call ProfileScreen's login flow uses —
    // one merge code path instead of two slightly different ones.
    await cartProvider.syncGuestCartToServer();

    // REMOVED — no longer auto-navigate to CheckoutScreen. The user
    // stays on CartScreen, which now correctly shows the "Proceed to
    // Checkout" button instead of the guest alert, and can tap it
    // themselves when ready — matching the expected flow.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF7),
      appBar: AppBar(
        backgroundColor: Colors.green[900],
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'My Cart',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: Consumer<CartProvider>(
        builder: (context, cart, _) {
          if (cart.isLoading && !cart.hasLoadedOnce) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF1E5038)),
            );
          }

          if (cart.error != null && cart.isEmpty) {
            return _buildErrorState(cart);
          }

          if (cart.isEmpty) return _buildEmptyState();

          return RefreshIndicator(
            onRefresh: () async {
              final cartProvider = context.read<CartProvider>();
              await cartProvider.loadCart();
              await cartProvider.refreshCartWithDiscounts();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Cart items list
                  ...cart.items.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildCartItemCard(item, cart),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Continue Shopping / Clear Entire Cart row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.arrow_back,
                          size: 16,
                          color: Color(0xFF1E5038),
                        ),
                        label: const Text(
                          'Continue Shopping',
                          style: TextStyle(
                            color: Color(0xFF1E5038),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                      ),
                      TextButton(
                        onPressed: () => _confirmClearCart(cart),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        child: const Text(
                          'Clear Entire Cart',
                          style: TextStyle(
                            color: Color(0xFFDC3545),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // _buildPromoSection(cart),
                  // const SizedBox(height: 16),
                  _buildOrderSummary(cart),
                  const SizedBox(height: 20),
                  if (_checkingAuth)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF1E5038),
                        ),
                      ),
                    )
                  else if (_isLoggedIn)
                    _buildCheckoutButton()
                  else
                    _buildGuestCheckoutAlert(),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorState(CartProvider cart) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 56, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              cart.error ?? 'Could not load your cart',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: cart.loadCart,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E5038),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckoutButton() {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CheckoutScreen()),
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1E5038),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Proceed to Checkout',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            SizedBox(width: 8),
            Icon(Icons.arrow_forward, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestCheckoutAlert() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF6E3),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFF5E6B8),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.login, color: Color(0xFFB8860B), size: 22),
          ),
          const SizedBox(height: 14),
          const Text(
            'GUEST CHECKOUT ALERT',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0B132B),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Please login with your phone number to continue your order. This allows you to track and manage order status.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _goToLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E5038),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Log In / Register with OTP',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_cart_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Your Cart is Empty',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add some products to get started',
              style: TextStyle(fontSize: 14, color: Colors.grey[500]),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E5038),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Continue Shopping',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartItemCard(RemoteCartItem item, CartProvider cart) {
    final product = item.product;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: product.imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: _fullImageUrl(product.imageUrl),
                    width: 64,
                    height: 64,
                    fit: BoxFit.cover,
                    memCacheWidth: 150,
                    placeholder: (context, url) => Container(
                      width: 64,
                      height: 64,
                      color: Colors.grey.shade100,
                      child: Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.green[700],
                          ),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 64,
                      height: 64,
                      color: Colors.grey.shade100,
                      child: Icon(
                        Icons.image_not_supported,
                        color: Colors.grey[400],
                        size: 24,
                      ),
                    ),
                  )
                : Container(
                    width: 64,
                    height: 64,
                    color: Colors.grey.shade100,
                    child: Icon(
                      Icons.image_outlined,
                      color: Colors.grey[400],
                      size: 28,
                    ),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0B132B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (product.status != 'active') ...[
                  const SizedBox(height: 2),
                  Text(
                    'No longer available',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.red[400],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                if (product.discountPrice != null) ...[
                  Row(
                    children: [
                      Text(
                        'Rs. ${product.discountPrice!.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0B132B),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Rs. ${product.price.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ),
                ] else
                  Text(
                    'Rs. ${product.price.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0B132B),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              InkWell(
                onTap: () => cart.removeItem(item.id),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Icon(
                    Icons.delete_outline,
                    size: 20,
                    color: Colors.grey[400],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _qtyButton(
                      icon: Icons.remove,
                      onTap: item.quantity <= 1
                          ? null
                          : () =>
                                cart.updateQuantity(item.id, item.quantity - 1),
                    ),
                    SizedBox(
                      width: 24,
                      child: Text(
                        '${item.quantity}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    _qtyButton(
                      icon: Icons.add,
                      onTap: () =>
                          cart.updateQuantity(item.id, item.quantity + 1),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Rs. ${item.lineTotal.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E5038),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _qtyButton({required IconData icon, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(
          icon,
          size: 14,
          color: onTap == null ? Colors.grey[300] : Colors.grey[700],
        ),
      ),
    );
  }

  // Widget _buildPromoSection(CartProvider cart) {
  //   return Card(
  //     elevation: 0,
  //     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  //     color: Colors.white,
  //     child: Padding(
  //       padding: const EdgeInsets.all(16),
  //       child: Column(
  //         crossAxisAlignment: CrossAxisAlignment.start,
  //         children: [
  //           const Text(
  //             'Promo Codes & Coupons',
  //             style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
  //           ),
  //           const SizedBox(height: 12),
  //           Row(
  //             children: [
  //               Expanded(
  //                 child: Container(
  //                   decoration: BoxDecoration(
  //                     color: Colors.grey.shade50,
  //                     borderRadius: BorderRadius.circular(8),
  //                     border: Border.all(color: Colors.grey.shade300),
  //                   ),
  //                   child: TextField(
  //                     controller: _promoController,
  //                     textCapitalization: TextCapitalization.characters,
  //                     decoration: InputDecoration(
  //                       hintText: 'E.G. DEERGHA10',
  //                       hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
  //                       border: InputBorder.none,
  //                       contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  //                     ),
  //                   ),
  //                 ),
  //               ),
  //               const SizedBox(width: 10),
  //               ElevatedButton(
  //                 onPressed: () => _applyPromoCode(cart),
  //                 style: ElevatedButton.styleFrom(
  //                   backgroundColor: const Color(0xFF1E5038),
  //                   foregroundColor: Colors.white,
  //                   padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
  //                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  //                   elevation: 0,
  //                 ),
  //                 child: const Text('Apply', style: TextStyle(fontWeight: FontWeight.w600)),
  //               ),
  //             ],
  //           ),
  //           if (cart.appliedCode != null) ...[
  //             const SizedBox(height: 10),
  //             Row(
  //               children: [
  //                 Icon(Icons.check_circle, size: 16, color: Colors.green[700]),
  //                 const SizedBox(width: 6),
  //                 Expanded(
  //                   child: Text(
  //                     '"${cart.appliedCode}" applied',
  //                     style: TextStyle(fontSize: 12, color: Colors.green[700], fontWeight: FontWeight.w600),
  //                   ),
  //                 ),
  //                 GestureDetector(
  //                   onTap: cart.removeCoupon,
  //                   child: Text(
  //                     'Remove',
  //                     style: TextStyle(fontSize: 12, color: Colors.grey[500], fontWeight: FontWeight.w600),
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ],
  //           const SizedBox(height: 14),
  //           Text(
  //             'Available Coupons',
  //             style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.grey[600]),
  //           ),
  //           const SizedBox(height: 6),
  //           ...CartProvider.availableCoupons.entries.map(
  //                 (entry) => Padding(
  //               padding: const EdgeInsets.only(bottom: 4),
  //               child: Row(
  //                 crossAxisAlignment: CrossAxisAlignment.start,
  //                 children: [
  //                   Text('• ', style: TextStyle(color: Colors.grey[500], fontSize: 12)),
  //                   Expanded(
  //                     child: RichText(
  //                       text: TextSpan(
  //                         style: TextStyle(fontSize: 12, color: Colors.grey[600]),
  //                         children: [
  //                           TextSpan(
  //                             text: entry.key,
  //                             style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace'),
  //                           ),
  //                           TextSpan(text: ' - ${entry.value.description}'),
  //                         ],
  //                       ),
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  Widget _buildOrderSummary(CartProvider cart) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Order Summary',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 14),
            _summaryRow('Subtotal', 'Rs. ${cart.subtotal.toStringAsFixed(0)}'),
            const SizedBox(height: 8),
            if (cart.appliedCode != null && cart.discountAmount > 0) ...[
              _summaryRow(
                'Discount (${cart.appliedCode})',
                '- Rs. ${cart.discountAmount.toStringAsFixed(0)}',
                valueColor: const Color(0xFFDC3545),
              ),
              const SizedBox(height: 8),
            ],
            _summaryRow(
              'Delivery Charge',
              cart.isDeliveryFree
                  ? 'FREE'
                  : 'Rs. ${cart.deliveryCharge.toStringAsFixed(0)}',
              valueColor: cart.isDeliveryFree ? const Color(0xFF1E5038) : null,
            ),
            if (!cart.isDeliveryFree) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: Colors.grey[700],
                    ),
                    children: [
                      TextSpan(
                        text:
                            'Add Rs. ${cart.amountToFreeDelivery.toStringAsFixed(0)} more to qualify for ',
                      ),
                      const TextSpan(
                        text: 'FREE DELIVERY',
                        style: TextStyle(
                          color: Color(0xFF1E5038),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const TextSpan(text: '!'),
                    ],
                  ),
                ),
              ),
            ],
            const Divider(height: 24),
            _summaryRow(
              'Grand Total',
              'Rs. ${cart.total.toStringAsFixed(0)}',
              isBold: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(
    String label,
    String value, {
    bool isBold = false,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
            color: const Color(0xFF111827),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 18 : 14,
            fontWeight: FontWeight.bold,
            color: valueColor ?? const Color(0xFF111827),
          ),
        ),
      ],
    );
  }
}

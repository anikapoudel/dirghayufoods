import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../models/order_models.dart';
import '../services/order_service.dart';
import '../services/auth_service.dart';
import 'order_tracking_screen.dart';

const Color _cream = Color(0xFFFDFBF7);
const Color _green = Color(0xFF1E5038);
const Color _darkText = Color(0xFF0B132B);

enum _CheckoutStep { delivery, payment, success }

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  _CheckoutStep _step = _CheckoutStep.delivery;
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _districtCtrl = TextEditingController();
  final _municipalityCtrl = TextEditingController();
  final _wardCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _landmarkCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  static const List<String> _provinces = [
    'Koshi Province',
    'Madhesh Province',
    'Bagmati Province',
    'Gandaki Province',
    'Lumbini Province',
    'Karnali Province',
    'Sudurpashchim Province',
  ];
  String _province = _provinces[2];

  bool _saveAddress = false;
  bool _isSubmitting = false;
  bool _isLoadingProfile = true;
  PaymentMethod _paymentMethod = PaymentMethod.cashOnDelivery;
  PlacedOrderSummary? _placedOrder;
  String? _profileEmail;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final data = await AuthService.getSavedUserData();
    if (!mounted) return;
    setState(() {
      if (data != null) {
        _nameCtrl.text = data['name']?.toString() ?? '';
        _phoneCtrl.text = data['phone']?.toString() ?? '';
        _profileEmail = data['email']?.toString();
      }
      _isLoadingProfile = false;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _districtCtrl.dispose();
    _municipalityCtrl.dispose();
    _wardCtrl.dispose();
    _streetCtrl.dispose();
    _landmarkCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  DeliveryAddress get _address => DeliveryAddress(
    receiverName: _nameCtrl.text.trim(),
    phoneNumber: _phoneCtrl.text.trim(),
    province: _province,
    district: _districtCtrl.text.trim(),
    municipality: _municipalityCtrl.text.trim(),
    wardNumber: _wardCtrl.text.trim(),
    streetName: _streetCtrl.text.trim(),
    landmark: _landmarkCtrl.text.trim(),
    notes: _notesCtrl.text.trim(),
  );

  void _goToPayment() {
    if (_formKey.currentState!.validate()) {
      setState(() => _step = _CheckoutStep.payment);
    }
  }

  Future<void> _placeOrder(CartProvider cart) async {
    if (_isSubmitting) return;

    setState(() => _isSubmitting = true);

    if (cart.items.isEmpty) {
      await cart.loadCart();
      if (cart.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not verify your cart: ${cart.error}'),
            backgroundColor: const Color(0xFFDC3545),
          ),
        );
        if (mounted) setState(() => _isSubmitting = false);
        return;
      }
    }

    if (_profileEmail == null || _profileEmail!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your account is missing an email address. Please update your profile first.',
          ),
          backgroundColor: Color(0xFFDC3545),
        ),
      );
      if (mounted) setState(() => _isSubmitting = false);
      return;
    }

    if (cart.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your cart is empty. Please add items before placing an order.',
          ),
          backgroundColor: Color(0xFFDC3545),
        ),
      );
      if (mounted) setState(() => _isSubmitting = false);
      return;
    }

    final address = _address;

    final request = CreateOrderRequest(
      fullName: address.receiverName,
      email: _profileEmail!.trim(),
      phone: address.phoneNumber,
      state: address.stateValue,
      district: address.district,
      city: address.cityValue,
      streetAddress: address.streetAddressValue,
      paymentMethod: _paymentMethod,
      notes: address.notes,
    );

    try {
      final result = await OrderService.createOrder(request);
      final items = cart.items
          .map(
            (i) => OrderLineItem(
              title: i.product.name,
              quantity: i.quantity,
              unitPrice: i.unitPrice,
            ),
          )
          .toList();

      final summary = PlacedOrderSummary(
        orderId: result.orderId,
        orderReference: result.orderReference,
        items: items,
        address: address,
        paymentMethod: _paymentMethod,
        subtotal: cart.subtotal,
        discount: cart.discountAmount,
        deliveryCharge: cart.deliveryCharge,
        total: cart.total,
      );

      await cart.clearCart();

      if (!mounted) return;
      setState(() {
        _placedOrder = summary;
        _step = _CheckoutStep.success;
      });
    } catch (e) {
      if (!mounted) return;
      final actuallySucceeded = await _checkIfOrderActuallyWentThrough(
        expectedTotal: cart.total,
      );

      if (actuallySucceeded != null) {
        final items = cart.items
            .map(
              (i) => OrderLineItem(
                title: i.product.name,
                quantity: i.quantity,
                unitPrice: i.unitPrice,
              ),
            )
            .toList();

        final summary = PlacedOrderSummary(
          orderId: actuallySucceeded.id,
          orderReference: actuallySucceeded.orderReference,
          items: items,
          address: address,
          paymentMethod: _paymentMethod,
          subtotal: cart.subtotal,
          discount: cart.discountAmount,
          deliveryCharge: cart.deliveryCharge,
          total: cart.total,
        );

        await cart.clearCart();
        if (!mounted) return;
        setState(() {
          _placedOrder = summary;
          _step = _CheckoutStep.success;
        });
        return;
      }

      final rawMessage = e.toString().replaceFirst('Exception: ', '');
      final displayMessage = _friendlyOrderErrorMessage(rawMessage);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(displayMessage),
          backgroundColor: const Color(0xFFDC3545),
          duration: const Duration(seconds: 5),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<RemoteOrder?> _checkIfOrderActuallyWentThrough({
    required double expectedTotal,
  }) async {
    print('🕵️ FALLBACK CHECK STARTED — expectedTotal: $expectedTotal');
    for (var attempt = 0; attempt < 4; attempt++) {
      if (attempt > 0) {
        await Future.delayed(Duration(milliseconds: 500 * attempt));
      }
      try {
        final result = await OrderService.fetchMyOrders(page: 1, limit: 5);
        final now = DateTime.now();
        print(
          '🕵️ Attempt $attempt — now: $now, found ${result.orders.length} orders',
        );
        for (final order in result.orders) {
          final age = now.difference(order.createdAt);
          final totalMatches = (order.totalPrice - expectedTotal).abs() < 1;
          print(
            '🕵️   order ${order.orderReference}: createdAt=${order.createdAt}, '
            'ageSeconds=${age.inSeconds}, totalPrice=${order.totalPrice}, '
            'totalMatches=$totalMatches',
          );
          if (age.inSeconds >= 0 && age.inSeconds < 90 && totalMatches) {
            print('🕵️ MATCH FOUND: ${order.orderReference}');
            return order;
          }
        }
      } catch (e) {
        print('🕵️ Attempt $attempt threw: $e');
      }
    }
    print('🕵️ NO MATCH FOUND after all attempts');
    return null;
  }

  String _friendlyOrderErrorMessage(String rawMessage) {
    final normalized = rawMessage.toLowerCase();

    if (normalized.contains('cart') && normalized.contains('empty')) {
      return "Your cart appears to be empty. Please add items and try again.";
    }

    if (normalized.contains('product') && normalized.contains('not found')) {
      return "One or more products in your cart are no longer available. Please remove them and try again.";
    }

    if (normalized.contains('stock') || normalized.contains('quantity')) {
      return "One or more items in your cart are out of stock. Please adjust quantities and try again.";
    }

    return 'Could not place order: $rawMessage';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      body: SafeArea(
        child: Consumer<CartProvider>(
          builder: (context, cart, _) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  if (_isLoadingProfile)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 60),
                      child: Center(
                        child: CircularProgressIndicator(color: _green),
                      ),
                    )
                  else ...[
                    if (_step == _CheckoutStep.delivery)
                      _buildDeliveryStep(cart),
                    if (_step == _CheckoutStep.payment) _buildPaymentStep(cart),
                    if (_step == _CheckoutStep.success && _placedOrder != null)
                      _buildSuccessStep(_placedOrder!),
                  ],
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final activeIndex = switch (_step) {
      _CheckoutStep.delivery => 1,
      _CheckoutStep.payment => 2,
      _CheckoutStep.success => 3,
    };
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Checkout Process',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _darkText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Complete your delivery details, choose a payment method, and confirm order.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _buildStepper(activeIndex),
      ],
    );
  }

  Widget _buildStepper(int active) {
    Widget circle(int n) {
      final isDone = n < active;
      final isActive = n == active;
      return Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: (isActive || isDone) ? _green : Colors.grey.shade200,
        ),
        child: isDone
            ? const Icon(Icons.check, color: Colors.white, size: 13)
            : Text(
                '$n',
                style: TextStyle(
                  color: isActive ? Colors.white : Colors.grey[500],
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
      );
    }

    Widget line() =>
        Container(width: 12, height: 1.5, color: Colors.grey.shade300);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [circle(1), line(), circle(2), line(), circle(3)],
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );
  }

  Widget _sectionTitle(String text, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: _green, size: 18),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: _darkText,
            ),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
    filled: true,
    fillColor: Colors.grey.shade50,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: _green, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFDC3545)),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFDC3545), width: 1.5),
    ),
  );

  Widget _fieldLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Colors.grey[600],
        letterSpacing: 0.4,
      ),
    ),
  );

  Widget _textField({
    required String label,
    required TextEditingController controller,
    String? hint,
    TextInputType? keyboardType,
    bool required = true,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel(required ? '$label *' : label),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            style: const TextStyle(fontSize: 14, color: _darkText),
            decoration: _inputDecoration(hint ?? ''),
            validator: required
                ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
                : null,
          ),
        ],
      ),
    );
  }

  Widget _provinceDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _fieldLabel('PROVINCE *'),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.grey.shade300),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _province,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
                style: const TextStyle(fontSize: 14, color: _darkText),
                items: _provinces
                    .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                    .toList(),
                onChanged: (v) => setState(() => _province = v ?? _province),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryLine(
    String label,
    String value, {
    bool bold = false,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: bold ? 15 : 13,
            fontWeight: bold ? FontWeight.bold : FontWeight.w500,
            color: _darkText,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 16 : 13,
            fontWeight: FontWeight.bold,
            color: color ?? _darkText,
          ),
        ),
      ],
    );
  }

  Widget _buildOrderSummaryCard(CartProvider cart) {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ORDER SUMMARY',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: _darkText,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 12),
          ...cart.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 13, color: _darkText),
                        children: [
                          TextSpan(
                            text: item.product.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          TextSpan(
                            text: ' (Qty: ${item.quantity})',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Rs. ${item.lineTotal.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _darkText,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 20),
          _summaryLine('Subtotal', 'Rs. ${cart.subtotal.toStringAsFixed(0)}'),
          const SizedBox(height: 6),
          if (cart.appliedCode != null && cart.discountAmount > 0) ...[
            _summaryLine(
              'Discount (${cart.appliedCode})',
              '- Rs. ${cart.discountAmount.toStringAsFixed(0)}',
              color: const Color(0xFFDC3545),
            ),
            const SizedBox(height: 6),
          ],
          _summaryLine(
            'Delivery Charge',
            cart.isDeliveryFree
                ? 'FREE'
                : 'Rs. ${cart.deliveryCharge.toStringAsFixed(0)}',
            color: cart.isDeliveryFree ? _green : null,
          ),
          const Divider(height: 20),
          _summaryLine(
            'Grand Total',
            'Rs. ${cart.total.toStringAsFixed(0)}',
            bold: true,
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryStep(CartProvider cart) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionCard(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle(
                  'Step 1: Delivery Location & Contact',
                  Icons.local_shipping_outlined,
                ),
                const SizedBox(height: 18),
                _textField(
                  label: 'RECEIVER\'S NAME',
                  controller: _nameCtrl,
                  hint: 'e.g. Anika Sharma',
                ),
                _textField(
                  label: 'PHONE NUMBER',
                  controller: _phoneCtrl,
                  hint: 'e.g. 98XXXXXXXX',
                  keyboardType: TextInputType.phone,
                ),
                _provinceDropdown(),
                _textField(
                  label: 'DISTRICT',
                  controller: _districtCtrl,
                  hint: 'e.g. Kathmandu',
                ),
                _textField(
                  label: 'MUNICIPALITY / LOCAL BODY',
                  controller: _municipalityCtrl,
                  hint: 'e.g. Butwal Sub-Metropolitan',
                ),
                _textField(
                  label: 'WARD NUMBER',
                  controller: _wardCtrl,
                  hint: 'e.g. 1',
                  keyboardType: TextInputType.number,
                ),
                _textField(
                  label: 'STREET NAME / TOLE',
                  controller: _streetCtrl,
                  hint: 'e.g. Milan Chowk',
                ),
                _textField(
                  label: 'LANDMARK (OPTIONAL)',
                  controller: _landmarkCtrl,
                  hint: 'e.g. Opposite Nabil Bank Branch',
                  required: false,
                ),
                _textField(
                  label: 'SPECIAL DELIVERY NOTES',
                  controller: _notesCtrl,
                  hint: 'e.g. Call before coming',
                  required: false,
                  maxLines: 2,
                ),
                // InkWell(
                //   onTap: () => setState(() => _saveAddress = !_saveAddress),
                //   child: Row(
                //     children: [
                //       Checkbox(
                //         value: _saveAddress,
                //         activeColor: _green,
                //         onChanged: (v) => setState(() => _saveAddress = v ?? false),
                //       ),
                //       const Expanded(
                //         child: Text(
                //           'Save this address in my customer profile for future checkout',
                //           style: TextStyle(fontSize: 12, color: Colors.grey),
                //         ),
                //       ),
                //     ],
                //   ),
                // ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildOrderSummaryCard(cart),
        const SizedBox(height: 20),
        TextButton.icon(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back, size: 16, color: _green),
          label: const Text(
            'Return to Cart',
            style: TextStyle(
              color: _green,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            alignment: Alignment.centerLeft,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _goToPayment,
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
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
                  'Continue to Payment',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                SizedBox(width: 8),
                Icon(Icons.arrow_forward, size: 18),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentStep(CartProvider cart) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle(
                'Step 2: Choose Payment Method',
                Icons.account_balance_wallet_outlined,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border.all(color: _green, width: 1.5),
                  borderRadius: BorderRadius.circular(12),
                  color: _green.withOpacity(0.04),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Radio<PaymentMethod>(
                      value: PaymentMethod.cashOnDelivery,
                      groupValue: _paymentMethod,
                      activeColor: _green,
                      onChanged: (v) =>
                          setState(() => _paymentMethod = v ?? _paymentMethod),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Cash on Delivery (COD)',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: _darkText,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Pay with cash or local scanned phone transfer upon receiving the parcel.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.grey[600],
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _sectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DELIVERY ADDRESS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[500],
                  letterSpacing: 0.4,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _address.receiverName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: _darkText,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'Phone: ${_address.phoneNumber}',
                style: TextStyle(fontSize: 12.5, color: Colors.grey[700]),
              ),
              const SizedBox(height: 3),
              Text(
                _address.shortLine,
                style: TextStyle(fontSize: 12.5, color: Colors.grey[700]),
              ),
              const SizedBox(height: 3),
              Text(
                _address.cityLine,
                style: TextStyle(fontSize: 12.5, color: Colors.grey[700]),
              ),
              const SizedBox(height: 3),
              Text(
                '${_address.province}, Nepal',
                style: TextStyle(fontSize: 12.5, color: Colors.grey[700]),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => setState(() => _step = _CheckoutStep.delivery),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.edit_outlined,
                      size: 14,
                      color: Color(0xFFFD7E14),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'EDIT DELIVERY ADDRESS',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B5E20),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        TextButton.icon(
          onPressed: _isSubmitting
              ? null
              : () => setState(() => _step = _CheckoutStep.delivery),
          icon: const Icon(Icons.arrow_back, size: 16, color: _green),
          label: const Text(
            'Back to Address Info',
            style: TextStyle(
              color: _green,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            alignment: Alignment.centerLeft,
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _isSubmitting ? null : () => _placeOrder(cart),
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.verified_user_outlined, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Place & Confirm Order',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessStep(PlacedOrderSummary order) {
    return _sectionCard(
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _green.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check, color: _green, size: 34),
          ),
          const SizedBox(height: 16),
          const Text(
            'Order Placed Successfully!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _darkText,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Thank you for ordering with Deerghayu Foods. Your order reference is ${order.orderReference}.',
            style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Delivery Summary:',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[700],
                      ),
                    ),
                    Text(
                      'Total: Rs. ${order.total.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: _darkText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _successRow('Address', order.address.streetAddressValue),
                const SizedBox(height: 6),
                _successRow(
                  'Payment',
                  '${order.paymentMethod.label} (Pending)',
                ),
                const SizedBox(height: 6),
                _successRow('Estimated Delivery', 'Within 24-48 Hours'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              OrderTrackingScreen(orderId: order.orderId),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Track Order Status',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () =>
                        Navigator.popUntil(context, (route) => route.isFirst),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _darkText,
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Back to Store',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _successRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/widgets.dart' as pw;
import '../models/order_models.dart';
import '../services/order_service.dart';
import '../services/product_service.dart';
import 'invoice_screen.dart';
import 'dart:typed_data';

const Color _cream = Color(0xFFFDFBF7);
const Color _green = Color(0xFF1E5038);
const Color _darkText = Color(0xFF0B132B);

const List<String> _knownStatusSteps = [
  'pending',
  'confirmed',
  'processing',
  'shipping',
  'delivered',
  'cancelled',
  'cancel',
];

String _statusLabel(String status) {
  switch (status.toLowerCase()) {
    case 'pending':
      return 'Placed';
    case 'confirmed':
      return 'Processed';
    case 'processing':
      return 'Packed';
    case 'shipping':
      return 'Dispatch';
    case 'delivered':
      return 'Delivered';
    case 'cancelled':
    case 'cancel':
      return 'Cancelled';
    default:
      return status;
  }
}

String _detailStatusLabel(String status) {
  switch (status.toLowerCase()) {
    case 'pending':
      return 'Order Placed';
    case 'confirmed':
      return 'Confirmed';
    case 'processing':
      return 'Processing';
    case 'shipping':
      return 'Out For Delivery';
    case 'delivered':
      return 'Delivered';
    case 'cancelled':
    case 'cancel':
      return 'Cancelled';
    default:
      return status;
  }
}

Color _detailStatusBg(String status) {
  switch (status.toLowerCase()) {
    case 'confirmed':
      return const Color(0xFFE4E8EF);
    case 'processing':
      return const Color(0xFFF6E693);
    case 'shipping':
      return const Color(0xFFCBD2FC);
    case 'delivered':
      return const Color(0xFFBDF1D2);
    case 'cancelled':
    case 'cancel':
      return const Color(0xFFDC3545).withOpacity(0.12);
    case 'pending':
      return const Color(0xFFFD7E14).withOpacity(0.12);
    default:
      return Colors.grey.shade100;
  }
}

Color _detailStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'confirmed':
      return const Color(0xFF21293B);
    case 'processing':
      return const Color(0xFF854113);
    case 'shipping':
      return const Color(0xFF3D2DA5);
    case 'delivered':
      return const Color(0xFF2D5F47);
    case 'cancelled':
    case 'cancel':
      return const Color(0xFFDC3545);
    case 'pending':
      return const Color(0xFFFD7E14);
    default:
      return Colors.grey[700]!;
  }
}

class OrderTrackingScreen extends StatefulWidget {
  final String orderId;

  const OrderTrackingScreen({super.key, required this.orderId});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  RemoteOrder? _order;
  bool _isLoading = true;
  bool _isCancelling = false;
  String? _error;

  final Map<String, String> _weightById = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final order = await OrderService.fetchOrderById(widget.orderId);
      print('RAW ORDER STATUS: "${order.status}"');
      if (!mounted) return;
      setState(() {
        _order = order;
        _isLoading = false;
      });
      _loadWeights(order);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _loadWeights(RemoteOrder order) async {
    for (final item in order.items) {
      if (_weightById.containsKey(item.product.id)) continue;
      try {
        final product = await ProductService.getProduct(item.product.id);
        if (!mounted) return;
        setState(() {
          _weightById[item.product.id] = product.weight;
        });
      } catch (_) {}
    }
  }

  Uint8List? _devanagariImageBytes;

  Future<Uint8List> _loadDevanagariImage() async {
    if (_devanagariImageBytes != null) return _devanagariImageBytes!;
    final data = await rootBundle.load('assets/dirghayu_devanagari.png');
    final bytes = data.buffer.asUint8List();
    _devanagariImageBytes = bytes;
    return bytes;
  }

  Uint8List? _logoBytes;

  Future<Uint8List> _loadLogo() async {
    if (_logoBytes != null) return _logoBytes!;
    final data = await rootBundle.load('assets/dirghayulogo.png');
    final bytes = data.buffer.asUint8List();
    _logoBytes = bytes;
    return bytes;
  }

  Future<void> _cancelOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: const Text('Are you sure you want to cancel this order?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'No',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC3545),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isCancelling = true);
    try {
      await OrderService.cancelOrder(widget.orderId);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Could not cancel order: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
          backgroundColor: const Color(0xFFDC3545),
        ),
      );
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final period = local.hour >= 12 ? 'PM' : 'AM';
    final minute = local.minute.toString().padLeft(2, '0');
    final second = local.second.toString().padLeft(2, '0');
    return '${local.month}/${local.day}/${local.year}, $hour12:$minute:$second $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: Colors.green[900],
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          'My Orders & Tracking',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Monitor your active orders, inspect timeline stages, and download tax invoices for your records.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.grey[600],
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 18),
                if (_isLoading) _buildLoading(),
                if (!_isLoading && _error != null) _buildError(),
                if (!_isLoading && _error == null && _order != null)
                  _buildContent(_order!),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 60),
      child: Center(child: CircularProgressIndicator(color: _green)),
    );
  }

  Widget _buildError() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.error_outline, color: Colors.grey[400], size: 40),
          const SizedBox(height: 12),
          Text(
            _error ?? 'Something went wrong',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey[700]),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _load,
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
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
    );
  }

  Widget _buildContent(RemoteOrder order) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildOrderHeader(order),
          const SizedBox(height: 18),
          _buildItemsAndBilling(order),
          const SizedBox(height: 22),
          _buildTimeline(order),
          if (order.status.toLowerCase() == 'pending') ...[
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton(
                onPressed: _isCancelling ? null : _cancelOrder,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFDC3545),
                  side: const BorderSide(color: Color(0xFFDC3545)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isCancelling
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFFDC3545),
                        ),
                      )
                    : const Text(
                        'Cancel Order',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOrderHeader(RemoteOrder order) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Text(
                    order.orderReference,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _darkText,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: _detailStatusBg(order.status),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _detailStatusLabel(order.status).toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: _detailStatusColor(order.status),
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 12,
                    color: Colors.grey[500],
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Ordered: ${_formatDate(order.createdAt)}',
                      style: TextStyle(fontSize: 11.5, color: Colors.grey[500]),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: () async {
            final devanagariImage = await _loadDevanagariImage();
            final logo = await _loadLogo();
            if (!mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => InvoiceScreen(
                  order: order,
                  weightLookup: (productId) => _weightById[productId],
                  devanagariImageBytes: devanagariImage,
                  logoBytes: logo,
                ),
              ),
            );
          },
          icon: const Icon(Icons.description_outlined, size: 15, color: _green),
          label: const Text(
            'Tax Invoice',
            style: TextStyle(
              color: _green,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
          ),
          style: TextButton.styleFrom(padding: EdgeInsets.zero),
        ),
      ],
    );
  }

  Widget _buildItemsAndBilling(RemoteOrder order) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 480;
        final itemsSection = _buildItemsSection(order);
        final detailsSection = _buildDeliveryAndBillingSection(order);
        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: itemsSection),
              const SizedBox(width: 16),
              Expanded(flex: 2, child: detailsSection),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [itemsSection, const SizedBox(height: 18), detailsSection],
        );
      },
    );
  }

  Widget _buildItemsSection(RemoteOrder order) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PURCHASED FOOD ITEMS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey[500],
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 10),
        ...order.items.map((item) {
          final weight = _weightById[item.product.id];
          final qtyLine = weight != null && weight.isNotEmpty
              ? 'Qty: ${item.quantity} • $weight'
              : 'Qty: ${item.quantity}';
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.product.name,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: _darkText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        qtyLine,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Rs. ${item.lineTotal.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: _darkText,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildDeliveryAndBillingSection(RemoteOrder order) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DELIVERY ADDRESS',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: Colors.grey[500],
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            order.deliveryAddress?.fullName.isNotEmpty == true
                ? order.deliveryAddress!.fullName
                : (order.customer?.name ?? '—'),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _darkText,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            order.deliveryAddress?.phone.isNotEmpty == true
                ? order.deliveryAddress!.phone
                : (order.customer?.phone ?? '—'),
            style: TextStyle(fontSize: 12, color: Colors.grey[700]),
          ),
          const SizedBox(height: 3),
          if (order.deliveryAddress != null) ...[
            Text(
              order.deliveryAddress!.line1,
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
            Text(
              order.deliveryAddress!.line2,
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
            Text(
              order.deliveryAddress!.line3,
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          ] else
            Text(
              order.customer?.location ?? '—',
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
          const SizedBox(height: 16),
          Text(
            'BILLING SUMMARY',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: Colors.grey[500],
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 8),
          _billingLine(
            'Subtotal',
            'Rs. ${order.itemsSubtotal.toStringAsFixed(0)}',
          ),
          const SizedBox(height: 6),
          _billingLine(
            'Delivery Charge',
            order.deliveryCharge.abs() < 0.5
                ? 'FREE'
                : 'Rs. ${order.deliveryCharge.toStringAsFixed(0)}',
          ),
          const SizedBox(height: 10),
          _billingLine(
            'Grand Total',
            'Rs. ${order.totalPrice.toStringAsFixed(0)}',
            bold: true,
          ),
          const SizedBox(height: 10),
          _billingLine(
            'Payment Method',
            order.payment.method == 'cash_on_delivery'
                ? 'Cash on Delivery'
                : order.payment.method,
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Payment Status',
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFD7E14).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  order.payment.status.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFFD7E14),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _billingLine(
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
            fontSize: bold ? 14 : 12,
            fontWeight: bold ? FontWeight.bold : FontWeight.w500,
            color: _darkText,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: bold ? 15 : 12,
            fontWeight: FontWeight.bold,
            color: color ?? _darkText,
          ),
        ),
      ],
    );
  }

  Widget _buildTimeline(RemoteOrder order) {
    final normalizedStatus = order.status.toLowerCase();

    if (normalizedStatus == 'cancelled' || normalizedStatus == 'cancel') {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        child: Text(
          'This order was cancelled.',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.red[700],
          ),
        ),
      );
    }

    if (!_knownStatusSteps.contains(normalizedStatus)) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        child: Text(
          'Status: ${order.status}',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _darkText,
          ),
        ),
      );
    }

    final currentIndex = _knownStatusSteps.indexOf(normalizedStatus);
    final lastIndex = _knownStatusSteps.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 1),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(_knownStatusSteps.length, (index) {
            final isDone = index < currentIndex;
            final isActive = index == currentIndex;
            final connectorInDone = index > 0 && (index - 1) < currentIndex;
            final connectorOutDone = index < currentIndex;

            return Expanded(
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Container(
                          height: 2,
                          color: index == 0
                              ? Colors.transparent
                              : (connectorInDone
                                    ? _green
                                    : Colors.grey.shade300),
                        ),
                      ),
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (isDone || isActive)
                              ? _green
                              : Colors.grey.shade200,
                        ),
                        child: isDone
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 14,
                              )
                            : Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: isActive
                                      ? Colors.white
                                      : Colors.grey[500],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                      ),
                      Expanded(
                        child: Container(
                          height: 2,
                          color: index == lastIndex
                              ? Colors.transparent
                              : (connectorOutDone
                                    ? _green
                                    : Colors.grey.shade300),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _statusLabel(_knownStatusSteps[index]),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                      color: isActive ? _green : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ],
    );
  }
}

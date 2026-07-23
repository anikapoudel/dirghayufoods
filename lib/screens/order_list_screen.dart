import 'package:flutter/material.dart';
import '../models/order_models.dart';
import '../services/app_cache.dart';
import '../services/order_service.dart';
import 'order_tracking_screen.dart';

const Color _cream = Color(0xFFFDFBF7);
const Color _green = Color(0xFF1E5038);
const Color _darkText = Color(0xFF0B132B);

String _statusLabel(String status) {
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

Color _statusBg(String status) {
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

Color _statusColor(String status) {
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

class OrderListScreen extends StatefulWidget {
  const OrderListScreen({super.key});

  @override
  State<OrderListScreen> createState() => _OrderListScreenState();
}

class _OrderListScreenState extends State<OrderListScreen> {
  static const int _pageSize = 6;

  final List<RemoteOrder> _orders = [];
  int _currentPage = 1;
  OrderPagination? _pagination;
  bool _isLoading = true;
  String? _error;

  final AppCache _cache = AppCache.instance;

  String _cacheKey(int page) => 'orders:page=$page:limit=$_pageSize';

  @override
  void initState() {
    super.initState();
    _load(1);
  }

  Future<void> _load(int page, {bool forceRefresh = false}) async {
    final key = _cacheKey(page);
    if (!forceRefresh && _cache.has(key)) {
      _applyResult(_cache.get<OrderListResult>(key)!);
      _prefetchNeighbours(page);
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await OrderService.fetchMyOrders(
        page: page,
        limit: _pageSize,
      );
      if (!mounted) return;
      _cache.put(key, result);
      _applyResult(result);
      _prefetchNeighbours(page);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _applyResult(OrderListResult result) {
    setState(() {
      _orders
        ..clear()
        ..addAll(result.orders);
      _currentPage = result.pagination.page;
      _pagination = result.pagination;
      _isLoading = false;
      _error = null;
    });
  }

  void _prefetchNeighbours(int page) {
    final totalPages = _pagination?.totalPages ?? 1;
    for (final p in [page + 1, page - 1]) {
      if (p < 1 || p > totalPages) continue;
      _cache.prefetch(
        _cacheKey(p),
        () => OrderService.fetchMyOrders(page: p, limit: _pageSize),
      );
    }
  }

  Future<void> _goToPage(int page) async {
    if (_isLoading) return;
    final totalPages = _pagination?.totalPages ?? 1;
    if (page < 1 || page > totalPages || page == _currentPage) return;
    await _load(page);
  }

  Future<void> _refresh() async {
    await _load(_currentPage, forceRefresh: true);
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    final hour12 = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final period = local.hour >= 12 ? 'PM' : 'AM';
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.month}/${local.day}/${local.year}, $hour12:$minute $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: Colors.green[900],
        elevation: 0,
        title: const Text(
          'My Orders',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(onRefresh: _refresh, child: _buildBody()),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 80),
            child: Center(child: CircularProgressIndicator(color: _green)),
          ),
        ],
      );
    }

    if (_error != null && _orders.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(Icons.error_outline, size: 56, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => _load(_currentPage, forceRefresh: true),
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
          ),
        ],
      );
    }

    if (_orders.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 72,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No Orders Yet',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your placed orders will show up here',
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            itemCount: _orders.length,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildOrderCard(_orders[index]),
              );
            },
          ),
        ),
        if ((_pagination?.totalPages ?? 1) > 1) _buildPaginationBar(),
      ],
    );
  }

  Widget _buildPaginationBar() {
    final totalPages = _pagination!.totalPages;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _cream,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _navButton(
            icon: Icons.chevron_left,
            enabled: _pagination!.hasPrevPage,
            onTap: () => _goToPage(_currentPage - 1),
          ),
          const SizedBox(width: 8),
          ..._buildPageNumbers(totalPages),
          const SizedBox(width: 8),
          _navButton(
            icon: Icons.chevron_right,
            enabled: _pagination!.hasNextPage,
            onTap: () => _goToPage(_currentPage + 1),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPageNumbers(int totalPages) {
    const int window = 1;
    final List<Object> items = [];

    if (totalPages <= 7) {
      items.addAll(List.generate(totalPages, (i) => i + 1));
    } else {
      items.add(1);
      final start = (_currentPage - window).clamp(2, totalPages - 1);
      final end = (_currentPage + window).clamp(2, totalPages - 1);
      if (start > 2) items.add('...');
      for (int p = start; p <= end; p++) {
        items.add(p);
      }
      if (end < totalPages - 1) items.add('...');
      items.add(totalPages);
    }

    return items.map<Widget>((item) {
      if (item is String) {
        return const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            '...',
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
          ),
        );
      }
      final page = item as int;
      final isActive = page == _currentPage;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: _pageNumberButton(page: page, isActive: isActive),
      );
    }).toList();
  }

  Widget _pageNumberButton({required int page, required bool isActive}) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: isActive ? null : () => _goToPage(page),
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? _green : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isActive ? _green : Colors.grey.shade300),
        ),
        child: Text(
          '$page',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isActive ? Colors.white : _darkText,
          ),
        ),
      ),
    );
  }

  Widget _navButton({
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: enabled ? onTap : null,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? _darkText : Colors.grey.shade300,
        ),
      ),
    );
  }

  Widget _buildOrderCard(RemoteOrder order) {
    final firstItemName = order.items.isNotEmpty
        ? order.items.first.product.name
        : 'Order';
    final extraCount = order.items.length - 1;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OrderTrackingScreen(orderId: order.id),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.orderReference,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: _darkText,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _statusBg(order.status),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusLabel(order.status).toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: _statusColor(order.status),
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
                Text(
                  _formatDate(order.createdAt),
                  style: TextStyle(fontSize: 11.5, color: Colors.grey[500]),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(
                  child: Text(
                    extraCount > 0
                        ? '$firstItemName +$extraCount more'
                        : firstItemName,
                    style: const TextStyle(
                      fontSize: 13,
                      color: _darkText,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Rs. ${order.totalPrice.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: _darkText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'View Details',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  Icons.arrow_forward_ios,
                  size: 11,
                  color: Colors.grey[500],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

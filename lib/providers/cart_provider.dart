import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/cart_models.dart';
import '../services/cart_service.dart';
import '../services/product_service.dart';
import '../services/auth_service.dart';

class CouponInfo {
  final double? percentOff;
  final double? flatOff;
  final double minOrder;
  final String description;

  const CouponInfo({
    this.percentOff,
    this.flatOff,
    required this.minOrder,
    required this.description,
  });
}

class CartProvider extends ChangeNotifier {
  RemoteCart _cart = RemoteCart.empty();
  bool _isLoading = false;
  String? _error;
  bool _hasLoadedOnce = false;

  bool _isGuest = true;

  bool get isGuest => _isGuest;

  static const String _guestCartKey = 'guest_cart_quantities';

  List<RemoteCartItem> get items => _cart.items;

  int get itemCount => _cart.items.fold(0, (sum, item) => sum + item.quantity);

  bool get isEmpty => _cart.items.isEmpty;

  bool get isLoading => _isLoading;

  String? get error => _error;

  bool get hasLoadedOnce => _hasLoadedOnce;

  double get subtotal =>
      _cart.items.fold(0.0, (sum, item) => sum + item.lineTotal);

  static const Map<String, CouponInfo> availableCoupons = {
    'DEERGHA10': CouponInfo(
      percentOff: 0.10,
      minOrder: 300,
      description: 'Get 10% off (Min order: Rs. 300)',
    ),
    'HEALTHYFOOD': CouponInfo(
      flatOff: 100,
      minOrder: 800,
      description: 'Get Flat Rs. 100 off (Min order: Rs. 800)',
    ),
  };

  static const double deliveryChargeAmount = 150;
  static const double freeDeliveryThreshold = 1000;

  bool get isDeliveryFree => subtotal >= freeDeliveryThreshold;

  double get deliveryCharge => isDeliveryFree ? 0 : deliveryChargeAmount;

  double get amountToFreeDelivery =>
      isDeliveryFree ? 0 : (freeDeliveryThreshold - subtotal);

  String? _appliedCode;

  String? get appliedCode => _appliedCode;

  CouponInfo? get _activeCoupon {
    if (_appliedCode == null) return null;
    final coupon = availableCoupons[_appliedCode];
    if (coupon == null) return null;
    if (subtotal < coupon.minOrder) return null;
    return coupon;
  }

  double get discountAmount {
    final coupon = _activeCoupon;
    if (coupon == null) return 0;
    if (coupon.percentOff != null) {
      return subtotal * coupon.percentOff!;
    }
    if (coupon.flatOff != null) {
      return coupon.flatOff! > subtotal ? subtotal : coupon.flatOff!;
    }
    return 0;
  }

  double get total => subtotal - discountAmount + deliveryCharge;

  Future<Map<String, int>> _readGuestQuantities() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_guestCartKey);
    if (raw == null) return {};
    try {
      final decoded = json.decode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeGuestQuantities(Map<String, int> quantities) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_guestCartKey, json.encode(quantities));
  }

  String? _productIdFromGuestItemId(String cartItemId) {
    if (!cartItemId.startsWith('guest:')) return null;
    return cartItemId.substring('guest:'.length);
  }

  Future<void> _loadGuestCart() async {
    final quantities = await _readGuestQuantities();
    if (quantities.isEmpty) {
      _cart = RemoteCart.empty();
      return;
    }

    final items = <RemoteCartItem>[];
    for (final entry in quantities.entries) {
      try {
        final product = await ProductService.getProduct(entry.key);
        items.add(
          RemoteCartItem(
            id: 'guest:${entry.key}',
            quantity: entry.value,
            product: RemoteCartProduct(
              id: product.id,
              name: product.title,
              price: product.price,
              discountPrice: product.discountPrice,
              imageUrl: product.imageUrl,
              status: product.status,
            ),
          ),
        );
      } catch (_) {}
    }
    _cart = RemoteCart(id: 'guest', customerId: '', items: items);
  }

  Future<void> loadCart() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final loggedIn = await AuthService.isLoggedIn();
    _isGuest = !loggedIn;

    if (_isGuest) {
      await _loadGuestCart();
      _isLoading = false;
      _hasLoadedOnce = true;
      notifyListeners();
      return;
    }

    try {
      final newCart = await CartService.fetchCart();
      _cart = newCart;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      _cart = RemoteCart.empty();
    } finally {
      _isLoading = false;
      _hasLoadedOnce = true;
      notifyListeners();
    }
  }

  Future<void> clearOnLogout() async {
    _cart = RemoteCart.empty();
    _appliedCode = null;
    _error = null;
    _isGuest = true;
    notifyListeners();

    await _loadGuestCart();
    notifyListeners();
  }

  Future<bool> addItem(String productId, {int quantity = 1}) async {
    if (_isGuest) {
      final quantities = await _readGuestQuantities();
      quantities[productId] = (quantities[productId] ?? 0) + quantity;
      await _writeGuestQuantities(quantities);
      await _loadGuestCart();
      notifyListeners();
      return true;
    }
    try {
      await CartService.addItem(productId, quantity: quantity);
      await loadCart();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateQuantity(String cartItemId, int quantity) async {
    if (quantity <= 0) {
      return removeItem(cartItemId);
    }

    if (_isGuest) {
      final productId = _productIdFromGuestItemId(cartItemId);
      if (productId == null) return false;
      final quantities = await _readGuestQuantities();
      quantities[productId] = quantity;
      await _writeGuestQuantities(quantities);
      await _loadGuestCart();
      notifyListeners();
      return true;
    }

    try {
      final updatedItem = await CartService.updateItemQuantity(
        cartItemId,
        quantity,
      );
      final idx = _cart.items.indexWhere((i) => i.id == cartItemId);
      if (idx >= 0) {
        _cart.items[idx] = updatedItem;
      }
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeItem(String cartItemId) async {
    if (_isGuest) {
      final productId = _productIdFromGuestItemId(cartItemId);
      if (productId == null) return false;
      final quantities = await _readGuestQuantities();
      quantities.remove(productId);
      await _writeGuestQuantities(quantities);
      await _loadGuestCart();
      notifyListeners();
      return true;
    }

    try {
      await CartService.removeItem(cartItemId);
      _cart.items.removeWhere((i) => i.id == cartItemId);
      notifyListeners();
      return true;
    } catch (e) {
      _error = e.toString().replaceFirst('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<void> clearCart() async {
    if (_isGuest) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_guestCartKey);
      _cart = RemoteCart.empty();
      _appliedCode = null;
      notifyListeners();
      return;
    }

    final ids = _cart.items.map((i) => i.id).toList();
    for (final id in ids) {
      try {
        await CartService.removeItem(id);
      } catch (e) {
        final msg = e.toString().toLowerCase();
        if (!msg.contains('not found')) rethrow;
      }
      _cart.items.removeWhere((i) => i.id == id);
    }
    _appliedCode = null;
    notifyListeners();
  }

  Future<void> syncGuestCartToServer() async {
    final quantities = await _readGuestQuantities();

    for (final entry in quantities.entries) {
      try {
        await CartService.addItem(entry.key, quantity: entry.value);
      } catch (_) {}
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_guestCartKey);

    _isGuest = false;
    await loadCart();
  }

  bool applyCoupon(String code) {
    final normalized = code.trim().toUpperCase();
    final coupon = availableCoupons[normalized];
    if (coupon == null) return false;
    if (subtotal < coupon.minOrder) return false;
    _appliedCode = normalized;
    notifyListeners();
    return true;
  }

  void removeCoupon() {
    _appliedCode = null;
    notifyListeners();
  }

  Future<void> refreshCartPrices() async {
    if (_isGuest) {
      await loadCart();
      return;
    }

    await loadCart();

    final updatedItems = <RemoteCartItem>[];
    for (var item in _cart.items) {
      try {
        final product = await ProductService.getProduct(item.product.id);
        updatedItems.add(
          RemoteCartItem(
            id: item.id,
            quantity: item.quantity,
            product: RemoteCartProduct(
              id: item.product.id,
              name: product.title,
              price: product.discountPrice ?? product.price,
              imageUrl: product.imageUrl,
              status: product.status,
            ),
          ),
        );
      } catch (e) {
        updatedItems.add(item);
      }
    }

    _cart = RemoteCart(
      id: _cart.id,
      customerId: _cart.customerId,
      items: updatedItems,
    );
    notifyListeners();
  }

  Future<void> refreshCartWithDiscounts() async {
    if (_isGuest) {
      await loadCart();
      return;
    }

    if (_cart.items.isEmpty) return;

    final updatedItems = <RemoteCartItem>[];
    bool hasChanges = false;

    for (var item in _cart.items) {
      try {
        final product = await ProductService.getProduct(item.product.id);
        final correctPrice = product.discountPrice ?? product.price;

        if (item.product.price != correctPrice) {
          hasChanges = true;
          updatedItems.add(
            RemoteCartItem(
              id: item.id,
              quantity: item.quantity,
              product: RemoteCartProduct(
                id: item.product.id,
                name: product.title,
                price: correctPrice,
                imageUrl: product.imageUrl,
                status: product.status,
              ),
            ),
          );
        } else {
          updatedItems.add(item);
        }
      } catch (e) {
        updatedItems.add(item);
      }
    }

    if (hasChanges) {
      _cart = RemoteCart(
        id: _cart.id,
        customerId: _cart.customerId,
        items: updatedItems,
      );
      notifyListeners();
    }
  }
}

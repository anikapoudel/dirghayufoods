import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/product_models.dart';

class ProductProvider extends ChangeNotifier {
  List<Product> _featuredProducts = [];
  List<Product> _allProducts = [];
  bool _isLoading = false;
  String? _error;

  List<Product> get featuredProducts => _featuredProducts;

  List<Product> get allProducts => _allProducts;

  bool get isLoading => _isLoading;

  String? get error => _error;

  // Fetch featured products
  Future<void> fetchFeaturedProducts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Fetch paginated products - you can customize the limit
      final paginated = await ApiService.fetchProductsPaginated(
        page: 1,
        limit: 10,
      );

      _featuredProducts = paginated.products;
      _error = null;
    } catch (e) {
      _error = e.toString();
      _featuredProducts = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Fetch all products
  Future<void> fetchAllProducts() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _allProducts = await ApiService.fetchProducts();
      _error = null;
    } catch (e) {
      _error = e.toString();
      _allProducts = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Refresh products
  Future<void> refreshProducts() async {
    await fetchFeaturedProducts();
    await fetchAllProducts();
  }

  // Get products by category
  Future<List<Product>> getProductsByCategory(String categoryId) async {
    try {
      return await ApiService.fetchProductsByCategory(categoryId);
    } catch (e) {
      return [];
    }
  }

  // Search products
  Future<List<Product>> searchProducts(String query) async {
    try {
      return await ApiService.searchProducts(query);
    } catch (e) {
      return [];
    }
  }
}

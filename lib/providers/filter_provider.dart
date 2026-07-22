import 'package:flutter/material.dart';

class FilterProvider extends ChangeNotifier {
  String selectedCategory = 'All Categories';
  double maxPrice = 3000;
  String selectedSort = 'Featured / Default';
  String searchQuery = '';

  void applyFilters({
    required String category,
    required double price,
    required String sort,
  }) {
    selectedCategory = category;
    maxPrice = price;
    selectedSort = sort;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    searchQuery = query;
    notifyListeners();
  }

  void resetFilters() {
    selectedCategory = 'All Categories';
    maxPrice = 3000;
    selectedSort = 'Featured / Default';
    searchQuery = '';
    notifyListeners();
  }
}

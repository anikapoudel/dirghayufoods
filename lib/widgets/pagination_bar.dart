import 'package:flutter/material.dart';

class PaginationBar extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final ValueChanged<int> onPageChanged;

  const PaginationBar({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      color: const Color(0xFFFDFBF7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _NavButton(
            icon: Icons.chevron_left,
            enabled: currentPage > 1,
            onTap: () => onPageChanged(currentPage - 1),
          ),
          const SizedBox(width: 8),
          ..._buildPageButtons(),
          const SizedBox(width: 8),
          _NavButton(
            icon: Icons.chevron_right,
            enabled: currentPage < totalPages,
            onTap: () => onPageChanged(currentPage + 1),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPageButtons() {
    final List<Widget> buttons = [];
    final List<dynamic> pageNumbers = _visiblePageNumbers();

    for (final p in pageNumbers) {
      if (p == '...') {
        buttons.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Text('...', style: TextStyle(color: Colors.grey)),
          ),
        );
      } else {
        buttons.add(
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _PageNumberButton(
              page: p as int,
              isActive: p == currentPage,
              onTap: () => onPageChanged(p),
            ),
          ),
        );
      }
    }
    return buttons;
  }

  List<dynamic> _visiblePageNumbers() {
    const int maxVisible = 5;
    if (totalPages <= maxVisible) {
      return List.generate(totalPages, (i) => i + 1);
    }

    final List<dynamic> pages = [1];
    int start = (currentPage - 1).clamp(2, totalPages - 3);
    int end = (currentPage + 1).clamp(4, totalPages - 1);

    if (start > 2) pages.add('...');
    for (int i = start; i <= end; i++) {
      pages.add(i);
    }
    if (end < totalPages - 1) pages.add('...');
    pages.add(totalPages);

    return pages;
  }
}

class _PageNumberButton extends StatelessWidget {
  final int page;
  final bool isActive;
  final VoidCallback onTap;

  const _PageNumberButton({
    required this.page,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isActive ? null : onTap,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isActive ? Colors.green[900] : Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          '$page',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : const Color(0xFF111827),
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? const Color(0xFF111827) : Colors.grey[300],
        ),
      ),
    );
  }
}

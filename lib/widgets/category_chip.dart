import 'package:flutter/material.dart';

class CategoryChip extends StatelessWidget {
  final String category;

  const CategoryChip({
    super.key,
    required this.category,
  });

  Color _getCategoryColor() {
    switch (category) {
      case 'Boundaries':
        return const Color(0xFFE74C3C);
      case 'Environment':
        return const Color(0xFF3498DB);
      case 'Life Systems':
        return const Color(0xFFF39C12);
      case 'Communication':
        return const Color(0xFF9B59B6);
      case 'Energy':
        return const Color(0xFF2ECC71);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getCategoryColor().withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getCategoryColor().withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Text(
        category,
        style: TextStyle(
          color: _getCategoryColor(),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}









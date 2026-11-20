import 'package:flutter/material.dart';

class ViewTogglePill extends StatelessWidget {
  final bool isTreeView;
  final ValueChanged<bool> onChanged;

  const ViewTogglePill({
    super.key,
    required this.isTreeView,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFFC7F0D2),
          width: 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0D331E),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildItem(
            label: 'Tree',
            icon: Icons.account_tree_rounded,
            isSelected: isTreeView,
            onTap: () => onChanged(true),
          ),
          const SizedBox(width: 2),
          _buildItem(
            label: 'List',
            icon: Icons.format_list_bulleted_rounded,
            isSelected: !isTreeView,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }

  Widget _buildItem({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF065F46) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected ? Colors.white : const Color(0xFF172B21),
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF172B21),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

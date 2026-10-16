import 'package:flutter/material.dart';
import '../config/theme.dart';

class TreeView extends StatelessWidget {
  final List<TreeNode> nodes;

  const TreeView({super.key, required this.nodes});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: nodes.map((node) => _buildNode(node, 0)).toList(),
    );
  }

  Widget _buildNode(TreeNode node, int depth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: depth * 24.0),
          child: Row(
            children: [
              if (depth > 0)
                Container(
                  width: 20,
                  height: 1,
                  color: AppColors.divider,
                  margin: const EdgeInsets.only(right: 8),
                ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                margin: const EdgeInsets.symmetric(vertical: 3),
                decoration: BoxDecoration(
                  color: depth == 0
                      ? AppColors.primary
                      : depth == 1
                          ? AppColors.surface
                          : AppColors.card,
                  borderRadius: BorderRadius.circular(10),
                  border: depth > 1
                      ? Border.all(color: AppColors.divider)
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      node.icon,
                      size: 16,
                      color: depth == 0 ? Colors.white : AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      node.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: depth == 0 ? FontWeight.w600 : FontWeight.w500,
                        color: depth == 0 ? Colors.white : AppColors.textDark,
                      ),
                    ),
                    if (node.badge != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: depth == 0
                              ? Colors.white.withAlpha(50)
                              : AppColors.primary.withAlpha(30),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          node.badge!,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: depth == 0 ? Colors.white : AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        ...node.children.map((child) => _buildNode(child, depth + 1)),
      ],
    );
  }
}

class TreeNode {
  final String label;
  final IconData icon;
  final String? badge;
  final List<TreeNode> children;

  const TreeNode({
    required this.label,
    required this.icon,
    this.badge,
    this.children = const [],
  });
}

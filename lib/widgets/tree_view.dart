import 'package:flutter/material.dart';
import '../config/theme.dart';

/// A fully interactive, animated tree view widget.
/// Each [TreeNode] can be expanded/collapsed and tapped to show details.
class InteractiveTreeView extends StatefulWidget {
  final List<TreeNode> nodes;

  const InteractiveTreeView({super.key, required this.nodes});

  @override
  State<InteractiveTreeView> createState() => _InteractiveTreeViewState();
}

class _InteractiveTreeViewState extends State<InteractiveTreeView> {
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    // Auto-expand root nodes
    for (final n in widget.nodes) {
      _expanded.add(n.id);
    }
  }

  void _toggle(String id) {
    setState(() {
      if (_expanded.contains(id)) {
        _expanded.remove(id);
      } else {
        _expanded.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widget.nodes.map((n) => _buildNode(context, n, 0)).toList(),
    );
  }

  Widget _buildNode(BuildContext context, TreeNode node, int depth) {
    final isExpanded = _expanded.contains(node.id);
    final hasChildren = node.children.isNotEmpty;
    final isRoot = depth == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _NodeTile(
          node: node,
          depth: depth,
          isExpanded: isExpanded,
          hasChildren: hasChildren,
          isRoot: isRoot,
          onToggle: hasChildren ? () => _toggle(node.id) : null,
          onTap: node.onTap,
        ),
        if (hasChildren && isExpanded)
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: node.children
                  .map((child) => _buildNode(context, child, depth + 1))
                  .toList(),
            ),
          ),
      ],
    );
  }
}

class _NodeTile extends StatelessWidget {
  final TreeNode node;
  final int depth;
  final bool isExpanded;
  final bool hasChildren;
  final bool isRoot;
  final VoidCallback? onToggle;
  final VoidCallback? onTap;

  const _NodeTile({
    required this.node,
    required this.depth,
    required this.isExpanded,
    required this.hasChildren,
    required this.isRoot,
    this.onToggle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final indent = depth * 20.0;

    // Color scheme by depth
    final Color bgColor;
    final Color textColor;
    final Color iconColor;
    if (isRoot) {
      bgColor = AppColors.primary;
      textColor = Colors.white;
      iconColor = Colors.white;
    } else if (depth == 1) {
      bgColor = const Color(0xFFDEF2D7);
      textColor = const Color(0xFF235E1E);
      iconColor = AppColors.primary;
    } else {
      bgColor = Colors.white;
      textColor = AppColors.textDark;
      iconColor = AppColors.primary;
    }

    return Padding(
      padding: EdgeInsets.only(left: indent, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Connector line for non-root nodes
          if (depth > 0) ...[
            Container(
              width: 16,
              height: 1.5,
              color: AppColors.divider,
              margin: const EdgeInsets.only(right: 6),
            ),
          ],
          Flexible(
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onTap ?? onToggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: isRoot
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withAlpha(40),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : depth == 1
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withAlpha(15),
                                  blurRadius: 4,
                                )
                              ]
                            : null,
                    border: depth > 1
                        ? Border.all(color: AppColors.border, width: 1)
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(node.icon, size: 15, color: iconColor),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          node.label,
                          style: TextStyle(
                            fontSize: isRoot ? 13 : 12,
                            fontWeight: isRoot ? FontWeight.w700 : FontWeight.w600,
                            color: textColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (node.badge != null) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: isRoot
                                ? Colors.white.withAlpha(55)
                                : AppColors.primary.withAlpha(30),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            node.badge!,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: isRoot ? Colors.white : AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                      if (hasChildren) ...[
                        const SizedBox(width: 6),
                        AnimatedRotation(
                          turns: isExpanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: iconColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Data model for a tree node
class TreeNode {
  /// Unique identifier (used for expand/collapse tracking)
  final String id;
  final String label;
  final IconData icon;
  final String? badge;
  final List<TreeNode> children;

  /// Called when user taps this node (if provided)
  final VoidCallback? onTap;

  const TreeNode({
    required this.id,
    required this.label,
    required this.icon,
    this.badge,
    this.children = const [],
    this.onTap,
  });
}

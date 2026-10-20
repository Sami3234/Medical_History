import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/member_model.dart';
import 'app_avatar.dart';

/// Relationship generational classification and ordering
enum FamilyGeneration {
  grandparents(
    level: 1,
    title: '1st Gen • Grandparents',
    color: Color(0xFF7C3AED),
    bgColor: Color(0xFFF5F3FF),
    borderColor: Color(0xFFDDD6FE),
  ),
  parents(
    level: 2,
    title: '2nd Gen • Parents & Core',
    color: Color(0xFF16A34A),
    bgColor: Color(0xFFF0FDF4),
    borderColor: Color(0xFFBBF7D0),
  ),
  children(
    level: 3,
    title: '3rd Gen • Children',
    color: Color(0xFF0284C7),
    bgColor: Color(0xFFF0F9FF),
    borderColor: Color(0xFFBAE6FD),
  ),
  other(
    level: 4,
    title: 'Extended Family',
    color: Color(0xFF64748B),
    bgColor: Color(0xFFF8FAFC),
    borderColor: Color(0xFFE2E8F0),
  );

  final int level;
  final String title;
  final Color color;
  final Color bgColor;
  final Color borderColor;

  const FamilyGeneration({
    required this.level,
    required this.title,
    required this.color,
    required this.bgColor,
    required this.borderColor,
  });

  static FamilyGeneration fromRelation(String? relation) {
    final rel = (relation ?? '').toLowerCase().trim();
    if (rel.contains('grandfather') ||
        rel.contains('grandmother') ||
        rel.contains('grandpa') ||
        rel.contains('grandma') ||
        rel.contains('dada') ||
        rel.contains('dadi') ||
        rel.contains('nana') ||
        rel.contains('nani')) {
      return FamilyGeneration.grandparents;
    }
    if (rel.contains('father') ||
        rel.contains('mother') ||
        rel == 'self' ||
        rel == 'spouse' ||
        rel == 'wife' ||
        rel == 'husband' ||
        rel.contains('brother') ||
        rel.contains('sister')) {
      return FamilyGeneration.parents;
    }
    if (rel.contains('son') ||
        rel.contains('daughter') ||
        rel.contains('child') ||
        rel.contains('kid')) {
      return FamilyGeneration.children;
    }
    return FamilyGeneration.other;
  }
}

/// Helper for relationship order and icons
int getRelationRank(String? relation) {
  final rel = (relation ?? '').toLowerCase().trim();
  switch (rel) {
    case 'grandfather':
      return 1;
    case 'grandmother':
      return 2;
    case 'father':
      return 3;
    case 'mother':
      return 4;
    case 'self':
      return 5;
    case 'spouse':
    case 'wife':
    case 'husband':
      return 6;
    case 'brother':
      return 7;
    case 'sister':
      return 8;
    case 'son':
      return 9;
    case 'daughter':
      return 10;
    case 'child':
      return 11;
    default:
      return 12;
  }
}

IconData getRelationIcon(String? relation) {
  final rel = (relation ?? '').toLowerCase().trim();
  if (rel.contains('grandfather')) return Icons.elderly_rounded;
  if (rel.contains('grandmother')) return Icons.elderly_woman_rounded;
  if (rel.contains('father')) return Icons.man_rounded;
  if (rel.contains('mother')) return Icons.woman_rounded;
  if (rel == 'self') return Icons.person_rounded;
  if (rel == 'spouse' || rel == 'wife' || rel == 'husband') {
    return Icons.favorite_rounded;
  }
  if (rel.contains('brother')) return Icons.boy_rounded;
  if (rel.contains('sister')) return Icons.girl_rounded;
  if (rel.contains('son')) return Icons.boy_rounded;
  if (rel.contains('daughter')) return Icons.girl_rounded;
  if (rel.contains('child')) return Icons.child_care_rounded;
  return Icons.person_outline_rounded;
}

Color getRelationBadgeColor(String? relation) {
  final rel = (relation ?? '').toLowerCase().trim();
  if (rel == 'self') return const Color(0xFF16A34A);
  if (rel == 'spouse' || rel == 'wife' || rel == 'husband') {
    return const Color(0xFFE11D48);
  }
  if (rel.contains('father') || rel.contains('mother')) {
    return const Color(0xFF0D9488);
  }
  if (rel.contains('grandfather') || rel.contains('grandmother')) {
    return const Color(0xFF7C3AED);
  }
  if (rel.contains('son') ||
      rel.contains('daughter') ||
      rel.contains('child')) {
    return const Color(0xFF0284C7);
  }
  return const Color(0xFF64748B);
}

/// Custom painter for authentic continuous tree branch lines
class TreeBranchLinePainter extends CustomPainter {
  final bool isLast;
  final Color lineColor;
  final double strokeWidth;
  final double? trunkX;

  TreeBranchLinePainter({
    required this.isLast,
    this.lineColor = const Color(0xFF94A3B8),
    this.strokeWidth = 2.0,
    this.trunkX,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final startX = trunkX ?? size.width / 2;
    final midY = size.height / 2;

    // Continuous vertical trunk line:
    // If not last, draw full height from 0 to size.height
    // If last, draw from 0 down to midY
    canvas.drawLine(
      Offset(startX, 0),
      Offset(startX, isLast ? midY : size.height),
      paint,
    );

    // Curved branch arm turning into the child node
    final path = Path();
    path.moveTo(startX, midY);
    path.quadraticBezierTo(startX + 4, midY, size.width, midY);
    canvas.drawPath(path, paint);

    // Branch node connection dot
    final dotPaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(startX, midY), 3.2, dotPaint);
  }

  @override
  bool shouldRepaint(covariant TreeBranchLinePainter oldDelegate) =>
      oldDelegate.isLast != isLast ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.trunkX != trunkX;
}

/// Modern interactive family tree with genuine tree branch connectors,
/// relationship hierarchy ordering, age display, and expand/collapse animation.
class InteractiveTreeView extends StatefulWidget {
  final List<TreeNode>? nodes;
  final List<MemberModel>? members;
  final String? familyName;
  final void Function(MemberModel member)? onMemberTap;
  final VoidCallback? onAddMember;

  const InteractiveTreeView({
    super.key,
    this.nodes,
    this.members,
    this.familyName,
    this.onMemberTap,
    this.onAddMember,
  });

  @override
  State<InteractiveTreeView> createState() => _InteractiveTreeViewState();
}

enum TreeDisplayMode { hierarchical, generational }

class _InteractiveTreeViewState extends State<InteractiveTreeView> {
  bool _rootExpanded = true;
  final Set<String> _expandedBranches = {'gen-1', 'gen-2', 'gen-3', 'gen-4'};
  TreeDisplayMode _displayMode = TreeDisplayMode.hierarchical;

  List<MemberModel> _getSortedMembers() {
    final list = List<MemberModel>.from(widget.members ?? []);
    list.sort((a, b) {
      final rankA = getRelationRank(a.relation);
      final rankB = getRelationRank(b.relation);
      if (rankA != rankB) return rankA.compareTo(rankB);
      return a.name.compareTo(b.name);
    });
    return list;
  }

  void _toggleBranch(String branchId) {
    setState(() {
      if (_expandedBranches.contains(branchId)) {
        _expandedBranches.remove(branchId);
      } else {
        _expandedBranches.add(branchId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final members = _getSortedMembers();

    // Fallback for legacy TreeNode usage if members list is empty
    if (members.isEmpty && (widget.nodes == null || widget.nodes!.isEmpty)) {
      return _buildEmptyState();
    }

    if (members.isEmpty && widget.nodes != null && widget.nodes!.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widget.nodes!.map((n) => _buildLegacyNode(n, 0)).toList(),
      );
    }

    // Active generation count
    final activeGenerations = members
        .map((m) => FamilyGeneration.fromRelation(m.relation))
        .toSet();

    final familyTitle = widget.familyName ?? 'Family Tree';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Top Bar: Hierarchy Stats & Mode Switcher ───────────────────
        LayoutBuilder(
          builder: (context, constraints) {
            final stats = Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3.5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withAlpha(50)),
                  ),
                  child: Text(
                    '${activeGenerations.length} Generations',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${members.length} Members',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            );
            final modeToggle = Container(
              padding: const EdgeInsets.all(2.5),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildModeToggleBtn(
                    label: 'Tree',
                    icon: Icons.account_tree_rounded,
                    isSelected: _displayMode == TreeDisplayMode.hierarchical,
                    onTap: () => setState(
                      () => _displayMode = TreeDisplayMode.hierarchical,
                    ),
                  ),
                  _buildModeToggleBtn(
                    label: 'Generations',
                    icon: Icons.alt_route_rounded,
                    isSelected: _displayMode == TreeDisplayMode.generational,
                    onTap: () => setState(
                      () => _displayMode = TreeDisplayMode.generational,
                    ),
                  ),
                ],
              ),
            );

            if (constraints.maxWidth < 420) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  stats,
                  const SizedBox(height: 8),
                  Align(alignment: Alignment.centerRight, child: modeToggle),
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: stats),
                const SizedBox(width: 10),
                modeToggle,
              ],
            );
          },
        ),
        const SizedBox(height: 12),

        // ── Root Family Node (Tree Trunk Header) ───────────────────────
        _buildRootFamilyNode(familyTitle, members.length),

        // ── Tree Branches & Leaves ─────────────────────────────────────
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: _rootExpanded
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Trunk top stem connector - centered at 24.0 to match branches
                    Padding(
                      padding: const EdgeInsets.only(left: 23),
                      child: Container(
                        width: 2,
                        height: 14,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                    if (_displayMode == TreeDisplayMode.hierarchical)
                      // Direct relational tree
                      ..._buildDirectTreeMembers(members)
                    else
                      // Generational branched tree
                      ..._buildGenerationalTreeBranches(members),
                  ],
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildModeToggleBtn({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: AppColors.shadow,
                    blurRadius: 3,
                    offset: Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? AppColors.primary : AppColors.textLight,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Root Node: Family Trunk ──────────────────────────────────────────
  Widget _buildRootFamilyNode(String familyTitle, int count) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _rootExpanded = !_rootExpanded),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF235E1E), Color(0xFF2E7D25)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF235E1E).withAlpha(45),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(45),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white70, width: 1.2),
                ),
                child: const Icon(
                  Icons.family_restroom_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      familyTitle,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$count family members registered',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.white.withAlpha(210),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(35),
                  shape: BoxShape.circle,
                ),
                child: AnimatedRotation(
                  turns: _rootExpanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Mode 1: Direct Relational Tree (Tree branch lines to each member) ─
  List<Widget> _buildDirectTreeMembers(List<MemberModel> members) {
    // Keep the direct mode explicit as separate generation branches. A single
    // continuous trunk makes children look attached to the wrong adult.
    return _buildGenerationalTreeBranches(members);
  }

  String _childrenParentLabel(
    List<MemberModel> members, {
    List<MemberModel>? children,
  }) {
    final parentIds = children
        ?.map((child) => child.parentId)
        .whereType<String>()
        .toSet();
    if (parentIds != null && parentIds.isNotEmpty) {
      final parentNames = members
          .where((member) => parentIds.contains(member.id))
          .map((member) => member.name)
          .toList();
      if (parentNames.isNotEmpty) return parentNames.join(' & ');
    }

    String? selfName;
    String? spouseName;

    for (final member in members) {
      final relation = member.relation.toLowerCase().trim();
      if (relation == 'self') selfName = member.name;
      if (relation == 'spouse' || relation == 'wife' || relation == 'husband') {
        spouseName = member.name;
      }
    }

    if (selfName != null && spouseName != null) {
      return '$selfName & $spouseName';
    }
    return selfName ?? spouseName ?? widget.familyName ?? 'Core Family';
  }

  List<Widget> _buildLocalBranchMembers(
    List<MemberModel> members,
    FamilyGeneration generation, {
    bool compact = false,
  }) {
    return List.generate(members.length, (index) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CustomPaint(
            painter: TreeBranchLinePainter(
              isLast: index == members.length - 1,
              lineColor: generation.color.withAlpha(145),
              strokeWidth: 1.8,
              trunkX: 10,
            ),
            size: Size(30, compact ? 62 : 74),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _buildMemberCard(members[index], compact: compact),
            ),
          ),
        ],
      );
    });
  }

  // ── Mode 2: Generational Branches (Grandparents -> Parents -> Children) ─
  List<Widget> _buildGenerationalTreeBranches(List<MemberModel> members) {
    final grandparents = members
        .where(
          (m) =>
              FamilyGeneration.fromRelation(m.relation) ==
              FamilyGeneration.grandparents,
        )
        .toList();
    final parents = members
        .where(
          (m) =>
              FamilyGeneration.fromRelation(m.relation) ==
              FamilyGeneration.parents,
        )
        .toList();
    final children = members
        .where(
          (m) =>
              FamilyGeneration.fromRelation(m.relation) ==
              FamilyGeneration.children,
        )
        .toList();
    final others = members
        .where(
          (m) =>
              FamilyGeneration.fromRelation(m.relation) ==
              FamilyGeneration.other,
        )
        .toList();

    final activeGroups = <MapEntry<FamilyGeneration, List<MemberModel>>>[];
    if (grandparents.isNotEmpty) {
      activeGroups.add(MapEntry(FamilyGeneration.grandparents, grandparents));
    }
    if (parents.isNotEmpty) {
      activeGroups.add(MapEntry(FamilyGeneration.parents, parents));
    }
    if (children.isNotEmpty) {
      activeGroups.add(MapEntry(FamilyGeneration.children, children));
    }
    if (others.isNotEmpty) {
      activeGroups.add(MapEntry(FamilyGeneration.other, others));
    }

    return List.generate(activeGroups.length, (gIndex) {
      final gen = activeGroups[gIndex].key;
      final groupMembers = activeGroups[gIndex].value;
      final branchId = 'gen-${gen.level}';
      final isExpanded = _expandedBranches.contains(branchId);
      final isChildrenGroup = gen == FamilyGeneration.children;
      final headerTitle = isChildrenGroup
          ? 'Children of ${_childrenParentLabel(members, children: groupMembers)}'
          : gen.title;

      return Container(
        margin: EdgeInsets.only(top: gIndex == 0 ? 10 : 4, bottom: 10),
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
        decoration: BoxDecoration(
          color: gen.bgColor.withAlpha(125),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: gen.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => _toggleBranch(branchId),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                decoration: BoxDecoration(
                  color: gen.bgColor,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: gen.borderColor, width: 1.1),
                ),
                child: Row(
                  children: [
                    Icon(
                      isChildrenGroup
                          ? Icons.family_restroom_rounded
                          : Icons.hub_rounded,
                      size: 15,
                      color: gen.color,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        headerTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: gen.color,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: gen.borderColor),
                      ),
                      child: Text(
                        '${groupMembers.length}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: gen.color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 5),
                    AnimatedRotation(
                      turns: isExpanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: gen.color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (isExpanded)
              ..._buildLocalBranchMembers(
                groupMembers,
                gen,
                compact: isChildrenGroup,
              ),
          ],
        ),
      );
    });
  }

  // ── Modern Member Node Card ──────────────────────────────────────────
  Widget _buildMemberCard(MemberModel member, {bool compact = false}) {
    final relation = member.relation;
    final isSelf = relation.toLowerCase().trim() == 'self';
    final relIcon = getRelationIcon(relation);
    final badgeColor = getRelationBadgeColor(relation);
    final gen = FamilyGeneration.fromRelation(relation);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => widget.onMemberTap?.call(member),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 14,
            vertical: compact ? 7 : 10,
          ),
          decoration: BoxDecoration(
            color: isSelf ? const Color(0xFFF0FDF4) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelf ? AppColors.primary : AppColors.border,
              width: isSelf ? 1.6 : 1.1,
            ),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadow,
                blurRadius: 5,
                offset: Offset(0, 1.5),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Avatar with generation ring
              Stack(
                alignment: Alignment.center,
                children: [
                  AppAvatar(
                    name: member.name,
                    avatarUrl: member.avatarUrl,
                    memberId: member.id,
                    size: compact ? 33 : 40,
                    border: Border.all(
                      color: isSelf ? AppColors.primary : gen.color,
                      width: 1.8,
                    ),
                  ),
                  if (isSelf)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.star_rounded,
                          size: 9,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(width: compact ? 9 : 12),

              // Name, Relation, Age & Blood Group
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name & Relation Badge Row
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            member.name,
                            style: TextStyle(
                              fontSize: compact ? 12.5 : 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: badgeColor.withAlpha(20),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(relIcon, size: 10, color: badgeColor),
                              const SizedBox(width: 3),
                              Text(
                                relation,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: badgeColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: compact ? 3 : 5),

                    // Badges Wrap: Age (Prominent), Blood Group, Generation
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Age Badge (Required & clearly visible)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.cake_outlined,
                                size: 10,
                                color: AppColors.textLight,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                member.age,
                                style: TextStyle(
                                  fontSize: compact ? 9.5 : 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textDark,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Blood Group Badge
                        if (member.bloodGroup != null &&
                            member.bloodGroup!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFECEC),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              member.bloodGroup!,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                          ),

                        // Generation Tag
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: gen.bgColor,
                            borderRadius: BorderRadius.circular(5),
                            border: Border.all(
                              color: gen.borderColor,
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            'Gen ${gen.level}',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: gen.color,
                            ),
                          ),
                        ),

                        // Hereditary / Chronic Condition Badge
                        if (member.notes != null &&
                            member.notes!.trim().isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: const Color(0xFFFDE68A),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.favorite_rounded,
                                  size: 9,
                                  color: Color(0xFFD97706),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  member.notes!.length > 12
                                      ? '${member.notes!.substring(0, 10)}..'
                                      : member.notes!,
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFB45309),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Allergy Alert Badge
                        if (member.allergies != null &&
                            member.allergies!.trim().isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEE2E2),
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: const Color(0xFFFECACA),
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  size: 9,
                                  color: Color(0xFFDC2626),
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  member.allergies!.length > 10
                                      ? '${member.allergies!.substring(0, 8)}..'
                                      : member.allergies!,
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFFB91C1C),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Arrow indicator
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13,
                color: AppColors.textLight,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(20),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.family_restroom_rounded,
              size: 28,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Family Tree is Empty',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add your family members (Grandparents, Parents, Self, Children) to build your tree.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textLight),
          ),
          const SizedBox(height: 14),
          if (widget.onAddMember != null)
            ElevatedButton.icon(
              onPressed: widget.onAddMember,
              icon: const Icon(Icons.person_add_rounded, size: 16),
              label: const Text('Add Member'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 9,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Backward Compatible Legacy TreeNode Renderer ─────────────────────
  Widget _buildLegacyNode(TreeNode node, int depth) {
    return Padding(
      padding: EdgeInsets.only(left: depth * 22.0, bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: node.onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: depth == 0 ? AppColors.primary : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: depth > 0 ? Border.all(color: AppColors.border) : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AppAvatar(
                  name: node.label,
                  avatarUrl: node.avatarUrl,
                  size: 26,
                ),
                const SizedBox(width: 8),
                Text(
                  node.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: depth == 0 ? Colors.white : AppColors.textDark,
                  ),
                ),
                if (node.relation != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    '(${node.relation})',
                    style: const TextStyle(fontSize: 11),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Backwards compatible TreeNode model for existing consumers
class TreeNode {
  final String id;
  final String label;
  final IconData icon;
  final String? badge;
  final String? avatarUrl;
  final String? relation;
  final String? age;
  final String? bloodGroup;
  final int generation;
  final List<TreeNode> children;
  final VoidCallback? onTap;

  const TreeNode({
    required this.id,
    required this.label,
    required this.icon,
    this.badge,
    this.avatarUrl,
    this.relation,
    this.age,
    this.bloodGroup,
    this.generation = 2,
    this.children = const [],
    this.onTap,
  });
}

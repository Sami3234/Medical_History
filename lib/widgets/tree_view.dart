import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../models/doctor_model.dart';
import '../models/member_model.dart';
import 'app_avatar.dart';

class _MeasureSize extends SingleChildRenderObjectWidget {
  const _MeasureSize({required this.onChange, required super.child});

  final ValueChanged<Size> onChange;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _MeasureSizeRenderObject(onChange);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _MeasureSizeRenderObject renderObject,
  ) {
    renderObject.onChange = onChange;
  }
}

class _MeasureSizeRenderObject extends RenderProxyBox {
  _MeasureSizeRenderObject(this.onChange);

  ValueChanged<Size> onChange;
  Size? _previousSize;

  @override
  void performLayout() {
    super.performLayout();
    final measuredSize = child?.size ?? Size.zero;
    if (_previousSize == measuredSize) return;
    _previousSize = measuredSize;
    WidgetsBinding.instance.addPostFrameCallback((_) => onChange(measuredSize));
  }
}

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
  if (rel == 'brother' || rel == 'sister') {
    return const Color(0xFF7C3AED);
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

class GenerationConnectorPainter extends CustomPainter {
  final int memberCount;
  final double cardWidth;
  final double spacing;
  final Color color;

  const GenerationConnectorPainter({
    required this.memberCount,
    required this.cardWidth,
    required this.spacing,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (memberCount == 0) return;
    final paint = Paint()
      ..color = color.withAlpha(145)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final cardsWidth =
        memberCount * cardWidth + math.max(0, memberCount - 1) * spacing;
    final firstCenter = (size.width - cardsWidth) / 2 + cardWidth / 2;
    final lastCenter = firstCenter + (memberCount - 1) * (cardWidth + spacing);
    final centerX = size.width / 2;
    const junctionY = 13.0;

    canvas.drawLine(Offset(centerX, 0), Offset(centerX, junctionY), paint);
    canvas.drawLine(
      Offset(firstCenter, junctionY),
      Offset(lastCenter, junctionY),
      paint,
    );
    for (var index = 0; index < memberCount; index++) {
      final x = firstCenter + index * (cardWidth + spacing);
      canvas.drawLine(Offset(x, junctionY), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant GenerationConnectorPainter oldDelegate) =>
      oldDelegate.memberCount != memberCount ||
      oldDelegate.cardWidth != cardWidth ||
      oldDelegate.spacing != spacing ||
      oldDelegate.color != color;
}

class CoupleContinuationPainter extends CustomPainter {
  final double ownerX;
  final double? spouseX;
  final double targetX;
  final Color color;

  const CoupleContinuationPainter({
    required this.ownerX,
    required this.targetX,
    required this.color,
    this.spouseX,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withAlpha(145)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    const junctionY = 7.0;
    const routeY = 12.0;
    final partnerX = spouseX;

    if (partnerX == null) {
      final path = Path()
        ..moveTo(ownerX, 0)
        ..lineTo(ownerX, routeY)
        ..lineTo(targetX, routeY)
        ..lineTo(targetX, size.height);
      canvas.drawPath(path, paint);
      return;
    }

    final coupleCenter = (ownerX + partnerX) / 2;
    canvas.drawLine(Offset(ownerX, 0), Offset(ownerX, junctionY), paint);
    canvas.drawLine(Offset(partnerX, 0), Offset(partnerX, junctionY), paint);
    canvas.drawLine(
      Offset(ownerX, junctionY),
      Offset(partnerX, junctionY),
      paint,
    );
    final path = Path()
      ..moveTo(coupleCenter, junctionY)
      ..lineTo(coupleCenter, routeY)
      ..lineTo(targetX, routeY)
      ..lineTo(targetX, size.height);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CoupleContinuationPainter oldDelegate) =>
      oldDelegate.ownerX != ownerX ||
      oldDelegate.spouseX != spouseX ||
      oldDelegate.targetX != targetX ||
      oldDelegate.color != color;
}

class DoctorConnectorPainter extends CustomPainter {
  final int doctorCount;
  final double avatarSize;
  final double spacing;
  final Color color;

  const DoctorConnectorPainter({
    required this.doctorCount,
    required this.avatarSize,
    required this.spacing,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (doctorCount == 0) return;
    final paint = Paint()
      ..color = color.withAlpha(145)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final firstCenter = avatarSize / 2;
    final lastCenter = firstCenter + (doctorCount - 1) * (avatarSize + spacing);
    final centerX = size.width / 2;
    final junctionY = doctorCount == 1 ? size.height : size.height * 0.55;

    canvas.drawLine(Offset(centerX, 0), Offset(centerX, junctionY), paint);
    if (doctorCount > 1) {
      canvas.drawLine(
        Offset(firstCenter, junctionY),
        Offset(lastCenter, junctionY),
        paint,
      );
      for (var index = 0; index < doctorCount; index++) {
        final doctorX = firstCenter + index * (avatarSize + spacing);
        canvas.drawLine(
          Offset(doctorX, junctionY),
          Offset(doctorX, size.height),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant DoctorConnectorPainter oldDelegate) =>
      oldDelegate.doctorCount != doctorCount ||
      oldDelegate.avatarSize != avatarSize ||
      oldDelegate.spacing != spacing ||
      oldDelegate.color != color;
}

/// Modern interactive family tree with genuine tree branch connectors,
/// relationship hierarchy ordering, age display, and expand/collapse animation.
class InteractiveTreeView extends StatefulWidget {
  final List<TreeNode>? nodes;
  final List<MemberModel>? members;
  final Map<String, List<DoctorModel>> memberDoctors;
  final String? currentUserName;
  final String? familyName;
  final void Function(MemberModel member)? onMemberTap;
  final VoidCallback? onAddMember;
  final bool showToolbar;
  final bool showRootNode;

  const InteractiveTreeView({
    super.key,
    this.nodes,
    this.members,
    this.memberDoctors = const {},
    this.currentUserName,
    this.familyName,
    this.onMemberTap,
    this.onAddMember,
    this.showToolbar = true,
    this.showRootNode = true,
  });

  @override
  State<InteractiveTreeView> createState() => _InteractiveTreeViewState();
}

enum TreeDisplayMode { hierarchical, generational }

class _InteractiveTreeViewState extends State<InteractiveTreeView> {
  Set<String>? _collapsedBranches;
  TreeDisplayMode _displayMode = TreeDisplayMode.hierarchical;
  final TransformationController _treeController = TransformationController();
  bool _treeWasMoved = false;
  double _fitScale = 1;
  double _lastCanvasWidth = 0;
  double _lastViewportWidth = 0;
  double? _treeContentHeight;

  @override
  void dispose() {
    _treeController.dispose();
    super.dispose();
  }

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
      final collapsedBranches = _collapsedBranches ??= <String>{};
      if (collapsedBranches.contains(branchId)) {
        collapsedBranches.remove(branchId);
      } else {
        collapsedBranches.add(branchId);
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

    MemberModel? ownerMember;
    for (final member in members) {
      if (_isCurrentUserMember(member)) {
        ownerMember = member;
        break;
      }
    }
    final familyTitle = ownerMember?.name ?? widget.familyName ?? 'Family Tree';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Top Bar: Hierarchy Stats & Mode Switcher ───────────────────
        if (widget.showToolbar)
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
                      border: Border.all(
                        color: AppColors.primary.withAlpha(50),
                      ),
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
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: context.appTextSecondary,
                    ),
                  ),
                ],
              );
              final modeToggle = Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  color: context.appSurfaceRaised,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: context.appBorder),
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
        if (widget.showToolbar) const SizedBox(height: 12),

        if (widget.showRootNode)
          _buildRootFamilyNode(familyTitle, members.length),
        if (widget.showRootNode)
          Align(
            alignment: Alignment.center,
            child: Container(
              width: 2,
              height: 14,
              color: const Color(0xFF94A3B8),
            ),
          ),
        _buildZoomableTreeCanvas(members),
      ],
    );
  }

  Widget _buildZoomableTreeCanvas(List<MemberModel> members) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportWidth = constraints.maxWidth;
        final canvasWidth = _calculateTreeCanvasWidth(members, viewportWidth);
        final nextFitScale = (viewportWidth / canvasWidth).clamp(0.5, 1.0);

        if (!_treeWasMoved &&
            ((_lastCanvasWidth - canvasWidth).abs() > 0.5 ||
                (_lastViewportWidth - viewportWidth).abs() > 0.5)) {
          _lastCanvasWidth = canvasWidth;
          _lastViewportWidth = viewportWidth;
          _fitScale = nextFitScale;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _treeWasMoved) return;
            _treeController.value = _centeredTreeMatrix(
              viewportWidth,
              canvasWidth,
              _fitScale,
            );
          });
        }
        final canvasHeight =
            _treeContentHeight ?? _calculateTreeCanvasHeight(members);
        final viewportHeight = math.max(70.0, canvasHeight * _fitScale + 2);

        return SizedBox(
          width: viewportWidth,
          height: viewportHeight,
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  transformationController: _treeController,
                  alignment: Alignment.topLeft,
                  constrained: false,
                  minScale: math.max(0.35, nextFitScale * 0.7),
                  maxScale: 2.4,
                  boundaryMargin: const EdgeInsets.symmetric(
                    horizontal: 72,
                    vertical: 36,
                  ),
                  panAxis: PanAxis.free,
                  clipBehavior: Clip.hardEdge,
                  trackpadScrollCausesScale: true,
                  onInteractionStart: (_) => _treeWasMoved = true,
                  child: _MeasureSize(
                    onChange: (size) {
                      if (!mounted ||
                          (_treeContentHeight != null &&
                              (_treeContentHeight! - size.height).abs() <
                                  0.5)) {
                        return;
                      }
                      setState(() => _treeContentHeight = size.height);
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted || _treeWasMoved) return;
                        _treeController.value = _centeredTreeMatrix(
                          viewportWidth,
                          canvasWidth,
                          _fitScale,
                        );
                      });
                    },
                    child: SizedBox(
                      width: canvasWidth,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_displayMode == TreeDisplayMode.hierarchical)
                            ..._buildDirectTreeMembers(members)
                          else
                            ..._buildGenerationalTreeBranches(members),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Tooltip(
                  message: 'Reset tree view',
                  child: Material(
                    color: Colors.white.withAlpha(225),
                    shape: const CircleBorder(),
                    elevation: 2,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        setState(() {
                          _treeWasMoved = false;
                        });
                        _treeController.value = _centeredTreeMatrix(
                          viewportWidth,
                          canvasWidth,
                          _fitScale,
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.fit_screen_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Matrix4 _centeredTreeMatrix(
    double viewportWidth,
    double canvasWidth,
    double scale,
  ) {
    final horizontalOffset = math.max(
      0.0,
      (viewportWidth - (canvasWidth * scale)) / 2,
    );
    return Matrix4.identity()
      ..setEntry(0, 0, scale)
      ..setEntry(1, 1, scale)
      ..setTranslationRaw(horizontalOffset, 0, 0);
  }

  double _calculateTreeCanvasWidth(
    List<MemberModel> members,
    double viewportWidth,
  ) {
    final groups = <({int count, double cardWidth})>[
      (
        count: members
            .where(
              (member) =>
                  FamilyGeneration.fromRelation(member.relation) ==
                  FamilyGeneration.grandparents,
            )
            .length,
        cardWidth: 214,
      ),
      (
        count: members.where((member) {
          final relation = member.relation.toLowerCase().trim();
          return relation == 'father' || relation == 'mother';
        }).length,
        cardWidth: 214,
      ),
      (
        count: members.where((member) {
          final relation = member.relation.toLowerCase().trim();
          return _isCurrentUserMember(member) ||
              relation == 'spouse' ||
              relation == 'wife' ||
              relation == 'husband' ||
              relation == 'brother' ||
              relation == 'sister';
        }).length,
        cardWidth: 214,
      ),
      (
        count: members
            .where(
              (member) =>
                  !_isCurrentUserMember(member) &&
                  FamilyGeneration.fromRelation(member.relation) ==
                      FamilyGeneration.children,
            )
            .length,
        cardWidth: 176,
      ),
      (
        count: members
            .where(
              (member) =>
                  FamilyGeneration.fromRelation(member.relation) ==
                  FamilyGeneration.other,
            )
            .length,
        cardWidth: 214,
      ),
    ];
    var requiredWidth = viewportWidth;
    for (final group in groups) {
      if (group.count == 0) continue;
      final groupWidth =
          group.count * group.cardWidth + math.max(0, group.count - 1) * 14;
      requiredWidth = math.max(requiredWidth, groupWidth + 24);
    }
    return requiredWidth;
  }

  double _calculateTreeCanvasHeight(List<MemberModel> members) {
    var groupCount = 0;
    if (members.any(
      (member) =>
          FamilyGeneration.fromRelation(member.relation) ==
          FamilyGeneration.grandparents,
    )) {
      groupCount++;
    }
    if (members.any((member) {
      final relation = member.relation.toLowerCase().trim();
      return relation == 'father' || relation == 'mother';
    })) {
      groupCount++;
    }
    if (members.any((member) {
      final relation = member.relation.toLowerCase().trim();
      return _isCurrentUserMember(member) ||
          relation == 'spouse' ||
          relation == 'wife' ||
          relation == 'husband' ||
          relation == 'brother' ||
          relation == 'sister';
    })) {
      groupCount++;
    }
    if (members.any(
      (member) =>
          !_isCurrentUserMember(member) &&
          FamilyGeneration.fromRelation(member.relation) ==
              FamilyGeneration.children,
    )) {
      groupCount++;
    }
    if (members.any(
      (member) =>
          FamilyGeneration.fromRelation(member.relation) ==
          FamilyGeneration.other,
    )) {
      groupCount++;
    }
    return math.max(1, groupCount) * 132 + 12;
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
          color: isSelected ? context.appSurface : Colors.transparent,
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
              color: isSelected ? AppColors.primary : context.appTextSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? AppColors.primary
                    : context.appTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Root Node: Family Trunk ──────────────────────────────────────────
  Widget _buildRootFamilyNode(String familyTitle, int count) {
    return Container(
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
        ],
      ),
    );
  }

  // ── Mode 1: Direct Relational Tree (Tree branch lines to each member) ─
  List<Widget> _buildDirectTreeMembers(List<MemberModel> members) {
    // Keep the direct mode explicit as separate generation branches. A single
    // continuous trunk makes children look attached to the wrong adult.
    return _buildGenerationalTreeBranches(members);
  }

  bool _isCurrentUserMember(MemberModel member) {
    final normalizedUserName = widget.currentUserName?.trim().toLowerCase();
    return member.relation.toLowerCase().trim() == 'self' ||
        (normalizedUserName != null &&
            normalizedUserName.isNotEmpty &&
            member.name.trim().toLowerCase() == normalizedUserName);
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
    final parents = members.where((member) {
      final relation = member.relation.toLowerCase().trim();
      return relation == 'father' || relation == 'mother';
    }).toList();
    final ownerMembers = members.where(_isCurrentUserMember).toList();
    final spouseMembers = members.where((member) {
      final relation = member.relation.toLowerCase().trim();
      return relation == 'spouse' ||
          relation == 'wife' ||
          relation == 'husband';
    }).toList();
    final siblingMembers = members.where((member) {
      final relation = member.relation.toLowerCase().trim();
      return relation == 'brother' || relation == 'sister';
    }).toList();
    final coreMembers = [...ownerMembers, ...spouseMembers, ...siblingMembers];
    final children = members
        .where(
          (m) =>
              !_isCurrentUserMember(m) &&
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

    final sections = <Widget>[];
    if (grandparents.isNotEmpty) {
      sections.add(
        _buildGenerationSection(
          generation: FamilyGeneration.grandparents,
          members: grandparents,
          branchId: 'gen-1',
        ),
      );
    }
    if (parents.isNotEmpty) {
      sections.add(
        _buildGenerationSection(
          generation: FamilyGeneration.parents,
          members: parents,
          branchId: 'gen-2',
          title: '2nd Gen • Parents',
        ),
      );
    }
    if (coreMembers.isNotEmpty) {
      sections.add(
        _buildGenerationSection(
          generation: FamilyGeneration.parents,
          members: coreMembers,
          branchId: 'gen-core',
          title: 'You, Spouse & Siblings',
          connectCoupleCount: math.min(
            2,
            ownerMembers.length + spouseMembers.length,
          ),
        ),
      );
    }
    if (children.isNotEmpty) {
      MemberModel? owner;
      for (final member in members) {
        if (_isCurrentUserMember(member)) {
          owner = member;
          break;
        }
      }
      sections.add(
        _buildGenerationSection(
          generation: FamilyGeneration.children,
          members: children,
          branchId: 'gen-3',
          title: owner == null
              ? '3rd Gen • Children'
              : 'Children of ${owner.name}',
          compact: true,
          topPadding: 0,
        ),
      );
    }
    if (others.isNotEmpty) {
      sections.add(
        _buildGenerationSection(
          generation: FamilyGeneration.other,
          members: others,
          branchId: 'gen-4',
        ),
      );
    }
    return sections;
  }

  Widget _buildGenerationSection({
    required FamilyGeneration generation,
    required List<MemberModel> members,
    required String branchId,
    String? title,
    bool compact = false,
    int connectCoupleCount = 0,
    double topPadding = 18,
  }) {
    final isExpanded = !(_collapsedBranches?.contains(branchId) ?? false);
    return Padding(
      padding: EdgeInsets.only(top: topPadding),
      child: Column(
        children: [
          GestureDetector(
            onTap: () => _toggleBranch(branchId),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 310),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: generation.bgColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    generation == FamilyGeneration.children
                        ? Icons.family_restroom_rounded
                        : Icons.hub_rounded,
                    size: 16,
                    color: generation.color,
                  ),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      title ?? generation.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: generation.color,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${members.length}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: generation.color,
                    ),
                  ),
                  const SizedBox(width: 2),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 17,
                      color: generation.color,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            child: !isExpanded
                ? const SizedBox.shrink()
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final cardWidth = compact ? 176.0 : 214.0;
                      const spacing = 14.0;
                      final contentWidth = math.max(
                        constraints.maxWidth,
                        members.length * cardWidth +
                            math.max(0, members.length - 1) * spacing,
                      );
                      final cardsWidth =
                          members.length * cardWidth +
                          math.max(0, members.length - 1) * spacing;
                      final firstCenter =
                          (contentWidth - cardsWidth) / 2 + cardWidth / 2;
                      return SizedBox(
                        width: contentWidth,
                        child: Column(
                          children: [
                            CustomPaint(
                              painter: GenerationConnectorPainter(
                                memberCount: members.length,
                                cardWidth: cardWidth,
                                spacing: spacing,
                                color: generation.color,
                              ),
                              size: Size(contentWidth, 28),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (
                                  var index = 0;
                                  index < members.length;
                                  index++
                                ) ...[
                                  SizedBox(
                                    width: cardWidth,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _buildMemberCard(
                                          members[index],
                                          compact: compact,
                                        ),
                                        _buildDoctorAvatars(members[index]),
                                      ],
                                    ),
                                  ),
                                  if (index != members.length - 1)
                                    const SizedBox(width: spacing),
                                ],
                              ],
                            ),
                            if (connectCoupleCount > 0)
                              CustomPaint(
                                painter: CoupleContinuationPainter(
                                  ownerX: firstCenter,
                                  spouseX: connectCoupleCount > 1
                                      ? firstCenter + cardWidth + spacing
                                      : null,
                                  targetX: contentWidth / 2,
                                  color: generation.color,
                                ),
                                size: Size(contentWidth, 18),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ── Modern Member Node Card ──────────────────────────────────────────
  Widget _buildDoctorAvatars(MemberModel member) {
    final doctors = widget.memberDoctors[member.id] ?? const <DoctorModel>[];
    if (doctors.isEmpty) return const SizedBox.shrink();
    final visibleDoctors = doctors.take(6).toList();
    const avatarSize = 22.0;
    const avatarSpacing = 3.0;
    final connectorWidth =
        visibleDoctors.length * avatarSize +
        math.max(0, visibleDoctors.length - 1) * avatarSpacing;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          painter: DoctorConnectorPainter(
            doctorCount: visibleDoctors.length,
            avatarSize: avatarSize,
            spacing: avatarSpacing,
            color: AppColors.primary,
          ),
          size: Size(connectorWidth, 10),
        ),
        Transform.translate(
          offset: const Offset(0, -1),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: List.generate(visibleDoctors.length, (index) {
              final doctor = visibleDoctors[index];
              return Padding(
                padding: EdgeInsets.only(
                  right: index == visibleDoctors.length - 1 ? 0 : avatarSpacing,
                ),
                child: AppAvatar(
                  memberId: doctor.id,
                  name: doctor.name,
                  avatarUrl: doctor.avatarUrl,
                  size: avatarSize,
                  fontSize: 7,
                  backgroundColor: const Color(0xFFEAF8EE),
                  textColor: AppColors.primary,
                  border: Border.all(color: AppColors.primary, width: 1.3),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.shadow,
                      blurRadius: 3,
                      offset: Offset(0, 1),
                    ),
                  ],
                  onTap: () => context.push('/doctors/${doctor.id}'),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildMemberCard(MemberModel member, {bool compact = false}) {
    final relation = member.relation;
    final isSelf = _isCurrentUserMember(member);
    final normalizedRelation = relation.toLowerCase().trim();
    final isSpouse =
        normalizedRelation == 'spouse' ||
        normalizedRelation == 'wife' ||
        normalizedRelation == 'husband';
    final isSibling =
        normalizedRelation == 'brother' || normalizedRelation == 'sister';
    final outlineColor = isSelf
        ? AppColors.primary
        : isSpouse
        ? const Color(0xFFE11D48)
        : isSibling
        ? const Color(0xFF7C3AED)
        : context.appBorder;
    final displayRelation = isSelf ? 'You' : relation;
    final relIcon = getRelationIcon(isSelf ? 'self' : relation);
    final badgeColor = getRelationBadgeColor(isSelf ? 'self' : relation);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => widget.onMemberTap?.call(member),
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 14,
            vertical: compact ? 5 : 10,
          ),
          decoration: BoxDecoration(
            color: isSelf
                ? (context.isDarkMode
                      ? const Color(0xFF183421)
                      : const Color(0xFFF0FDF4))
                : context.appSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: outlineColor,
              width: isSelf || isSpouse || isSibling ? 1.6 : 1.1,
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
                    size: compact ? 28 : 40,
                    border: Border.all(
                      color: isSelf || isSpouse || isSibling
                          ? outlineColor
                          : badgeColor,
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

              // Name and relationship only
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      style: TextStyle(
                        fontSize: compact ? 12.5 : 14,
                        fontWeight: FontWeight.w700,
                        color: context.appTextPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: badgeColor.withAlpha(20),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(relIcon, size: 9, color: badgeColor),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              displayRelation,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: badgeColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Arrow indicator
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 13,
                color: context.appTextSecondary,
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
          Text(
            'Family Tree is Empty',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Add your family members (Grandparents, Parents, Self, Children) to build your tree.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: context.appTextSecondary),
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
              color: depth == 0 ? AppColors.primary : context.appSurface,
              borderRadius: BorderRadius.circular(12),
              border: depth > 0 ? Border.all(color: context.appBorder) : null,
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
                    color: depth == 0 ? Colors.white : context.appTextPrimary,
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

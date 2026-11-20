import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../config/theme.dart';
import '../models/member_model.dart';
import 'app_avatar.dart';

class FamilyGroupedListView extends StatefulWidget {
  final List<MemberModel> members;
  final void Function(MemberModel member)? onMemberTap;
  final VoidCallback? onAddMember;

  const FamilyGroupedListView({
    super.key,
    required this.members,
    this.onMemberTap,
    this.onAddMember,
  });

  @override
  State<FamilyGroupedListView> createState() => _FamilyGroupedListViewState();
}

class _FamilyGroupedListViewState extends State<FamilyGroupedListView> {
  final Map<String, bool> _expanded = {
    'grandparents': true,
    'parents': true,
    'youAndSpouse': true,
    'siblings': true,
    'children': true,
    'others': true,
  };

  void _toggle(String key) {
    setState(() {
      _expanded[key] = !(_expanded[key] ?? true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.members.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.family_restroom_rounded,
                  size: 36,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No family members yet',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF172B21),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Add your family members to track their health history.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppColors.textMid),
              ),
              if (widget.onAddMember != null) ...[
                const SizedBox(height: 18),
                ElevatedButton.icon(
                  onPressed: widget.onAddMember,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.person_add_rounded, size: 18),
                  label: const Text('Add Member'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final grandparents = <MemberModel>[];
    final parents = <MemberModel>[];
    final youAndSpouse = <MemberModel>[];
    final siblings = <MemberModel>[];
    final children = <MemberModel>[];
    final others = <MemberModel>[];

    for (final m in widget.members) {
      final rel = m.relation.toLowerCase().trim();
      if (rel.contains('grandfather') ||
          rel.contains('grandmother') ||
          rel.contains('grandpa') ||
          rel.contains('grandma') ||
          rel.contains('dada') ||
          rel.contains('dadi') ||
          rel.contains('nana') ||
          rel.contains('nani')) {
        grandparents.add(m);
      } else if (rel == 'self' ||
          rel == 'me' ||
          rel == 'myself' ||
          rel == 'you' ||
          rel.contains('spouse') ||
          rel.contains('wife') ||
          rel.contains('husband') ||
          rel.contains('partner') ||
          rel.contains('shohar') ||
          rel.contains('biwi') ||
          rel.contains('begum')) {
        youAndSpouse.add(m);
      } else if (rel.contains('father') ||
          rel.contains('mother') ||
          rel.contains('dad') ||
          rel.contains('mom') ||
          rel.contains('walid') ||
          rel.contains('walida') ||
          rel.contains('abu') ||
          rel.contains('abbu') ||
          rel.contains('ammi') ||
          rel.contains('ami')) {
        parents.add(m);
      } else if (rel.contains('brother') ||
          rel.contains('sister') ||
          rel.contains('sibling') ||
          rel.contains('bhai') ||
          rel.contains('behan') ||
          rel.contains('baji')) {
        siblings.add(m);
      } else if (rel.contains('son') ||
          rel.contains('daughter') ||
          rel.contains('child') ||
          rel.contains('kid') ||
          rel.contains('beta') ||
          rel.contains('beti') ||
          rel.contains('bacha') ||
          rel.contains('bachi')) {
        children.add(m);
      } else {
        others.add(m);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (grandparents.isNotEmpty) ...[
          _buildSection(
            key: 'grandparents',
            title: 'Grandparents',
            icon: Icons.groups_rounded,
            members: grandparents,
          ),
          const SizedBox(height: 12),
        ],
        if (parents.isNotEmpty) ...[
          _buildSection(
            key: 'parents',
            title: 'Parents',
            icon: Icons.family_restroom_rounded,
            members: parents,
          ),
          const SizedBox(height: 12),
        ],
        if (youAndSpouse.isNotEmpty) ...[
          _buildSection(
            key: 'youAndSpouse',
            title: 'You & Spouse',
            icon: Icons.favorite_rounded,
            members: youAndSpouse,
          ),
          const SizedBox(height: 12),
        ],
        if (siblings.isNotEmpty) ...[
          _buildSection(
            key: 'siblings',
            title: 'Brothers & Sisters',
            icon: Icons.diversity_3_rounded,
            members: siblings,
          ),
          const SizedBox(height: 12),
        ],
        if (children.isNotEmpty) ...[
          _buildSection(
            key: 'children',
            title: 'Children',
            icon: Icons.child_care_rounded,
            members: children,
          ),
          const SizedBox(height: 12),
        ],
        if (others.isNotEmpty) ...[
          _buildSection(
            key: 'others',
            title: 'Other Members',
            icon: Icons.group_add_rounded,
            members: others,
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

  Widget _buildSection({
    required String key,
    required String title,
    required IconData icon,
    required List<MemberModel> members,
  }) {
    final isExpanded = _expanded[key] ?? true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          title: title,
          icon: icon,
          count: members.length,
          isExpanded: isExpanded,
          onToggle: () => _toggle(key),
        ),
        const SizedBox(height: 6),
        AnimatedCrossFade(
          firstChild: Column(
            children: members.map((m) => _buildMemberCard(context, m)).toList(),
          ),
          secondChild: const SizedBox.shrink(),
          crossFadeState: isExpanded
              ? CrossFadeState.showFirst
              : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 220),
        ),
      ],
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required IconData icon,
    required int count,
    required bool isExpanded,
    required VoidCallback onToggle,
  }) {
    return InkWell(
      onTap: onToggle,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFE4F7E9),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(
                  color: const Color(0xFFC7F0D2),
                  width: 1.0,
                ),
              ),
              child: Icon(
                icon,
                size: 18,
                color: const Color(0xFF087A45),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: Color(0xFF172B21),
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$count',
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF087A45),
              ),
            ),
            const Spacer(),
            AnimatedRotation(
              turns: isExpanded ? 0.0 : 0.5,
              duration: const Duration(milliseconds: 200),
              child: const Icon(
                Icons.keyboard_arrow_up_rounded,
                color: Color(0xFF172B21),
                size: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberCard(BuildContext context, MemberModel member) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE2F3E8),
          width: 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0D331E),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            if (widget.onMemberTap != null) {
              widget.onMemberTap!(member);
            } else {
              context.push('/members/${member.id}');
            }
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                AppAvatar(
                  name: member.name,
                  avatarUrl: member.avatarUrl,
                  size: 48,
                  border: Border.all(
                    color: const Color(0xFF16A34A).withValues(alpha: 0.25),
                    width: 1.2,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF172B21),
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(
                            Icons.medical_services_outlined,
                            size: 13,
                            color: Color(0xFF16A34A),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            member.relation.isEmpty
                                ? 'Member'
                                : (member.relation[0].toUpperCase() +
                                    member.relation.substring(1)),
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF4A6652),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF94A3B8),
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

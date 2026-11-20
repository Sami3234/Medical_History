import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/routes.dart';
import '../../providers/family_provider.dart';
import '../../providers/member_provider.dart';
import '../../providers/visit_provider.dart';
import '../../widgets/hero_health_card.dart';
import '../../utils/extensions.dart';

class FamilyDetailScreen extends StatefulWidget {
  final String id;
  const FamilyDetailScreen({super.key, required this.id});

  @override
  State<FamilyDetailScreen> createState() => _FamilyDetailScreenState();
}

class _FamilyDetailScreenState extends State<FamilyDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MemberProvider>().loadByFamily(widget.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final famProv = context.watch<FamilyProvider>();
    final memberProv = context.watch<MemberProvider>();
    final visitProv = context.watch<VisitProvider>();

    final families = famProv.families;
    final family =
        families
            .where((f) => f.id == widget.id || f.familyId == widget.id)
            .firstOrNull ??
        (families.isNotEmpty ? families.first : null);

    if (family == null) {
      return Scaffold(
        backgroundColor: context.appBackground,
        appBar: AppBar(
          title: const Text('Family details'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: famProv.loading
              ? const CircularProgressIndicator(color: AppColors.primary)
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.family_restroom_rounded,
                      size: 54,
                      color: AppColors.textLight,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Family space not found',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: context.appTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => context.pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                      child: const Text(
                        'Go Back',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
        ),
      );
    }

    final members = memberProv.members;
    final familyMemberIds = members.map((member) => member.id).toSet();
    final familyVisitCount = visitProv.visits
        .where((visit) => familyMemberIds.contains(visit.memberId))
        .length;
    final cardColor = Theme.of(context).cardColor;
    final surfaceColor = Theme.of(context).colorScheme.surface;

    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        title: const Text('Family details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            tooltip: 'Delete family',
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.error,
            ),
            onPressed: () => _confirmDeleteFamily(context, family),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero Green Card
              HeroHealthCard(
                title: family.name,
                subtitle:
                    '${family.familyId} • ${family.address ?? "No address added"}',
                actionText: 'Edit family',
                onAction: () => _showEditDialog(context, family),
              ),
              const SizedBox(height: 20),

              // Stat Boxes: current family members and recorded visits
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border, width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.shadow,
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            members.length < 10
                                ? '0${members.length}'
                                : '${members.length}',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: context.appTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Family members',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textLight,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border, width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.shadow,
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$familyVisitCount',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: context.appTextPrimary,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Doctor visits',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textLight,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 26),

              // Section: Family members
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Family members',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: context.appTextPrimary,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => context.push(AppRoutes.memberAdd),
                    icon: const Icon(
                      Icons.add_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    label: const Text(
                      'Add',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Members List
              ...members.map((member) {
                final initials = member.name.split(' ').length >= 2
                    ? '${member.name.split(' ')[0][0]}${member.name.split(' ')[1][0]}'
                          .toUpperCase()
                    : member.name
                          .substring(0, member.name.length >= 2 ? 2 : 1)
                          .toUpperCase();

                String subtitle = member.relation;
                if (member.notes != null && member.notes!.isNotEmpty) {
                  subtitle = '$subtitle • ${member.notes}';
                } else if (member.bloodGroup != null) {
                  subtitle = '$subtitle • Blood group ${member.bloodGroup}';
                } else if (member.age != 'N/A') {
                  subtitle = '$subtitle • ${member.age}';
                }

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () => context.push('/members/${member.id}'),
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border, width: 1.2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.shadow,
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              initials,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: AppColors.primaryDark,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  member.name,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: context.appTextPrimary,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  subtitle,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textLight,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: AppColors.textLight,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, dynamic family) {
    final editCtrl = TextEditingController(text: family.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Family Name'),
        content: TextField(
          controller: editCtrl,
          decoration: const InputDecoration(hintText: 'Enter family name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (editCtrl.text.isNotEmpty) {
                context.read<FamilyProvider>().updateFamily(family.id, {
                  'name': editCtrl.text.trim(),
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteFamily(
    BuildContext context,
    dynamic family,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete family space?'),
        content: const Text(
          'All members, visits, health records and local document links in this family may be removed. Create a Google Drive backup first if you need to restore them later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete permanently'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final deleted = await context.read<FamilyProvider>().deleteFamily(
      family.id,
    );
    if (!mounted) return;
    if (deleted) {
      context.showSnack('Family deleted');
      context.pop();
    } else {
      context.showSnack('Family could not be deleted', isError: true);
    }
  }
}

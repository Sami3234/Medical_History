import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../utils/helpers.dart';

class MemberTile extends StatelessWidget {
  final String name;
  final String relation;
  final String? age;
  final String? bloodGroup;
  final VoidCallback? onTap;

  const MemberTile({
    super.key,
    required this.name,
    required this.relation,
    this.age,
    this.bloodGroup,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: context.appSurfaceSoft,
        child: Text(
          Helpers.initials(name),
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      title: Text(
        name,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: Text(
        '$relation${age != null ? ' • $age' : ''}',
        style: const TextStyle(color: AppColors.textLight, fontSize: 13),
      ),
      trailing: bloodGroup != null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: context.appSurfaceSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                bloodGroup!,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            )
          : null,
    );
  }
}

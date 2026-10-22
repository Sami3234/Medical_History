import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../utils/helpers.dart';

class VisitCard extends StatelessWidget {
  final String memberName;
  final String? doctorName;
  final DateTime visitDate;
  final String? diagnosis;
  final VoidCallback? onTap;

  const VisitCard({
    super.key,
    required this.memberName,
    this.doctorName,
    required this.visitDate,
    this.diagnosis,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: context.appSurfaceSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.medical_services_rounded,
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    memberName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    diagnosis ?? 'General Checkup',
                    style: const TextStyle(
                      color: AppColors.textLight,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  Helpers.formatDateShort(visitDate),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMid,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (doctorName != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Dr. $doctorName',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

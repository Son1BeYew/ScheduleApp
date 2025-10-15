import 'package:flutter/material.dart';
import 'package:schedule_app/theme/app_colors.dart';
import 'package:schedule_app/theme/app_spacing.dart';
import 'package:schedule_app/theme/app_typography.dart';

class TimelineCard extends StatelessWidget {
  final String time;
  final String title;
  final String? description;
  final bool isActive;
  final VoidCallback? onTap;

  const TimelineCard({
    super.key,
    required this.time,
    required this.title,
    this.description,
    this.isActive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.borderRadiusXl,
        child: Container(
          padding: AppSpacing.paddingLg + const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : AppColors.surface,
            borderRadius: AppSpacing.borderRadiusXl,
            border: Border.all(
              color: isActive ? Colors.transparent : AppColors.border,
              width: 1,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : [],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 6,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: AppSpacing.borderRadiusMd,
                  color: isActive ? null : AppColors.timelineInactive,
                  gradient: isActive ? AppColors.gradientAccent : null,
                ),
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      time,
                      style: AppTypography.timeLabel.copyWith(
                        color: isActive
                            ? AppColors.textOnPrimary.withValues(alpha: 0.8)
                            : AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      style: AppTypography.cardTitle.copyWith(
                        color: isActive
                            ? AppColors.textOnPrimary
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (description != null && description!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          description!,
                          style: AppTypography.cardSubtitle.copyWith(
                            color: isActive
                                ? AppColors.textOnPrimary.withValues(alpha: 0.8)
                                : AppColors.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

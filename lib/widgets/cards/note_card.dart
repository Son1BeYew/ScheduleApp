import 'package:flutter/material.dart';
import 'package:schedule_app/theme/app_colors.dart';
import 'package:schedule_app/theme/app_spacing.dart';
import 'package:schedule_app/theme/app_typography.dart';

class NoteCard extends StatelessWidget {
  final String title;
  final String content;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onShare;
  final Color? backgroundColor;
  final bool? hasAttachment;
  final String? groupName;

  const NoteCard({
    super.key,
    required this.title,
    required this.content,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onShare,
    this.backgroundColor,
    this.hasAttachment,
    this.groupName,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.borderRadiusXl,
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.borderRadiusXl,
        child: Container(
          decoration: BoxDecoration(
            color: backgroundColor ?? AppColors.surface,
            borderRadius: AppSpacing.borderRadiusXl,
          ),
          padding: AppSpacing.paddingLg,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: AppTypography.cardTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (hasAttachment == true)
                    Padding(
                      padding: const EdgeInsets.only(left: AppSpacing.sm),
                      child: Icon(
                        Icons.attachment,
                        size: AppSpacing.iconSm,
                        color: AppColors.textTertiary,
                      ),
                    ),
                  if (onEdit != null || onDelete != null || onShare != null)
                    PopupMenuButton<String>(
                      icon: Icon(
                        Icons.more_vert,
                        size: AppSpacing.iconSm,
                        color: AppColors.textSecondary,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppSpacing.borderRadiusMd,
                      ),
                      onSelected: (value) {
                        if (value == 'edit' && onEdit != null) {
                          onEdit!();
                        } else if (value == 'delete' && onDelete != null) {
                          onDelete!();
                        } else if (value == 'share' && onShare != null) {
                          onShare!();
                        }
                      },
                      itemBuilder: (context) => [
                        if (onEdit != null)
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit_outlined, size: AppSpacing.iconSm),
                                SizedBox(width: AppSpacing.sm),
                                Text('Sửa'),
                              ],
                            ),
                          ),
                        if (onShare != null)
                          const PopupMenuItem(
                            value: 'share',
                            child: Row(
                              children: [
                                Icon(Icons.share_outlined, size: AppSpacing.iconSm),
                                SizedBox(width: AppSpacing.sm),
                                Text('Chia sẻ'),
                              ],
                            ),
                          ),
                        if (onDelete != null)
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete_outline, size: AppSpacing.iconSm),
                                SizedBox(width: AppSpacing.sm),
                                Text('Xóa'),
                              ],
                            ),
                          ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                content,
                style: AppTypography.cardSubtitle,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              if (groupName != null) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.1),
                    borderRadius: AppSpacing.borderRadiusSm,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.group_outlined,
                        size: AppSpacing.iconXs,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        groupName!,
                        style: AppTypography.textTheme.labelSmall?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

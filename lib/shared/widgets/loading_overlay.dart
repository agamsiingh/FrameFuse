import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

/// Full-screen loading overlay with progress indication.
class LoadingOverlay extends StatelessWidget {
  final String? message;
  final double? progress;
  final bool show;

  const LoadingOverlay({
    super.key,
    this.message,
    this.progress,
    this.show = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!show) return const SizedBox.shrink();

    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (progress != null) ...[
              SizedBox(
                width: 80,
                height: 80,
                child: CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 4,
                  color: AppColors.primary,
                  backgroundColor: AppColors.surfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${(progress! * 100).toInt()}%',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                    ),
              ),
            ] else
              const CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 3,
              ),
            if (message != null) ...[
              const SizedBox(height: 20),
              Text(
                message!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

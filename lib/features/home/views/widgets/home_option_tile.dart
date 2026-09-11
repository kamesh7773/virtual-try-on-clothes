import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_colors.dart';

/// One of the home screen's two choices.
class HomeOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const HomeOptionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.stageSurface,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 20.h),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.stageBorder),
          ),
          child: Row(
            children: [
              Icon(icon, size: 22.sp, color: AppColors.onStageSecondary),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: AppColors.onStagePrimary,
                        letterSpacing: 1.8,
                      ),
                    ),
                    SizedBox(height: 5.h),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: AppColors.onStageMuted,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 12.sp,
                color: AppColors.onStageFaint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

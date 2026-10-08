import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:yoopn/core/themes/app_colors.dart';

class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Divider(color: AppColors.border, thickness: 1)),
        RPadding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(
            "or continue with",
            style: Theme.of(context).textTheme.bodySmall!
                .copyWith(color: AppColors.textHint),
          ),
        ),
        Expanded(child: Divider(color: AppColors.border, thickness: 1)),
      ],
    );
  }
}

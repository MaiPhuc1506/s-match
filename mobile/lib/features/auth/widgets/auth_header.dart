import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 332,
    width: double.infinity,
    child: Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 340,
          child: Image.asset(
            'assets/images/auth_login_header.png',
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: 340,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: AppColors.headerScrimGradient,
              ),
            ),
          ),
        ),
        Positioned(
          left: 32,
          top: 52,
          child: Column(
            children: [
              SizedBox.square(
                dimension: 73.539,
                child: Center(
                  child: SvgPicture.asset(
                    'assets/icons/auth_brand_shuttle.svg',
                    width: 69.862,
                    height: 69.862,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text('S-Match', style: AppTextStyles.brandTitle),
            ],
          ),
        ),
        Positioned(
          left: 32,
          top: 166,
          child: Text('Play More\nBetter More', style: AppTextStyles.tagline),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 248,
          height: 569.973,
          child: SvgPicture.asset(
            'assets/icons/auth_header_curve.svg',
            fit: BoxFit.fill,
          ),
        ),
      ],
    ),
  );
}

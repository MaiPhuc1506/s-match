import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class CustomTextField extends StatefulWidget {
  final TextEditingController controller;
  final String hintText;
  final IconData prefixIcon;
  final bool isPassword;
  final double height;
  final Widget? leading;
  final Widget? visibilityIcon;
  final TextInputType keyboardType;

  const CustomTextField({
    super.key,
    required this.controller,
    required this.hintText,
    required this.prefixIcon,
    this.isPassword = false,
    this.height = 52,
    this.leading,
    this.visibilityIcon,
    this.keyboardType = TextInputType.text,
  });

  @override
  State<CustomTextField> createState() => _CustomTextFieldState();
}

class _CustomTextFieldState extends State<CustomTextField> {
  // Biến quản lý trạng thái ẩn/hiện mật khẩu
  late bool _obscureText;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.isPassword;
  }

  @override
  Widget build(BuildContext context) {
    // Chiều cao chuẩn 52px theo Figma
    return SizedBox(
      height: widget.height,
      child: TextField(
        controller: widget.controller,
        obscureText: _obscureText,
        keyboardType: widget.keyboardType,
        style: AppTextStyles.inputText,
        cursorColor: AppColors.primary,
        decoration: InputDecoration(
          constraints: BoxConstraints(minHeight: widget.height),
          filled: true,
          fillColor: AppColors.white,
          hintText: widget.hintText,
          hintStyle: AppTextStyles.inputPlaceholder,
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: widget.height == 56 ? 18 : 14,
          ),

          // Icon tiền tố (Email / Lock)
          prefixIconConstraints: widget.leading == null
              ? null
              : BoxConstraints.tightFor(width: 48, height: widget.height),
          prefixIcon: widget.leading == null
              ? Icon(widget.prefixIcon, color: AppColors.iconPrimary, size: 20)
              : Center(child: widget.leading),

          // Nút con mắt bật/tắt mật khẩu (chỉ hiện khi là ô Password)
          suffixIcon: widget.isPassword
              ? IconButton(
                  icon:
                      widget.visibilityIcon ??
                      Icon(
                        _obscureText
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: AppColors.iconPrimary,
                        size: 20,
                      ),
                  onPressed: () {
                    setState(() {
                      _obscureText = !_obscureText;
                    });
                  },
                )
              : null,

          // Viền ở trạng thái bình thường (xám #D6DCD8, bo góc 14px)
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.border, width: 1),
          ),

          // Viền khi được bấm vào (xanh #087A61 theo prototype Figma)
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: AppColors.inputFocusedBorder,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

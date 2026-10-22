import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/core/theme/app_colors.dart';

import '../services/facility_service.dart';
import '../widgets/facility_card.dart';

class AddEditFacilityScreen extends StatefulWidget {
  final FacilityCardItem? facility;

  const AddEditFacilityScreen({super.key, this.facility});

  @override
  State<AddEditFacilityScreen> createState() => _AddEditFacilityScreenState();
}

class _AddEditFacilityScreenState extends State<AddEditFacilityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _descriptionController = TextEditingController();

  bool _isLoading = false;

  bool get _isEditing => widget.facility != null;

  @override
  void initState() {
    super.initState();
    final f = widget.facility;
    if (f != null) {
      _nameController.text = f.name;
      _addressController.text = f.address;
      _phoneController.text = f.contactPhone ?? '';
      _descriptionController.text = f.description ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final address = _addressController.text.trim();
    final phone = _phoneController.text.trim();
    final description = _descriptionController.text.trim();

    setState(() => _isLoading = true);

    if (_isEditing) {
      final success = await FacilityService.instance.updateFacility(
        facilityId: widget.facility!.id,
        name: name,
        address: address,
        contactPhone: phone.isNotEmpty ? phone : null,
        description: description.isNotEmpty ? description : null,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cập nhật cơ sở thành công!'),
            backgroundColor: AppColors.primary,
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cập nhật thất bại. Vui lòng kiểm tra lại.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      final newFacility = await FacilityService.instance.createFacility(
        name: name,
        address: address,
        contactPhone: phone.isNotEmpty ? phone : null,
        description: description.isNotEmpty ? description : null,
      );

      if (!mounted) return;

      if (newFacility != null) {
        final facilityId = newFacility['id'] as int;
        // Tự động khởi tạo khung giờ mở cửa mặc định cả tuần (06:00 - 22:00)
        await FacilityService.instance.updateOperatingHours(
          facilityId: facilityId,
          days: List.generate(
            7,
            (d) => {
              'dayOfWeek': d,
              'openTime': '06:00',
              'closeTime': '22:00',
            },
          ),
        );

        if (!mounted) return;
        setState(() => _isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tạo cơ sở mới thành công!'),
            backgroundColor: AppColors.primary,
          ),
        );
        Navigator.of(context).pop(true);
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tạo cơ sở thất bại. Vui lòng thử lại.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa cơ sở?'),
        content: Text(
          'Bạn có chắc chắn muốn xóa "${widget.facility!.name}"? Toàn bộ sân con và khung giờ thuộc cơ sở này cũng sẽ bị xóa.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Xóa', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);
    final result = await FacilityService.instance.deleteFacility(
      widget.facility!.id,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã xóa cơ sở thành công!'),
          backgroundColor: AppColors.primary,
        ),
      );
      Navigator.of(context).pop('deleted');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.message ?? 'Không thể xóa cơ sở. Vui lòng thử lại sau.',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: AppColors.textPrimary,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _isEditing ? 'Chỉnh sửa cơ sở' : 'Thêm cơ sở mới',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Tên cơ sở
              _buildLabel('Tên cơ sở / Cụm sân *'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _nameController,
                hintText: 'Ví dụ: Sân Cầu Lông Sky Badminton',
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Vui lòng nhập tên cơ sở';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // 2. Địa chỉ
              _buildLabel('Địa chỉ cụ thể *'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _addressController,
                hintText: 'Ví dụ: 123 Nguyễn Văn Linh, Hải Châu, Đà Nẵng',
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Vui lòng nhập địa chỉ cơ sở';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // 3. Số điện thoại liên hệ
              _buildLabel('Số điện thoại liên hệ'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _phoneController,
                hintText: 'Ví dụ: 0901234567',
                keyboardType: TextInputType.phone,
              ),

              const SizedBox(height: 16),

              // 4. Mô tả cơ sở
              _buildLabel('Mô tả cơ sở'),
              const SizedBox(height: 8),
              _buildTextField(
                controller: _descriptionController,
                hintText: 'Cụm sân tiêu chuẩn thảm thi đấu Yonex, đèn LED chống lóa...',
                maxLines: 3,
              ),

              const SizedBox(height: 32),

              // Nút xóa cơ sở nếu đang ở chế độ chỉnh sửa
              if (_isEditing) ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : _handleDelete,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.delete_outline, size: 20),
                    label: const Text(
                      'Xóa cơ sở này',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleSave,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      _isEditing ? 'Lưu thay đổi' : 'Tạo cơ sở mới',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.white,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.textDark,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: GoogleFonts.plusJakartaSans(fontSize: 14),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: GoogleFonts.plusJakartaSans(
          fontSize: 13,
          color: AppColors.textSecondary,
        ),
        filled: true,
        fillColor: AppColors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}


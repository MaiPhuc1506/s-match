import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/core/theme/app_colors.dart';

import '../services/facility_service.dart';

class AddEditCourtScreen extends StatefulWidget {
  final int facilityId;
  final int? courtId;

  const AddEditCourtScreen({super.key, required this.facilityId, this.courtId});

  @override
  State<AddEditCourtScreen> createState() => _AddEditCourtScreenState();
}

class _AddEditCourtScreenState extends State<AddEditCourtScreen> {
  final _nameController = TextEditingController();

  String _courtType = 'Indoor'; // 'Indoor' hoặc 'Outdoor'
  String _status = 'ACTIVE'; // 'ACTIVE', 'MAINTENANCE', 'INACTIVE'
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.courtId != null;

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
          isEditing ? 'Edit Court' : 'Add Court',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),

                // 1. Court Name
                _buildLabel('Court Name'),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _nameController,
                  hintText: 'e.g. Sân 1 (VIP)',
                ),

                const SizedBox(height: 16),

                // 2. Court Type (Indoor / Outdoor)
                _buildLabel('Court Type'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildTypeOption(
                        title: 'Indoor',
                        icon: Icons.roofing,
                        isSelected: _courtType == 'Indoor',
                        onTap: () => setState(() => _courtType = 'Indoor'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildTypeOption(
                        title: 'Outdoor',
                        icon: Icons.wb_sunny_outlined,
                        isSelected: _courtType == 'Outdoor',
                        onTap: () => setState(() => _courtType = 'Outdoor'),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // 3. Status Dropdown
                _buildLabel('Status'),
                const SizedBox(height: 8),
                Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _status,
                      isExpanded: true,
                      icon: const Icon(
                        Icons.keyboard_arrow_down,
                        color: AppColors.textSecondary,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'ACTIVE',
                          child: Text('Active (Sẵn sàng phục vụ)'),
                        ),
                        DropdownMenuItem(
                          value: 'MAINTENANCE',
                          child: Text('Maintenance (Bảo trì)'),
                        ),
                        DropdownMenuItem(
                          value: 'INACTIVE',
                          child: Text('Inactive (Tạm ngừng)'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _status = val);
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 120), // Khoảng trống cho nút Save Court
              ],
            ),
          ),

          // Nút Save Court cố định ở đáy
          Positioned(
            left: 24,
            right: 24,
            bottom: 24,
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : () async {
                        final name = _nameController.text.trim();
                        if (name.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Vui lòng nhập tên sân'),
                            ),
                          );
                          return;
                        }

                        setState(() => _isLoading = true);
                        final success = await FacilityService.instance.addCourt(
                          facilityId: widget.facilityId,
                          name: name,
                          courtType: _courtType,
                          status: _status,
                        );

                        if (!context.mounted) return;
                        setState(() => _isLoading = false);

                        if (success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Thêm sân thành công!'),
                            ),
                          );
                          Navigator.of(context).pop(true);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Lưu thông tin thất bại. Vui lòng thử lại!',
                              ),
                            ),
                          );
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          color: AppColors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : Text(
                        'Save Court',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.white,
                        ),
                      ),
              ),
            ),
          ),
        ],
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
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      alignment: Alignment.centerLeft,
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: GoogleFonts.plusJakartaSans(fontSize: 14),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            color: AppColors.textSecondary,
          ),
          border: InputBorder.none,
          isDense: true,
        ),
      ),
    );
  }

  Widget _buildTypeOption({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.mintSurface : AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/core/theme/app_colors.dart';

import '../services/facility_service.dart';

class AddEditCourtScreen extends StatefulWidget {
  final int facilityId;
  final int? courtId;
  final Map<String, dynamic>? court;

  const AddEditCourtScreen({
    super.key,
    required this.facilityId,
    this.courtId,
    this.court,
  });

  @override
  State<AddEditCourtScreen> createState() => _AddEditCourtScreenState();
}

class _AddEditCourtScreenState extends State<AddEditCourtScreen> {
  final _nameController = TextEditingController();
  final _numberController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _courtType = 'Indoor'; // 'Indoor' hoặc 'Outdoor'
  String _status = 'ACTIVE'; // 'ACTIVE', 'MAINTENANCE', 'INACTIVE'
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final court = widget.court;
    if (court != null) {
      _nameController.text = court['name'] as String? ?? '';
      _courtType = (court['courtType'] as String? ?? 'INDOOR') == 'OUTDOOR'
          ? 'Outdoor'
          : 'Indoor';
      _status = court['status'] as String? ?? 'ACTIVE';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _numberController.dispose();
    _descriptionController.dispose();
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
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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

                _buildLabel('Court Number'),
                const SizedBox(height: 8),
                _buildTextField(
                  controller: _numberController,
                  hintText: '01',
                  keyboardType: TextInputType.number,
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
                          child: Text('Available'),
                        ),
                        DropdownMenuItem(
                          value: 'MAINTENANCE',
                          child: Text('Maintenance'),
                        ),
                        DropdownMenuItem(
                          value: 'INACTIVE',
                          child: Text('Unavailable'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _status = val);
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 16),
                _buildLabel('Description (Optional)'),
                const SizedBox(height: 8),
                TextField(
                  controller: _descriptionController,
                  minLines: 3,
                  maxLines: 4,
                  maxLength: 200,
                  style: GoogleFonts.plusJakartaSans(fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Add a description for this court…\n(e.g. court condition, special notes…)',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Opacity(
                    opacity: .18,
                    child: SvgPicture.asset(
                      'assets/icons/sprint3_shuttle.svg',
                      width: 112,
                      height: 112,
                    ),
                  ),
                ),
                const SizedBox(height: 100),
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
                        final success = isEditing
                            ? await FacilityService.instance.updateCourt(
                                facilityId: widget.facilityId,
                                courtId: widget.courtId!,
                                name: name,
                                courtType: _courtType,
                                status: _status,
                              )
                            : await FacilityService.instance.addCourt(
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
                              content: Text(
                                'Court saved. Court number and description are UI-only until supported by the API.',
                              ),
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
                        isEditing ? 'Save Changes' : 'Save Court',
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
        inputFormatters: keyboardType == TextInputType.number
            ? [FilteringTextInputFormatter.digitsOnly]
            : null,
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
            SvgPicture.asset(
              title == 'Indoor'
                  ? 'assets/icons/sprint3_indoor.svg'
                  : 'assets/icons/sprint3_outdoor.svg',
              width: 24,
              height: 24,
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

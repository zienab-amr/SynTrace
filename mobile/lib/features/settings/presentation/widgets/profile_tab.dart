import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:syntrace/core/models/user_model.dart';
import 'package:syntrace/core/services/current_user_service.dart';
import 'package:syntrace/core/services/secure_storage_service.dart';
import 'package:syntrace/core/theme/app_colors.dart';

class ProfileTab extends StatefulWidget {
  const ProfileTab({super.key});

  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _companyController = TextEditingController();

  bool _isEditing = false;
  bool _isSaving = false;
  bool _isAdmin = false;
  String _role = 'Admin';
  Uint8List? _avatarBytes;
  List<String> _permissions = const [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final user = CurrentUserService.instance.user;
    if (user == null) return;

    final storedName = await SecureStorageService.instance.getUserName();
    final storedCompany =
        await SecureStorageService.instance.getCompanyName();
    final storedAvatar = await SecureStorageService.instance.getAvatarBytes();

    if (!mounted) return;

    setState(() {
      _nameController.text = storedName ?? user.name;
      _emailController.text = user.email;
      _companyController.text =
          storedCompany ?? user.companyName ?? 'My Organization';
      _role = _capitalize(user.role.value);
      _isAdmin = user.role == UserRole.admin;
      _avatarBytes = storedAvatar;
      _permissions = const [
        'Projects',
        'Reports',
        'Knowledge Graph',
        'AI Assistant',
        'Security Center',
      ];
    });
  }

  Future<void> _onSave() async {
    setState(() => _isSaving = true);

    await SecureStorageService.instance.saveUserName(_nameController.text);
    await SecureStorageService.instance
        .saveCompanyName(_companyController.text);

    final user = CurrentUserService.instance.user;
    if (user != null) {
      CurrentUserService.instance.setUser(
        user.copyWith(
          name: _nameController.text,
          email: _emailController.text,
          companyName: _companyController.text,
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _isEditing = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 12),
            Text('Profile updated successfully'),
          ],
        ),
        backgroundColor: AppColors.secondary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _onCancel() {
    _loadData();
    setState(() => _isEditing = false);
  }

  Future<void> _pickAvatar() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 400,
      );

      if (picked == null) return;

      final bytes = await picked.readAsBytes();

      await SecureStorageService.instance.saveAvatarBytes(bytes);

      if (!mounted) return;
      setState(() => _avatarBytes = bytes);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('Avatar updated'),
            ],
          ),
          backgroundColor: AppColors.secondary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick image: $e'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _removeAvatar() async {
    await SecureStorageService.instance.deleteAvatarBytes();
    if (!mounted) return;
    setState(() => _avatarBytes = null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildProfileCard(theme),
        const SizedBox(height: 20),
        _buildPermissionsCard(theme),
        const SizedBox(height: 24),
        _buildActions(),
      ],
    );
  }

  Widget _buildProfileCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PROFILE',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 24),
          _buildAvatarRow(theme),
          const SizedBox(height: 28),
          _buildFieldsRow1(theme),
          const SizedBox(height: 16),
          _buildFieldsRow2(theme),
        ],
      ),
    );
  }

  Widget _buildAvatarRow(ThemeData theme) {
    return Row(
      children: [
        _buildAvatar(theme),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _nameController.text.isEmpty
                    ? 'User'
                    : _nameController.text,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$_role · ${_companyController.text}',
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        if (_isEditing) ...[
          TextButton.icon(
            onPressed: _pickAvatar,
            icon: const Icon(Icons.photo_camera_outlined, size: 18),
            label: const Text('Change Avatar'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
            ),
          ),
          if (_avatarBytes != null)
            IconButton(
              onPressed: _removeAvatar,
              icon: const Icon(Icons.delete_outline, size: 18),
              color: AppColors.error,
              tooltip: 'Remove avatar',
            ),
        ],
      ],
    );
  }

  Widget _buildAvatar(ThemeData theme) {
    return GestureDetector(
      onTap: _isEditing ? _pickAvatar : null,
      child: Stack(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary,
              image: _avatarBytes != null
                  ? DecorationImage(
                      image: MemoryImage(_avatarBytes!),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: _avatarBytes != null
                ? null
                : Center(
                    child: Text(
                      _initials(_nameController.text),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
          ),
          if (_isEditing)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                  border: Border.all(
                    color: theme.colorScheme.surface,
                    width: 2,
                  ),
                ),
                child: const Icon(
                  Icons.edit,
                  color: Colors.white,
                  size: 12,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFieldsRow1(ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildField(
            theme: theme,
            label: 'Full Name',
            controller: _nameController,
            enabled: _isEditing,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildField(
            theme: theme,
            label: 'Email Address',
            controller: _emailController,
            enabled: _isEditing && _isAdmin,
          ),
        ),
      ],
    );
  }

  Widget _buildFieldsRow2(ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildField(
            theme: theme,
            label: 'Role',
            controller: TextEditingController(text: _role),
            enabled: false,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildField(
            theme: theme,
            label: 'Organization',
            controller: _companyController,
            enabled: _isEditing && _isAdmin,
          ),
        ),
      ],
    );
  }

  Widget _buildField({
    required ThemeData theme,
    required String label,
    required TextEditingController controller,
    required bool enabled,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: theme.colorScheme.onSurface.withOpacity(0.5),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          enabled: enabled,
          onChanged: (_) => setState(() {}),
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontSize: 14,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: enabled
                ? theme.colorScheme.surface
                : theme.scaffoldBackgroundColor.withOpacity(0.3),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: theme.dividerColor.withOpacity(0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: theme.dividerColor.withOpacity(0.3),
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: theme.dividerColor.withOpacity(0.15),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPermissionsCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ROLE & PERMISSIONS',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip(theme, _role, filled: true),
              ..._permissions.map<Widget>((p) => _chip(theme, p)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(ThemeData theme, String label, {bool filled = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: filled
            ? AppColors.primary.withOpacity(0.15)
            : theme.scaffoldBackgroundColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: filled
              ? AppColors.primary.withOpacity(0.4)
              : theme.dividerColor.withOpacity(0.3),
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: filled
              ? AppColors.primary
              : theme.colorScheme.onSurface.withOpacity(0.75),
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildActions() {
    if (!_isEditing) {
      return Align(
        alignment: Alignment.centerLeft,
        child: ElevatedButton(
          onPressed: () => setState(() => _isEditing = true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: 32,
              vertical: 16,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text(
            'Edit Profile',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    return Row(
      children: [
        ElevatedButton(
          onPressed: _isSaving ? null : _onSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: 32,
              vertical: 16,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text(
                  'Save Changes',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
        ),
        const SizedBox(width: 12),
        OutlinedButton(
          onPressed: _isSaving ? null : _onCancel,
          style: OutlinedButton.styleFrom(
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            padding: const EdgeInsets.symmetric(
              horizontal: 32,
              vertical: 16,
            ),
            side: BorderSide(
              color: Theme.of(context).dividerColor.withOpacity(0.3),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: const Text('Cancel', style: TextStyle(fontSize: 13)),
        ),
      ],
    );
  }

  String _initials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return (parts[0][0] + parts[parts.length - 1][0]).toUpperCase();
  }

  String _capitalize(String value) {
    if (value.isEmpty) return value;
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }
}
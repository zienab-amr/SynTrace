import 'package:flutter/material.dart';
import 'package:syntrace/core/theme/app_colors.dart';

class TeamSetupStep extends StatefulWidget {
  final List<Map<String, String>> teamMembers;
  final void Function(Map<String, String> member) onAdd;
  final void Function(String email) onRemove;

  const TeamSetupStep({
    super.key,
    required this.teamMembers,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  State<TeamSetupStep> createState() => _TeamSetupStepState();
}

class _TeamSetupStepState extends State<TeamSetupStep> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedRole = 'Developer';

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _addMember() {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (firstName.isEmpty ||
        email.isEmpty ||
        !email.contains('@') ||
        password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please fill all required fields correctly. Password min 6 chars.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    widget.onAdd({
      'firstName': firstName,
      'lastName': lastName.isEmpty ? '.' : lastName,
      'phoneNumber': phone.isEmpty ? '0000000000' : phone,
      'email': email,
      'password': password,
      'role': _selectedRole,
    });

    _firstNameController.clear();
    _lastNameController.clear();
    _phoneController.clear();
    _emailController.clear();
    _passwordController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add team members',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create accounts for your team. You can add more later.',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  _firstNameController,
                  'First Name *',
                  Icons.person,
                  theme,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildTextField(
                  _lastNameController,
                  'Last Name',
                  Icons.person_outline,
                  theme,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTextField(_phoneController, 'Phone Number', Icons.phone, theme),
          const SizedBox(height: 12),
          _buildTextField(
            _emailController,
            'Email Address *',
            Icons.email,
            theme,
          ),
          const SizedBox(height: 12),
          _buildTextField(
            _passwordController,
            'Password *',
            Icons.lock,
            theme,
            isPassword: true,
          ),
          const SizedBox(height: 12),

          DropdownButtonFormField<String>(
            value: _selectedRole,
            dropdownColor: theme.colorScheme.surface,
            decoration: InputDecoration(
              filled: true,
              fillColor: theme.colorScheme.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: theme.dividerColor),
              ),
            ),
            items: ['Admin', 'Manager', 'Developer', 'Viewer'].map((role) {
              return DropdownMenuItem(
                value: role,
                child: Text(
                  role,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                ),
              );
            }).toList(),
            onChanged: (val) => setState(() => _selectedRole = val!),
          ),

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _addMember,
              icon: const Icon(Icons.add),
              label: const Text('Add Member to List'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          if (widget.teamMembers.isNotEmpty)
            ...widget.teamMembers.map((member) {
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.primary.withOpacity(0.2),
                  child: Text(
                    member['firstName']![0],
                    style: const TextStyle(color: AppColors.primary),
                  ),
                ),
                title: Text(
                  '${member['firstName']} ${member['lastName']}',
                  style: TextStyle(color: theme.colorScheme.onSurface),
                ),
                subtitle: Text(
                  member['email']!,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                  ),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () => widget.onRemove(member['email']!),
                ),
              );
            }).toList(),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon,
    ThemeData theme, {
    bool isPassword = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: TextStyle(color: theme.colorScheme.onSurface),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: theme.colorScheme.onSurface.withOpacity(0.4),
        ),
        prefixIcon: Icon(
          icon,
          color: theme.colorScheme.onSurface.withOpacity(0.5),
          size: 20,
        ),
        filled: true,
        fillColor: theme.colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.dividerColor),
        ),
      ),
    );
  }
}

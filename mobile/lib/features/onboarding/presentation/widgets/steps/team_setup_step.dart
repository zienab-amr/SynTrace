import 'package:flutter/material.dart';
import 'package:syntrace/core/theme/app_colors.dart';

class TeamSetupStep extends StatefulWidget {
  final List<String> emails;
  final void Function(String) onAdd;
  final void Function(String) onRemove;

  const TeamSetupStep({
    super.key,
    required this.emails,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  State<TeamSetupStep> createState() => _TeamSetupStepState();
}

class _TeamSetupStepState extends State<TeamSetupStep> {
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _addEmail() {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    if (!email.contains('@')) return;
    if (widget.emails.contains(email)) return;

    widget.onAdd(email);
    _emailController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Header ───
          Text(
            'Invite your team',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add team members (optional). You can always do this later.',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
              fontSize: 14,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 24),

          // ─── Email Input ───
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: TextStyle(color: theme.colorScheme.onSurface),
                  decoration: InputDecoration(
                    hintText: 'teammate@company.com',
                    hintStyle: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.3),
                    ),
                    prefixIcon: Icon(
                      Icons.email_outlined,
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                      size: 20,
                    ),
                    filled: true,
                    fillColor: theme.colorScheme.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.dividerColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: theme.dividerColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _addEmail,
                icon: const Icon(Icons.add_circle),
                iconSize: 44,
                color: AppColors.primary,
              ),
            ],
          ),

          const SizedBox(height: 24),

          // ─── Emails List ───
          if (widget.emails.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.dividerColor.withOpacity(0.5),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.group_outlined,
                    size: 48,
                    color: theme.colorScheme.onSurface.withOpacity(0.2),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No team members yet',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            )
          else
            Column(
              children: widget.emails.map((email) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor:
                              AppColors.primary.withOpacity(0.15),
                          child: Text(
                            email[0].toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            email,
                            style: TextStyle(
                              color: theme.colorScheme.onSurface,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => widget.onRemove(email),
                          icon: Icon(
                            Icons.close,
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}
class AuthValidators {
  AuthValidators._();

  static String? requiredText(
    String? value, {
    required String label,
    required int maxLength,
  }) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return '$label is required';
    if (text.length > maxLength) {
      return '$label must be $maxLength characters or fewer';
    }
    return null;
  }

  static String? email(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Email is required';
    if (text.length > 256) return 'Email must be 256 characters or fewer';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(text)) {
      return 'Enter a valid email';
    }
    return null;
  }

  static String? loginPassword(String? value) {
    if (value == null || value.trim().isEmpty) return 'Password is required';
    if (value.length > 128) return 'Password must be 128 characters or fewer';
    return null;
  }

  // ASP.NET Identity's default password options: length >= 6, at least one
  // uppercase letter, lowercase letter, digit, and non-alphanumeric character.
  static String? signupPassword(String? value) {
    if (value == null || value.trim().isEmpty) return 'Password is required';
    if (value.length > 128) return 'Password must be 128 characters or fewer';
    if (value.length < 6) return 'Password must be at least 6 characters';
    if (!RegExp(r'[A-Z]').hasMatch(value)) {
      return 'Password must include an uppercase letter';
    }
    if (!RegExp(r'[a-z]').hasMatch(value)) {
      return 'Password must include a lowercase letter';
    }
    if (!RegExp(r'[0-9]').hasMatch(value)) {
      return 'Password must include a number';
    }
    if (!RegExp(r'[^A-Za-z0-9]').hasMatch(value)) {
      return 'Password must include a symbol';
    }
    return null;
  }

  static String? phoneNumber(String? value) {
    final text = value?.trim() ?? '';
    if (text.length > 32) return 'Phone number must be 32 characters or fewer';
    // The backend makes phone optional and applies no format rule beyond length.
    return null;
  }

  static String? otp(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'OTP is required';
    if (!RegExp(r'^[0-9]{6}$').hasMatch(text)) {
      return 'OTP must contain exactly 6 digits';
    }
    return null;
  }
}

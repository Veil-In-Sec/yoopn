import 'app_regex.dart';

class AppValidators {
  AppValidators._();

  /// Validates an email address.
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email address.';
    }
    if (!AppRegex.emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address.';
    }
    return null;
  }

  /// Validates a password.
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password.';
    }
    if (!AppRegex.passwordRegex.hasMatch(value)) {
      return 'Password must be at least 6 characters long.';
    }
    return null;
  }

  /// Validates a required text field.
  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter $fieldName.';
    }
    return null;
  }
}

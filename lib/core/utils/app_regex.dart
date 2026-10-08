class AppRegex {
  AppRegex._();

  /// Regular expression for validating standard email addresses
  static final RegExp emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  /// Regular expression for validating phone numbers
  static final RegExp phoneRegex = RegExp(
    r'^\+?[0-9]{7,15}$',
  );

  /// Regular expression for validating passwords (min 6 chars)
  static final RegExp passwordRegex = RegExp(
    r'^.{6,}$',
  );
}

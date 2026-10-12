class AppRegex {
  AppRegex._();

  static final RegExp emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  static final RegExp phoneRegex = RegExp(
    r'^\+?[0-9]{7,15}$',
  );

  static final RegExp passwordRegex = RegExp(
    r'^.{6,}$',
  );
}

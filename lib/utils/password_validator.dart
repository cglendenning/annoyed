/// Password complexity validator
class PasswordValidator {
  static const int minLength = 8;
  static const int maxLength = 128;
  
  /// Validates password complexity
  /// Returns null if valid, error message if invalid
  static String? validate(String password) {
    if (password.isEmpty) {
      return 'Password is required';
    }
    
    if (password.length < minLength) {
      return 'Password must be at least $minLength characters';
    }
    
    if (password.length > maxLength) {
      return 'Password must be less than $maxLength characters';
    }
    
    // Must contain at least one uppercase letter
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }
    
    // Must contain at least one lowercase letter
    if (!password.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter';
    }
    
    // Must contain at least one digit
    if (!password.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }
    
    // Must contain at least one special character
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'Password must contain at least one special character (!@#$%^&*(),.?":{}|<>)';
    }
    
    return null;
  }
  
  /// Returns password strength (0-4)
  static int getStrength(String password) {
    int strength = 0;
    
    if (password.length >= minLength) strength++;
    if (password.contains(RegExp(r'[A-Z]'))) strength++;
    if (password.contains(RegExp(r'[a-z]'))) strength++;
    if (password.contains(RegExp(r'[0-9]'))) strength++;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) strength++;
    
    return strength > 4 ? 4 : strength;
  }
  
  /// Returns password strength label
  static String getStrengthLabel(int strength) {
    switch (strength) {
      case 0:
      case 1:
        return 'Weak';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
      case 5:
        return 'Strong';
      default:
        return 'Weak';
    }
  }
}


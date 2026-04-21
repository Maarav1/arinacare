import 'dart:io';

import '../constants/app_constants.dart';

class ValidationService {
  static String? validateEmail(String? email) {
    if (email == null || email.isEmpty) {
      return 'Email is required';
    }
    
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+',
      caseSensitive: false,
    );
    
    if (!emailRegex.hasMatch(email)) {
      return 'Please enter a valid email address';
    }
    
    return null;
  }

  static String? validatePassword(String? password) {
    if (password == null || password.isEmpty) {
      return 'Password is required';
    }
    
    if (password.length < AppConstants.minPasswordLength) {
      return 'Password must be at least ${AppConstants.minPasswordLength} characters';
    }
    
    if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'Include at least one uppercase letter';
    }
    
    if (!password.contains(RegExp(r'[a-z]'))) {
      return 'Include at least one lowercase letter';
    }
    
    if (!password.contains(RegExp(r'[0-9]'))) {
      return 'Include at least one number';
    }
    
    if (!password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
      return 'Include at least one special character';
    }
    
    return null;
  }

  static String? validateRequiredField(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? validateName(String? value, String fieldName) {
    final requiredError = validateRequiredField(value, fieldName);
    if (requiredError != null) return requiredError;
    
    if (value!.length < 2) {
      return '$fieldName must be at least 2 characters';
    }
    
    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value)) {
      return '$fieldName can only contain letters and spaces';
    }
    
    return null;
  }

  static String? validateDateOfBirth(DateTime? date) {
    if (date == null) {
      return 'Date of birth is required';
    }
    
    final now = DateTime.now();
    final age = now.year - date.year;
    
    // Check if birthday has occurred this year
    final hasBirthdayOccurred = now.month > date.month || 
        (now.month == date.month && now.day >= date.day);
    
    final actualAge = hasBirthdayOccurred ? age : age - 1;
    
    if (actualAge < AppConstants.minAgeYears) {
      return 'You must be at least ${AppConstants.minAgeYears} years old';
    }
    
    if (date.isAfter(now)) {
      return 'Date of birth cannot be in the future';
    }
    
    return null;
  }

  static String? validateHobbies(List<String> hobbies) {
    if (hobbies.isEmpty) {
      return 'Please select at least one hobby';
    }
    
    if (hobbies.length > 10) {
      return 'Please select no more than 10 hobbies';
    }
    
    return null;
  }

  static String? validatePhoneNumber(String? phone) {
    if (phone == null || phone.isEmpty) {
      return null; // Phone is optional
    }
    
    // Remove all non-digit characters except +
    final cleanedPhone = phone.replaceAll(RegExp(r'[^\d+]'), '');
    
    // Basic phone validation - allows international formats
    final phoneRegex = RegExp(r'^\+?[0-9]{8,15}$');
    
    if (!phoneRegex.hasMatch(cleanedPhone)) {
      return 'Please enter a valid phone number (8-15 digits)';
    }
    
    return null;
  }

  static String? validateCountry(String? country) {
    if (country == null || country.isEmpty) {
      return 'Country is required';
    }
    
    if (country.length < 2) {
      return 'Please enter a valid country name';
    }
    
    if (!RegExp(r'^[a-zA-Z\s\-]+$').hasMatch(country)) {
      return 'Country name can only contain letters, spaces, and hyphens';
    }
    
    return null;
  }

  static String? validateCity(String? city) {
    if (city == null || city.isEmpty) {
      return 'City is required';
    }
    
    if (city.length < 2) {
      return 'Please enter a valid city name';
    }
    
    if (!RegExp(r'^[a-zA-Z\s\-]+$').hasMatch(city)) {
      return 'City name can only contain letters, spaces, and hyphens';
    }
    
    return null;
  }

  static String? validateProfileImage(File? image) {
    if (image == null) {
      return 'Profile image is required';
    }
    return null;
  }

  static String? validateTermsAgreement(bool agreed) {
    if (!agreed) {
      return 'You must agree to the terms and conditions';
    }
    return null;
  }

  // Comprehensive form validation
  static Map<String, String?> validateSignupForm({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String countryOfOrigin,
    required String countryOfResidence,
    required String city,
    required DateTime? dateOfBirth,
    required List<String> hobbies,
    required File? profileImage,
    required bool agreedToTerms,
    String? phoneNumber,
  }) {
    return {
      'firstName': validateName(firstName, 'First Name'),
      'lastName': validateName(lastName, 'Last Name'),
      'email': validateEmail(email),
      'password': validatePassword(password),
      'countryOfOrigin': validateCountry(countryOfOrigin),
      'countryOfResidence': validateCountry(countryOfResidence),
      'city': validateCity(city),
      'dateOfBirth': validateDateOfBirth(dateOfBirth),
      'hobbies': validateHobbies(hobbies),
      'profileImage': validateProfileImage(profileImage),
      'terms': validateTermsAgreement(agreedToTerms),
      'phoneNumber': validatePhoneNumber(phoneNumber),
    };
  }

  // Check if form has any validation errors
  static bool isFormValid(Map<String, String?> validationResults) {
    return validationResults.values.every((error) => error == null);
  }

  // Get first validation error message
  static String? getFirstValidationError(Map<String, String?> validationResults) {
    for (final error in validationResults.values) {
      if (error != null) {
        return error;
      }
    }
    return null;
  }

  // Get all validation errors as a list
  static List<String> getAllValidationErrors(Map<String, String?> validationResults) {
    return validationResults.values
        .where((error) => error != null)
        .cast<String>()
        .toList();
  }
}
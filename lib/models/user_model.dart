import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String firstName;
  final String lastName;
  final String fullName;
  final String gender;
  final String interestedIn;
  final String relationshipStatus;
  final String occupation;
  final String educationLevel;
  final String countryOfOrigin;
  final String countryOfResidence;
  final String city;
  final String phoneNumber;
  final String userEmail;
  final List<String> hobbies;
  final String? profilePictureUrl;
  final DateTime? dateOfBirth;
  final bool isOnline;
  final bool emailVisibility;
  final bool phoneVisibility;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.gender,
    required this.interestedIn,
    required this.relationshipStatus,
    required this.occupation,
    required this.educationLevel,
    required this.countryOfOrigin,
    required this.countryOfResidence,
    required this.city,
    required this.phoneNumber,
    required this.userEmail,
    required this.hobbies,
    this.profilePictureUrl,
    this.dateOfBirth,
    this.isOnline = true,
    this.emailVisibility = false,
    this.phoneVisibility = false,
    required this.createdAt,
    required this.updatedAt,
  }) : fullName = '$firstName $lastName';

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'firstName': firstName,
      'lastName': lastName,
      'fullName': fullName,
      'gender': gender,
      'interestedIn': interestedIn,
      'relationshipStatus': relationshipStatus,
      'occupation': occupation,
      'educationLevel': educationLevel,
      'countryOfOrigin': countryOfOrigin,
      'countryOfResidence': countryOfResidence,
      'city': city,
      'phoneNumber': phoneNumber,
      'userEmail': userEmail,
      'hobbies': hobbies,
      'profilePictureUrl': profilePictureUrl,
      'isOnline': isOnline,
      'emailVisibility': emailVisibility,
      'phoneVisibility': phoneVisibility,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (dateOfBirth != null) 'dateOfBirth': Timestamp.fromDate(dateOfBirth!),
    };
  }

  // Create from Firestore document
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      uid: doc.id,
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      gender: data['gender'] ?? '',
      interestedIn: data['interestedIn'] ?? '',
      relationshipStatus: data['relationshipStatus'] ?? '',
      occupation: data['occupation'] ?? '',
      educationLevel: data['educationLevel'] ?? '',
      countryOfOrigin: data['countryOfOrigin'] ?? '',
      countryOfResidence: data['countryOfResidence'] ?? '',
      city: data['city'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      userEmail: data['userEmail'] ?? '',
      hobbies: List<String>.from(data['hobbies'] ?? []),
      profilePictureUrl: data['profilePictureUrl'],
      dateOfBirth: data['dateOfBirth'] != null 
          ? (data['dateOfBirth'] as Timestamp).toDate() 
          : null,
      isOnline: data['isOnline'] ?? true,
      emailVisibility: data['emailVisibility'] ?? false,
      phoneVisibility: data['phoneVisibility'] ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }
}
class CustomerModel {
  final String id;
  final String firstName;
  final String lastName;
  final String name;
  final String email;
  final String phone;
  final String birthday;
  final String gender;
  final String profileImage;

  const CustomerModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.name,
    required this.email,
    required this.phone,
    this.birthday = '',
    this.gender = '',
    this.profileImage = '',
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) => CustomerModel(
    id: (json['id'] ?? json['_id']) as String,
    firstName: (json['firstName'] ?? '') as String,
    lastName: (json['lastName'] ?? '') as String,
    name: (json['name'] ?? '') as String,
    email: (json['email'] ?? '') as String,
    phone: json['phone'] as String,
    birthday: (json['birthday'] ?? '') as String,
    gender: (json['gender'] ?? '') as String,
    profileImage: (json['profileImage'] ?? '') as String,
  );

  Map<String, dynamic> toJson() => {
        'id': id,
        'firstName': firstName,
        'lastName': lastName,
        'name': name,
        'email': email,
        'phone': phone,
        'birthday': birthday,
        'gender': gender,
        'profileImage': profileImage,
      };
}

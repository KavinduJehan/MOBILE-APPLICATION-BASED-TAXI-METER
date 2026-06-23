class CustomerModel {
  final String id;
  final String firstName;
  final String lastName;
  final String name;
  final String email;
  final String phone;

  const CustomerModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.name,
    required this.email,
    required this.phone,
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) => CustomerModel(
    id: (json['id'] ?? json['_id']) as String,
    firstName: (json['firstName'] ?? '') as String,
    lastName: (json['lastName'] ?? '') as String,
    name: (json['name'] ?? '') as String,
    email: (json['email'] ?? '') as String,
    phone: json['phone'] as String,
  );
}

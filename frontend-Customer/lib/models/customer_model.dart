class CustomerModel {
  final String id;
  final String name;
  final String phone;

  const CustomerModel({
    required this.id,
    required this.name,
    required this.phone,
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) => CustomerModel(
    id: (json['id'] ?? json['_id']) as String,
    name: json['name'] as String,
    phone: json['phone'] as String,
  );
}

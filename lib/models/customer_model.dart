class Customer {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String location;
  final String? role;

  Customer({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.location,
    this.role,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      role: json['role']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'location': location,
      if (role != null) 'role': role,
    };
  }

  Customer copyWith({String? name, String? phone, String? location}) {
    return Customer(
      id: id,
      name: name ?? this.name,
      email: email,
      phone: phone ?? this.phone,
      location: location ?? this.location,
      role: role,
    );
  }
}

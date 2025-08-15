// 用户类定义
class User {
  final int userID;
  final String name;
  final String email;
  final int? role;
  final int? state;
  final String? created_at;
  final String? updated_at;

  User({
    required this.userID,
    required this.name,
    required this.email,
    this.role,
    this.state,
    this.created_at,
    this.updated_at,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userID: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as int??0,
      state: json['state'] as int??0,
      created_at: json['created_at']?.toString(),
      updated_at: json['updated_at']?.toString(),
    );
  }
}

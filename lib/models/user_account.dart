class UserAccount {
  final String name;
  final String email;
  final String passwordHash;

  const UserAccount(this.name, this.email, this.passwordHash);

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'password_hash': passwordHash,
      };

  factory UserAccount.fromJson(Map<String, dynamic> j) => UserAccount(
        j['name'] as String,
        j['email'] as String,
        j['password_hash'] as String,
      );
}

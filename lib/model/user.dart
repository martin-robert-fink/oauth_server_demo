import 'package:uuid/uuid.dart';

import '../constants/keys.dart' as kc;

enum Role { user, admin }

class User {
  User({
    this.id,
    this.lastName,
    this.firstName,
    this.name,
    this.email,
    this.roles,
  });
  final String id;
  final String lastName;
  final String firstName;
  final String name;
  final String email;
  final List<Role> roles;

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json[kc.ID],
        lastName: json[kc.LAST_NAME],
        firstName: json[kc.FIRST_NAME],
        name: json[kc.NAME],
        email: json[kc.EMAIL],
        roles: List<Role>.from(json[kc.ROLES].map(((x) => Role.values[x]))),
      );

  factory User.fromTokenData(Map<String, dynamic> tokenData) => User(
        id: Uuid().v4(),
        lastName: tokenData.containsKey(kc.LAST_NAME)
            ? tokenData[kc.LAST_NAME]
            : null,
        firstName: tokenData.containsKey(kc.FIRST_NAME)
            ? tokenData[kc.FIRST_NAME]
            : null,
        name: tokenData.containsKey(kc.NAME) ? tokenData[kc.NAME] : null,
        email: tokenData[kc.EMAIL],
        roles: [Role.user],
      );

  Map<String, dynamic> toJson() => {
        kc.ID: id,
        kc.LAST_NAME: lastName,
        kc.FIRST_NAME: firstName,
        kc.NAME: name,
        kc.EMAIL: email,
        kc.ROLES: List<int>.from(roles.map((x) => x.index)),
      };
}

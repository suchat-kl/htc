class Employee {
  final int? empID;
  final String? name;
  final String? lastname;
  final String? position;
  final int? orgID;
  final String? orgName;
  final int? userID;
  final String? userName;

  Employee({
    this.empID,
    this.name,
    this.lastname,
    this.position,
    this.orgID = 10,
    this.orgName,
    this.userID,
    this.userName,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      empID: json['empID'] as int?,
      name: json['name'] as String? ?? '',
      lastname: json['lastname'] as String? ?? '',
      position: json['position'] as String?,
      orgID: json['orgID'] as int? ?? 10,
      orgName: json['orgName'] as String?,
      userID: json['userID'] as int?,
      userName: json['userName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (empID != null) 'empID': empID,
      'name': name,
      'lastname': lastname,
      'position': position,
      'orgID': orgID,
      'userID': userID,
    };
  }

  String get fullName => '${name ?? ''} ${lastname ?? ''}'.trim();
}

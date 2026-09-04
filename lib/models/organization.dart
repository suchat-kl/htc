class Organization {
  final int? orgID;
  final String? orgLevel;
  final String? orgCode;
  final String? orgName;
  final int? orgidParent;
  final String? parentOrgName;

  Organization({
    this.orgID,
    this.orgLevel,
    this.orgCode,
    this.orgName,
    this.orgidParent,
    this.parentOrgName,
  });

  factory Organization.fromJson(Map<String, dynamic> json) {
    return Organization(
      orgID: json['orgID'] as int?,
      orgLevel: json['orgLevel'] as String? ?? '',
      orgCode: json['orgCode'] as String? ?? '',
      orgName: json['orgName'] as String? ?? '-',
      orgidParent: json['orgidParent'] as int?,
      parentOrgName: json['parentOrgName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (orgID != null) 'orgID': orgID,
      'orgLevel': orgLevel,
      'orgCode': orgCode,
      'orgName': orgName,
      'orgidParent': orgidParent,
    };
  }
}

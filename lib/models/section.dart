class Section {
  final int? secID;
  final String? name;
  final int? orgID;
  final String? orgName;

  Section({this.secID, this.name, this.orgID = 10, this.orgName});

  factory Section.fromJson(Map<String, dynamic> json) {
    return Section(
      secID: json['secID'] as int?,
      name: json['name'] as String? ?? '',
      orgID: json['orgID'] as int? ?? 10,
      orgName: json['orgName'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {if (secID != null) 'secID': secID, 'name': name, 'orgID': orgID};
  }
}

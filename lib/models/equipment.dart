class Equipment {
  final int? equipmentID;
  final int? roomtypeid;
  final String? roomtypeName;
  final int? bookingid;
  final String? booktitle;
  final int? numberperson;
  final String? startdate;
  final String? stopdate;
  final int sequence;
  final String? place;
  final String? contractname;

  Equipment({
    this.equipmentID,
    this.roomtypeid,
    this.roomtypeName,
    this.bookingid,
    this.booktitle,
    this.numberperson,
    this.startdate,
    this.stopdate,
    this.sequence = 0,
    this.place,
    this.contractname,
  });

  factory Equipment.fromJson(Map<String, dynamic> json) {
    return Equipment(
      equipmentID: json['equipmentID'] as int?,
      roomtypeid: json['roomtypeid'] as int?,
      roomtypeName: json['roomtypeName'] as String?,
      bookingid: json['bookingid'] as int?,
      booktitle: json['booktitle'] as String?,
      numberperson: json['numberperson'] as int?,
      startdate: json['startdate'] as String?,
      stopdate: json['stopdate'] as String?,
      sequence: json['sequence'] as int? ?? 0,
      place: json['place'] as String?,
      contractname: json['contractname'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (equipmentID != null) 'equipmentID': equipmentID,
      'roomtypeid': roomtypeid,
      'bookingid': bookingid,
      'numberperson': numberperson,
      'startdate': startdate,
      'stopdate': stopdate,
      'sequence': sequence,
      'place': place,
      'contractname': contractname,
    };
  }
}

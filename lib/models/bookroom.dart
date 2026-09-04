// lib/models/bookroom.dart
class Bookroom {
  final int? bookID;
  final String? idcard;
  final String? startdate;
  final String? stopdate;
  final int? numbermember;
  final int? numberstaff;
  final String? departmentname;
  final String? booktitle;
  final String? contractname1;
  final String? contractnumber1;
  final String? bookingtype;
  final String? requestroom;
  final String? requestconference;
  final String? bookremark;
  final int? statusId;
  final String? statusName;
  final String? c; // ห้องกิจกรรม
  // ignore: non_constant_identifier_names
  final String? c_color; // สีห้องกิจกรรม
  final String? r; // ห้องพัก
  // ignore: non_constant_identifier_names
  final String? r_color; // สีห้องพัก

  Bookroom({
    this.bookID,
    this.idcard,
    this.startdate,
    this.stopdate,
    this.numbermember,
    this.numberstaff,
    this.departmentname,
    this.booktitle,
    this.contractname1,
    this.contractnumber1,
    this.bookingtype,
    this.requestroom,
    this.requestconference,
    this.bookremark,
    this.statusId,
    this.statusName,
    this.c,
    this.c_color,
    this.r,
    this.r_color,
  });

  factory Bookroom.fromJson(Map<String, dynamic> json) {
    return Bookroom(
      bookID: json['bookID'] as int?,
      idcard: json['idcard'] as String?,
      startdate: json['startdate'] as String?,
      stopdate: json['stopdate'] as String?,
      numbermember: json['numbermember'] as int?,
      numberstaff: json['numberstaff'] as int?,
      departmentname: json['departmentname'] as String?,
      booktitle: json['booktitle'] as String?,
      contractname1: json['contractname1'] as String?,
      contractnumber1: json['contractnumber1'] as String?,
      bookingtype: json['bookingtype'] as String?,
      requestroom: json['requestroom'] as String?,
      requestconference: json['requestconference'] as String?,
      bookremark: json['bookremark'] as String?,
      statusId: json['statusId'] as int?,
      statusName: json['statusName'] as String?,
      c: json['c'] as String?,
      c_color: json['c_color'] as String?,
      r: json['r'] as String?,
      r_color: json['r_color'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bookID': bookID,
      'idcard': idcard,
      'startdate': startdate,
      'stopdate': stopdate,
      'numbermember': numbermember,
      'numberstaff': numberstaff,
      'departmentname': departmentname,
      'booktitle': booktitle,
      'contractname1': contractname1,
      'contractnumber1': contractnumber1,
      'bookingtype': bookingtype,
      'requestroom': requestroom,
      'requestconference': requestconference,
      'bookremark': bookremark,
      'statusId': statusId,
      'statusName': statusName,
      'c': c,
      'c_color': c_color,
      'r': r,
      'r_color': r_color,
    };
  }
}

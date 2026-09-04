class Maintenance {
  final int? maintenanceID;
  final String? reportname;
  final String? placetype;
  final String? place;
  final String? position;
  final String? reportdate;
  final String? reporttel;
  final String? reportremark;
  final String? assignee;
  final String? workdetail;
  final double? price;
  final String? resolutiontype;
  final String? workremark;
  final String? startdate;
  final String? stopdate;
  final String? workstatus;
  final String? worktype;
  final int? roomid;
  final int? employeeid1;
  final int? employeeid2;

  Maintenance({
    this.maintenanceID,
    this.reportname,
    this.placetype,
    this.place,
    this.position,
    this.reportdate,
    this.reporttel,
    this.reportremark,
    this.assignee,
    this.workdetail,
    this.price,
    this.resolutiontype,
    this.workremark,
    this.startdate,
    this.stopdate,
    this.workstatus,
    this.worktype,
    this.roomid,
    this.employeeid1,
    this.employeeid2,
  });

  factory Maintenance.fromJson(Map<String, dynamic> json) {
    return Maintenance(
      maintenanceID: json['maintenanceID'] as int?,
      reportname: json['reportname'] as String?,
      placetype: json['placetype'] as String?,
      place: json['place'] as String?,
      position: json['position'] as String?,
      reportdate: json['reportdate'] as String?,
      reporttel: json['reporttel'] as String?,
      reportremark: json['reportremark'] as String?,
      assignee: json['assignee'] as String?,
      workdetail: json['workdetail'] as String?,
      price: (json['price'] as num?)?.toDouble(),
      resolutiontype: json['resolutiontype'] as String?,
      workremark: json['workremark'] as String?,
      startdate: json['startdate'] as String?,
      stopdate: json['stopdate'] as String?,
      workstatus: json['workstatus'] as String?,
      worktype: json['worktype'] as String?,
      roomid: json['roomid'] as int?,
      employeeid1: json['employeeid1'] as int?,
      employeeid2: json['employeeid2'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (maintenanceID != null) 'maintenanceID': maintenanceID,
      'reportname': reportname,
      'placetype': placetype,
      'place': place,
      'position': position,
      'reportdate': reportdate,
      'reporttel': reporttel,
      'reportremark': reportremark,
      'assignee': assignee,
      'workdetail': workdetail,
      'price': price,
      'resolutiontype': resolutiontype,
      'workremark': workremark,
      'startdate': startdate,
      'stopdate': stopdate,
      'workstatus': workstatus,
      'worktype': worktype,
      'roomid': roomid,
      'employeeid1':employeeid1,
      'employeeid2': employeeid2,
    };
  }

  // String get placetypeName {
  //   switch (placetype) {
  //     case 'A':
  //       return 'ห้องพัก';
  //     case 'B':
  //       return 'อื่นๆ';
  //     default:
  //       return placetype ?? '-';
  //   }
  // }

  // String get workstatusName {
  //   switch (workstatus) {
  //     case '1':
  //       return 'ยังไม่ดำเนินการ';
  //     case '2':
  //       return 'กำลังดำเนินการ';
  //     case '3':
  //       return 'เสร็จแล้ว';
  //     default:
  //       return workstatus ?? '-';
  //   }
  // }
// ✅ Add this getter to Maintenance class
  String get maintenanceInfo {
    final parts = <String>[];
    if (maintenanceID != null) parts.add('$maintenanceID');
    if (place != null && place!.isNotEmpty) parts.add(place!);
    if (position != null && position!.isNotEmpty) parts.add(position!);
    return parts.join(' ');
  }
  // String get worktypeName {
  //   switch (worktype) {
  //     case '1':
  //       return 'แจ้งซ่อม';
  //     case '2':
  //       return 'งานบำรุง';
  //     default:
  //       return worktype ?? '-';
  //   }
  // }

  // String get resolutiontypeName {
  //   switch (resolutiontype) {
  //     case '1':
  //       return 'ซ่อมเอง';
  //     case '2':
  //       return 'จ้างเหมา';
  //     default:
  //       return resolutiontype ?? '-';
  //   }
  // }
  //new
  String get workstatusName {
    switch (workstatus) {
      case '0':
        return 'ยังไม่มีผู้รับงาน';
      case '1':
        return 'รับงาน';
      case '2':
        return 'รออุปกรณ์หรือจ้างซ่อม';
      case '3':
        return 'ปิดงาน';
      case '4':
        return 'ยกเลิกงาน';
      case '5':
        return 'ไม่ระบุ';
      default:
        return workstatus ?? '-';
    }
  }

  String get placetypeName {
    switch (placetype) {
      case 'O':
        return 'อาคารอำนวยการ';
      case 'C':
        return 'อาคารเรียน';
      case 'R':
        return 'อาคารพัก';
      default:
        return placetype ?? '-';
    }
  }

  String get worktypeName {
    switch (worktype) {
      case 'E':
        return 'ไฟฟ้า';
      case 'A':
        return 'เครื่องปรับอากาศ';
      case 'P':
        return 'ประปา';
      case 'TV':
        return 'โทรทัศน์';
      case 'TP':
        return 'โทรศัพท์';
      case 'B':
        return 'อาคารสถานที่';
      default:
        return worktype ?? '-';
    }
  }

  String get resolutiontypeName {
    switch (resolutiontype) {
      case 'C':
        return 'ซ่อม';
      case 'O':
        return 'จ้างซ่อม';
      default:
        return resolutiontype ?? '-';
    }
  }
}

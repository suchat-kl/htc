// lib/utils/file_pick.dart
import 'dart:async';
import 'dart:typed_data';

import 'package:universal_html/html.dart' as html;

/// ไฟล์ที่ผู้ใช้เลือกจากเครื่อง
class PickedFile {
  final String name;
  final Uint8List bytes;

  const PickedFile(this.name, this.bytes);
}

/// เปิดหน้าต่างเลือกรูปภาพของเบราว์เซอร์ แล้วอ่านไฟล์เป็นไบต์
///
/// ใช้ input type=file ของเบราว์เซอร์ตรง ๆ ไม่ต้องเพิ่มแพ็กเกจ file_picker
/// ถ้าผู้ใช้กดยกเลิก เบราว์เซอร์ไม่แจ้งอะไรกลับมา Future จึงค้างอยู่เฉย ๆ
/// หน้าจอจึงไม่ควรขึ้นตัวหมุนรอก่อนได้ไฟล์
Future<PickedFile?> pickImageFile() {
  final completer = Completer<PickedFile?>();
  final input = html.FileUploadInputElement()..accept = 'image/png,image/jpeg';

  input.onChange.listen((_) {
    final files = input.files;
    if (files == null || files.isEmpty) {
      completer.complete(null);
      return;
    }
    final file = files.first;
    final reader = html.FileReader();
    reader.onLoadEnd.listen((_) {
      if (completer.isCompleted) return;
      final result = reader.result;
      if (result is ByteBuffer) {
        completer.complete(PickedFile(file.name, result.asUint8List()));
      } else if (result is Uint8List) {
        completer.complete(PickedFile(file.name, result));
      } else {
        completer.completeError(Exception('อ่านไฟล์ที่เลือกไม่สำเร็จ'));
      }
    });
    reader.onError.listen((_) {
      if (!completer.isCompleted) {
        completer.completeError(Exception('อ่านไฟล์ที่เลือกไม่สำเร็จ'));
      }
    });
    reader.readAsArrayBuffer(file);
  });

  input.click();
  return completer.future;
}

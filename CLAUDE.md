# HTC — Highway Training System (Flutter Web)

ระบบจองห้องอบรม/ห้องพักของกรมทางหลวง ส่วนหน้าเว็บ เขียนด้วย Flutter Web

## โครงสร้างระบบ

โปรเจกต์นี้เป็นครึ่งหนึ่งของระบบ อีกครึ่งคือ backend Spring Boot ที่อยู่คนละ repo:

| ส่วน | path บน Windows |
|---|---|
| Frontend (repo นี้) | `C:\AI\flutter\htc` |
| Backend | `C:\AI\springboot\htc_sp35` |

เวลาต้องแก้ API / entity / report ให้ทำที่โฟลเดอร์ backend และอ่าน `CLAUDE.md` ของฝั่งนั้นประกอบ

API endpoint: `https://backupdoh.doh.go.th/htcapi` (กำหนดที่ `lib/services/api_service.dart`)

## คำสั่งที่ใช้ประจำ

```bash
flutter run -d chrome                          # dev (debug mode, log แสดงครบ)
flutter build web --no-wasm-dry-run            # build production → build/web
flutter analyze
```

ตอนติดปัญหา dependency: `flutter clean && flutter pub get` (บางเคสต้องลบ `pubspec.lock` ก่อน)

**ห้าม** build ขึ้น production ด้วย `--debug` หรือ `--profile` — ต้องเป็น release เท่านั้น มิฉะนั้น log จะไม่ถูก tree-shake

## ผังโค้ด (`lib/`, ~92 ไฟล์)

```
config/      theme.dart — ธีมและสีทั้งระบบ
models/      โมเดลข้อมูล 1 ไฟล์ต่อ 1 entity (bookroom, room, tfood, employee, ...)
providers/   auth_provider.dart — สถานะ login/session
services/    api_service.dart (Dio ทุก endpoint), auth_interceptor.dart (แนบ/refresh JWT)
screens/     หน้าจอหลัก + tab ของหน้าจอง (booking_*_tab.dart)
widgets/     dialog เพิ่ม/แก้ไขข้อมูล (*_dialog.dart) + ส่วนประกอบร่วม (header, sidebar_menu, footer)
utils/       logger.dart, dialog.dart, snackbar_helper.dart, event_bus.dart, util.dart
```

รูปแบบที่ใช้ทั้งโปรเจกต์: หนึ่ง entity มี `models/x.dart` + `screens/x_screen.dart` + `widgets/x_dialog.dart` เวลาเพิ่ม entity ใหม่ให้ทำครบสามไฟล์ตามแบบเดิม

## ข้อกำหนดเฉพาะโปรเจกต์

**Logging** ใช้ `AppLogger` จาก `lib/utils/logger.dart` เท่านั้น อย่าใช้ `print()` หรือ `debugPrint()` — `AppLogger` ถูกตัดออกตอน compile release เพื่อไม่ให้ token หลุดลง browser console ถ้าข้อความ log ต้องคำนวณค่าที่แพงหรืออ่อนไหว ให้ใช้ `AppLogger.lazy(() => ...)`

**ฟอนต์ไทย** ต้องระบุ `fontFamily` ให้ชัดเสมอ (`Sarabun`, `NotoSansThai`, `Kanit` — bundle มาในโปรเจกต์แล้ว ไม่ได้โหลดจาก Google Fonts ตอน runtime)

**ภาษา** ข้อความที่ผู้ใช้เห็นเป็นภาษาไทยทั้งหมด คอมเมนต์ในโค้ดก็เป็นภาษาไทย เขียนโค้ดใหม่ให้เข้าชุดกัน

## Git

remote: `https://github.com/suchat-kl/htc.git` — commit message เป็นภาษาไทยรูปแบบ Conventional Commits เช่น `feat(booking): เพิ่มตารางรายการอาหาร`

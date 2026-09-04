#!/usr/bin/env bash
# ตรวจว่าไม่มี debugPrint / print หลุดกลับเข้ามาใน lib/
#
# `avoid_print` ใน analysis_options.yaml ดักได้แค่ print() แต่ดัก debugPrint ไม่ได้
# สคริปต์นี้ปิดช่องว่างนั้น ใช้รันใน CI หรือ pre-commit hook
#
#   bash tool/check_logging.sh
set -uo pipefail

cd "$(dirname "$0")/.."

fail=0

hits=$(grep -rn "debugPrint(" lib --include="*.dart" | grep -v "^lib/main.dart:" || true)
if [ -n "$hits" ]; then
  echo "พบ debugPrint( ที่ยังไม่ได้แปลงเป็น AppLogger:"
  echo "$hits"
  fail=1
fi

hits=$(grep -rnE "(^|[^a-zA-Z0-9_.])print\(" lib --include="*.dart" || true)
if [ -n "$hits" ]; then
  echo "พบ print( ใน lib/ — ให้ใช้ AppLogger แทน:"
  echo "$hits"
  fail=1
fi

# LogInterceptor ต้องไม่เปิด header/body ทิ้งไว้ (token และ PII จะโผล่ใน console)
hits=$(grep -rnE "(requestHeader|responseBody|requestBody|responseHeader): true" lib --include="*.dart" || true)
if [ -n "$hits" ]; then
  echo "LogInterceptor เปิด header/body ไว้ — เสี่ยง token รั่ว:"
  echo "$hits"
  fail=1
fi

if [ "$fail" -eq 0 ]; then
  echo "ตรวจ logging ผ่าน ไม่พบ debugPrint/print ที่ไม่ควรมี"
fi
exit "$fail"

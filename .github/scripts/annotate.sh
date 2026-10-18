#!/usr/bin/env bash
# Chuyển lỗi biên dịch / test / báo cáo trong log thành annotation GitHub,
# để đọc được qua API mà không cần tải log.
# Dùng: annotate.sh <file-log> <thư-mục-gốc-để-rút-gọn-đường-dẫn>
log="$1"; root="${2:-$PWD}"
[ -f "$log" ] || exit 0

# Kết quả XCTest / swift-testing
grep -E "Executed [0-9]+ tests?|[0-9]+ tests? (passed|failed)" "$log" \
  | tail -3 | while IFS= read -r l; do echo "::notice title=tests::${l}"; done

# Báo cáo số liệu (dòng bắt đầu bằng REPORT:)
grep -E "^REPORT: " "$log" | sort -u | head -12 \
  | while IFS= read -r l; do echo "::notice title=report::${l#REPORT: }"; done

# Lỗi biên dịch / test Swift
grep -E "^[^ ]+\.swift:[0-9]+(:[0-9]+)?: (error|fatal error): " "$log" | sort -u | head -40 \
  | while IFS= read -r l; do
      f=$(echo "$l" | cut -d: -f1); ln=$(echo "$l" | cut -d: -f2)
      msg=$(echo "$l" | sed -E 's/^[^ ]+\.swift:[0-9]+(:[0-9]+)?: (fatal )?error: //')
      rel="${f#$root/}"
      echo "::error file=${rel},line=${ln}::${rel}:${ln}: ${msg}"
    done
grep -E "error: (unable|could not|no such|failed|invalid|manifest)|BUILD FAILED|xcodebuild: error" "$log" | sort -u | head -10 \
  | while IFS= read -r l; do echo "::error title=build::${l}"; done

# Python
grep -E "^Ran [0-9]+ tests? in|^(OK|FAILED)( \(.*\))?$" "$log" | tail -2 \
  | while IFS= read -r l; do echo "::notice title=python::${l}"; done
grep -E "^[A-Za-z]*(Error|Exception): |^ERROR: " "$log" | sort -u | head -8 \
  | while IFS= read -r l; do echo "::error title=python::${l}"; done
exit 0

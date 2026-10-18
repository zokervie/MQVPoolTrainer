#!/usr/bin/env bash
# Chuyển lỗi biên dịch / test trong log thành annotation GitHub,
# để đọc được qua API mà không cần tải log.
# Dùng: annotate.sh <file-log> <tiền-tố-thư-mục-để-rút-gọn>
log="$1"; root="${2:-$PWD}"
[ -f "$log" ] || exit 0
grep -E "Executed [0-9]+ tests?|Test Suite 'All tests' (passed|failed)|[0-9]+ tests? (passed|failed)" "$log" \
  | tail -3 | while IFS= read -r l; do echo "::notice title=tests::${l}"; done
grep -E "^[^ ]+\.swift:[0-9]+(:[0-9]+)?: (error|fatal error): " "$log" | sort -u | head -40 \
  | while IFS= read -r l; do
      f=$(echo "$l" | cut -d: -f1); ln=$(echo "$l" | cut -d: -f2)
      msg=$(echo "$l" | sed -E 's/^[^ ]+\.swift:[0-9]+(:[0-9]+)?: (fatal )?error: //')
      rel="${f#$root/}"
      echo "::error file=${rel},line=${ln}::${rel}:${ln}: ${msg}"
    done
grep -E "error: (unable|could not|no such|failed|invalid|manifest)|BUILD FAILED|xcodebuild: error" "$log" | sort -u | head -10 \
  | while IFS= read -r l; do echo "::error title=build::${l}"; done
exit 0

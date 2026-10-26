#!/bin/bash
set -euo pipefail
cd -- "$(dirname -- "$0")"
mkdir -p build/physics-checks
for suite in Physics Prediction Practice Contact ExtendedPractice Research Elevated; do
  xcrun clang++ -std=c++17 -O2 -Wall -Wextra -Wpedantic -Werror \
    "Tests/${suite}Tests.cpp" BankLab/Core/Physics.cpp BankLab/Core/ElevatedPhysics.cpp -o "build/physics-checks/$suite"
  "build/physics-checks/$suite"
done
echo 'Các kiểm tra lõi đã qua. Đây chưa phải phép đo so với bàn thật.'

cmake_minimum_required(VERSION 3.16)
project(BankLabPhysics LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
enable_testing()

# Keep this list identical to the suite loop in Run-All-Checks.command.
# CI checks the two lists match, so a new test file cannot be silently skipped by ctest.
set(ZOKER_TEST_SUITES
  Physics Prediction Practice Contact ExtendedPractice Research Elevated KickSearch
  Calibration Cushion3D Presentation SpinTransfer PresentationPolicy Determinism Literature CueClearance DiamondSystem PowerScale MatchRules)

foreach(suite IN LISTS ZOKER_TEST_SUITES)
  add_executable(${suite}Tests Tests/${suite}Tests.cpp BankLab/Core/Physics.cpp BankLab/Core/ElevatedPhysics.cpp)
  target_compile_options(${suite}Tests PRIVATE -Wall -Wextra -Wpedantic -Werror)
  # Tests are assert-based: keep asserts live even in Release, otherwise every suite passes vacuously.
  target_compile_options(${suite}Tests PRIVATE -UNDEBUG)
  add_test(NAME ${suite} COMMAND ${suite}Tests)
endforeach()

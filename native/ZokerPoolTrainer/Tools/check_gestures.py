#!/usr/bin/env python3
"""Chặn lỗi build 5: cử chỉ một ngón (pan ngắm) không được chờ cử chỉ nhiều ngón thất bại.
UIPanGestureRecognizer(minimumNumberOfTouches=2) và UIPinchGestureRecognizer chỉ thất bại khi nhấc tay,
nên `pan.require(toFail: orbit|pinch)` làm kéo một ngón không bao giờ bắt đầu → không xoay được cơ."""
import re, sys, pathlib
src = pathlib.Path(__file__).resolve().parent.parent / "BankLab/UI/TrainingController.swift"
text = src.read_text()
bad = re.findall(r"\bpan\.require\(toFail:\s*(orbit|pinch)\)", text)
if bad:
    print(f"FAIL: pan ngắm đang chờ {bad} thất bại — kéo một ngón sẽ không xoay được cơ")
    sys.exit(1)
if not re.search(r"pan\.maximumNumberOfTouches\s*=\s*1", text):
    print("FAIL: pan ngắm phải giới hạn một ngón"); sys.exit(1)
print("PASS: cử chỉ ngắm một ngón không bị cử chỉ hai ngón chặn")
if not re.search(r"func panTable.*?aimPitch", text, re.S):
    print("FAIL: kéo một ngón phải điều khiển cả độ cao camera ngắm (aimPitch)"); sys.exit(1)
print("PASS: kéo một ngón điều khiển hướng ngắm + độ cao camera")

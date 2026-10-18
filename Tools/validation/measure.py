#!/usr/bin/env python3
"""Tầng 3 — đo bàn thật bằng video iPhone 240 fps (UPGRADE.md 3.3, docs/07-validation.md).

Chỉ phụ thuộc numpy. Các bước cần OpenCV (phát hiện bàn cờ, sửa méo ống kính) nằm trong
`camera_calibration_opencv()` và chỉ chạy khi có cv2.

Nội dung:
- Ma trận chiếu P (3×4) từ ≥ 6 điểm 3D đã biết (DLT): kim cương ở mặt khung (cao hơn nỉ) và
  góc lỗ ở mặt nỉ — hai độ cao khác nhau nên giải được cả độ sâu.
- Phép chiếu phối cảnh cho MẶT PHẲNG TÂM BI (z = R), không phải mặt nỉ: H = [p1, p2, p4 + R·p3].
- Bám tâm bi trên khung hình (ngưỡng màu + trọng tâm).
- Độ không chắc chắn của hệ đo (k = 2) và quy tắc tuyên bố đạt KPI (≤ 1/3 ngưỡng).
- Chia tập hiệu chỉnh / kiểm chứng xác định theo seed, TRƯỚC khi xem kết quả.
- Hiệu chỉnh cản lăn và phục hồi băng; xuất CalibrationProfile JSON đọc được bởi app.
"""
import datetime as _dt
import hashlib
import json
import math

import numpy as np


# ---------------------------------------------------------------------------
# Hình học camera
# ---------------------------------------------------------------------------
def projection_dlt(world_xyz, image_uv):
    """Ma trận chiếu P (3×4) từ ≥ 6 cặp điểm 3D ↔ 2D (DLT có chuẩn hóa Hartley)."""
    X = np.asarray(world_xyz, float)
    x = np.asarray(image_uv, float)
    if len(X) < 6:
        raise ValueError("cần ít nhất 6 điểm, không đồng phẳng")

    def norm2(p):
        c = p.mean(0)
        s = math.sqrt(2) / np.mean(np.linalg.norm(p - c, axis=1))
        return np.array([[s, 0, -s * c[0]], [0, s, -s * c[1]], [0, 0, 1]])

    def norm3(p):
        c = p.mean(0)
        s = math.sqrt(3) / np.mean(np.linalg.norm(p - c, axis=1))
        T = np.eye(4)
        T[:3, :3] *= s
        T[:3, 3] = -s * c
        return T

    T2, T3 = norm2(x), norm3(X)
    Xh = (T3 @ np.c_[X, np.ones(len(X))].T).T
    xh = (T2 @ np.c_[x, np.ones(len(x))].T).T
    rows = []
    for (Xw, Yw, Zw, Ww), (u, v, w) in zip(Xh, xh):
        P = [Xw, Yw, Zw, Ww]
        rows.append([0, 0, 0, 0] + [-w * c for c in P] + [v * c for c in P])
        rows.append([w * c for c in P] + [0, 0, 0, 0] + [-u * c for c in P])
    _, _, Vt = np.linalg.svd(np.array(rows))
    Pn = Vt[-1].reshape(3, 4)
    P = np.linalg.inv(T2) @ Pn @ T3
    return P / np.linalg.norm(P[2, :3])


def plane_homography(P, z):
    """Phép chiếu từ ảnh về mặt phẳng z = const (ví dụ z = R cho tâm bi)."""
    H_world_to_img = np.c_[P[:, 0], P[:, 1], P[:, 3] + z * P[:, 2]]
    return np.linalg.inv(H_world_to_img)


def image_to_plane(H_img_to_plane, uv):
    uv = np.atleast_2d(np.asarray(uv, float))
    p = (H_img_to_plane @ np.c_[uv, np.ones(len(uv))].T).T
    return p[:, :2] / p[:, 2:3]


def project(P, xyz):
    xyz = np.atleast_2d(np.asarray(xyz, float))
    p = (P @ np.c_[xyz, np.ones(len(xyz))].T).T
    return p[:, :2] / p[:, 2:3]


def camera_calibration_opencv(images, board=(9, 6), square_mm=25.0):  # pragma: no cover - cần cv2
    """Hiệu chỉnh méo ống kính bằng bàn cờ (cần OpenCV). Trả về (K, dist, rms)."""
    import cv2
    objp = np.zeros((board[0] * board[1], 3), np.float32)
    objp[:, :2] = np.mgrid[0:board[0], 0:board[1]].T.reshape(-1, 2) * square_mm / 1000
    obj, img = [], []
    size = None
    for im in images:
        gray = cv2.cvtColor(im, cv2.COLOR_BGR2GRAY)
        size = gray.shape[::-1]
        ok, corners = cv2.findChessboardCorners(gray, board)
        if ok:
            corners = cv2.cornerSubPix(gray, corners, (11, 11), (-1, -1),
                                       (cv2.TERM_CRITERIA_EPS + cv2.TERM_CRITERIA_MAX_ITER, 30, 1e-3))
            obj.append(objp)
            img.append(corners)
    if len(obj) < 8:
        raise ValueError("cần ít nhất 8 ảnh bàn cờ nhận được")
    rms, K, dist, _, _ = cv2.calibrateCamera(obj, img, size, None, None)
    return K, dist, rms


# ---------------------------------------------------------------------------
# Bám bi
# ---------------------------------------------------------------------------
def ball_centroid(frame_rgb, target_rgb, tolerance=40, min_pixels=12):
    """Tâm (u, v) của vùng có màu gần `target_rgb` (đơn giản, cho bi cái trắng/bi màu trên nỉ xanh)."""
    f = np.asarray(frame_rgb, float)
    d = np.linalg.norm(f - np.asarray(target_rgb, float), axis=2)
    mask = d < tolerance
    if mask.sum() < min_pixels:
        return None
    vs, us = np.nonzero(mask)
    return float(us.mean()), float(vs.mean())


def track(frames, target_rgb, fps, H_img_to_plane, **kw):
    """Quỹ đạo [(t, x, y)] trên mặt phẳng tâm bi."""
    out = []
    for k, fr in enumerate(frames):
        c = ball_centroid(fr, target_rgb, **kw)
        if c is not None:
            x, y = image_to_plane(H_img_to_plane, c)[0]
            out.append((k / fps, float(x), float(y)))
    return out


def initial_velocity(track_points, n=8):
    """Vận tốc đầu (m/s) và hướng (rad) bằng hồi quy tuyến tính n điểm đầu."""
    pts = np.asarray(track_points[:n], float)
    t, x, y = pts[:, 0], pts[:, 1], pts[:, 2]
    vx = np.polyfit(t, x, 1)[0]
    vy = np.polyfit(t, y, 1)[0]
    return math.hypot(vx, vy), math.atan2(vy, vx)


# ---------------------------------------------------------------------------
# Độ không chắc chắn và quy tắc tuyên bố
# ---------------------------------------------------------------------------
def static_position_uncertainty(points_xy, k=2.0):
    """Độ không chắc chắn mở rộng (k = 2) của vị trí từ bi đứng yên qua nhiều khung (m)."""
    p = np.asarray(points_xy, float)
    sd = np.std(p - p.mean(0), axis=0, ddof=1)
    return k * float(math.hypot(*sd))


def direction_uncertainty(position_u, baseline):
    """Độ không chắc chắn góc hướng (độ) khi đo hướng từ hai vị trí cách nhau `baseline` m."""
    return math.degrees(math.atan2(math.sqrt(2) * position_u, baseline))


def can_claim(threshold, measurement_u):
    """Chỉ tuyên bố đạt ngưỡng khi độ không chắc chắn đo ≤ 1/3 ngưỡng (UPGRADE.md 3.3)."""
    return measurement_u <= threshold / 3.0


# ---------------------------------------------------------------------------
# Chia tập, hiệu chỉnh, xuất hồ sơ
# ---------------------------------------------------------------------------
def split_trials(trial_ids, seed):
    """Chia 50/50 xác định theo seed. Trả về (hiệu_chỉnh, kiểm_chứng, dấu_vân_tay)."""
    ids = sorted(trial_ids)
    keyed = sorted(ids, key=lambda i: hashlib.sha256(f"{seed}:{i}".encode()).hexdigest())
    half = len(keyed) // 2
    cal, val = sorted(keyed[:half]), sorted(keyed[half:])
    fp = hashlib.sha256(json.dumps([seed, cal, val]).encode()).hexdigest()[:16]
    return cal, val, fp


def fit_rolling_resistance(speeds, distances, g=9.81):
    """Bi lăn thuần: d = v²/(2·μr·g) → μr bình phương tối thiểu theo d. Trả về (μr, sai số dư tương đối)."""
    v2 = np.asarray(speeds, float) ** 2
    d = np.asarray(distances, float)
    a = float(np.dot(v2, d) / np.dot(v2, v2))      # d ≈ a·v², a = 1/(2μg)
    mu = 1.0 / (2 * g * a)
    resid = float(np.median(np.abs(a * v2 - d) / d))
    return mu, resid


def fit_cushion_restitution(v_in_normal, v_out_normal):
    """e ≈ v_out/v_in theo pháp tuyến (bi lăn, mô hình đơn giản hóa). Trả về (e, sai số dư tương đối)."""
    vi = np.asarray(v_in_normal, float)
    vo = np.asarray(v_out_normal, float)
    e = float(np.dot(vi, vo) / np.dot(vi, vi))
    resid = float(np.median(np.abs(e * vi - vo) / vo))
    return e, resid


def calibration_profile(table_id, conditions, fits, when=None):
    """CalibrationProfile JSON khớp Codable của Swift (Provenance.measured)."""
    when = when or _dt.datetime.now(_dt.timezone.utc).replace(microsecond=0)
    overrides = {}
    for key, (value, method, samples, residual) in fits.items():
        overrides[key] = {"value": value,
                          "provenance": {"measured": {"method": method, "samples": samples, "residual": residual}}}
    return {"schemaVersion": 1, "tableId": table_id,
            "measuredAt": when.strftime("%Y-%m-%dT%H:%M:%SZ"),
            "conditions": conditions, "overrides": overrides}

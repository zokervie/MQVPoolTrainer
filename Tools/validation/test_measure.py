"""Kiểm thử công cụ đo trên dữ liệu tổng hợp (chạy: python -m unittest discover Tools/validation)."""
import math
import os
import sys
import unittest

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import measure as m  # noqa: E402

L, W, R = 2.54, 1.27, 0.028575
RAIL_TOP = 0.045   # độ cao mặt khung có kim cương (giả định cho kiểm thử)


def synthetic_camera():
    """Camera nghiêng nhìn xuống bàn từ phía đầu bàn."""
    K = np.array([[1500, 0, 960], [0, 1500, 540], [0, 0, 1.0]])
    eye = np.array([-0.6, W / 2, 1.6])
    target = np.array([L / 2, W / 2, 0])
    f = target - eye; f /= np.linalg.norm(f)
    up = np.array([0, 0, 1.0])
    r = np.cross(f, up); r /= np.linalg.norm(r)
    u = np.cross(r, f)
    Rm = np.vstack([r, -u, f])
    t = -Rm @ eye
    return K @ np.c_[Rm, t]


def reference_points():
    pts = []
    for k in range(1, 8):
        pts += [(k * L / 8, -0.05, RAIL_TOP), (k * L / 8, W + 0.05, RAIL_TOP)]
    pts += [(0, 0, 0), (L, 0, 0), (0, W, 0), (L, W, 0), (L / 2, 0, 0), (L / 2, W, 0)]
    return np.array(pts)


class GeometryTests(unittest.TestCase):
    def test_projection_and_ball_plane(self):
        P_true = synthetic_camera()
        Xw = reference_points()
        uv = m.project(P_true, Xw) + np.random.default_rng(1).normal(0, 0.3, (len(Xw), 2))
        P = m.projection_dlt(Xw, uv)
        H = m.plane_homography(P, R)
        balls = np.array([(0.5, 0.4, R), (1.9, 1.0, R), (1.27, 0.635, R)])
        rec = m.image_to_plane(H, m.project(P_true, balls))
        err = np.linalg.norm(rec - balls[:, :2], axis=1).max()
        self.assertLess(err, 0.003, f"sai số {err*1000:.2f} mm")

    def test_ignoring_ball_height_is_biased(self):
        """Dựng phép chiếu trên mặt nỉ (z = 0) cho tâm bi gây sai lệch hệ thống — lý do phải dùng z = R."""
        P = synthetic_camera()
        balls = np.array([(0.5, 0.4, R), (1.9, 1.0, R)])
        wrong = m.image_to_plane(m.plane_homography(P, 0.0), m.project(P, balls))
        bias = np.linalg.norm(wrong - balls[:, :2], axis=1).max()
        self.assertGreater(bias, 0.01)


class TrackingTests(unittest.TestCase):
    def test_centroid_and_velocity(self):
        fps = 240
        frames = []
        for k in range(20):
            img = np.zeros((120, 200, 3)); img[:] = (20, 90, 50)
            cx, cy = 30 + 2.0 * k, 60
            yy, xx = np.mgrid[0:120, 0:200]
            img[(xx - cx) ** 2 + (yy - cy) ** 2 <= 36] = (240, 240, 235)
            frames.append(img)
        H = np.diag([0.001, 0.001, 1.0])   # 1 px = 1 mm
        tr = m.track(frames, (240, 240, 235), fps, H)
        self.assertEqual(len(tr), 20)
        v, ang = m.initial_velocity(tr)
        self.assertAlmostEqual(v, 2.0 * 0.001 * fps, delta=0.01)
        self.assertAlmostEqual(ang, 0.0, delta=0.01)


class UncertaintyTests(unittest.TestCase):
    def test_claim_rule(self):
        rng = np.random.default_rng(3)
        pts = rng.normal(0, 0.0005, (240, 2)) + (1.0, 0.5)
        u = m.static_position_uncertainty(pts)
        self.assertAlmostEqual(u, 2 * math.hypot(0.0005, 0.0005), delta=0.0003)
        du = m.direction_uncertainty(u, 1.0)
        self.assertTrue(m.can_claim(0.5, du) == (du <= 0.5 / 3))
        self.assertFalse(m.can_claim(0.5, 0.2))
        self.assertTrue(m.can_claim(0.5, 0.15))


class CalibrationTests(unittest.TestCase):
    def test_split_is_deterministic_and_disjoint(self):
        a = m.split_trials(range(40), seed=7)
        b = m.split_trials(range(40), seed=7)
        self.assertEqual(a, b)
        self.assertFalse(set(a[0]) & set(a[1]))
        self.assertEqual(len(a[0]) + len(a[1]), 40)
        self.assertNotEqual(m.split_trials(range(40), seed=8)[2], a[2])

    def test_fit_rolling_resistance(self):
        rng = np.random.default_rng(5)
        v = rng.uniform(0.5, 1.5, 20)
        d = v ** 2 / (2 * 0.009 * 9.81) * (1 + rng.normal(0, 0.01, 20))
        mu, res = m.fit_rolling_resistance(v, d)
        self.assertAlmostEqual(mu, 0.009, delta=0.0003)
        self.assertLess(res, 0.03)

    def test_profile_json_shape(self):
        p = m.calibration_profile("zoker-9ft-v1", "nỉ mới", {"rollingResistance": (0.009, "máng lăn", 10, 0.02)})
        self.assertEqual(p["overrides"]["rollingResistance"]["provenance"]["measured"]["samples"], 10)
        self.assertTrue(p["measuredAt"].endswith("Z"))


if __name__ == "__main__":
    unittest.main()

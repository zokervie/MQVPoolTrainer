// 0.59 "Thang 5 sao" (BankLab/UI/Mastery059.h): star scale, round length, take-back fund, start aim offset and the
// 5-layout pose set. Rules: owner approval 24/11/2026. The physics is used only to prove every pose is playable.
#include "../BankLab/Core/PoseCheck.hpp"
#include <chrono>
#include <cstdio>
#include <iostream>
#include <set>
#include <string>
using namespace banklab;
static int fails = 0, checks = 0;
static void check(bool ok, const std::string& what) { ++checks; if (!ok) { ++fails; std::cerr << "FAIL: " << what << "\n"; } }
static std::string S(long v) { return std::to_string(v); }

// Chance of at least `need` made of `n` at make rate p (binomial).
static double atLeast(int n, int need, double p) {
    double sum = 0, c = 1;
    for (int k = 0; k <= n; ++k) {
        if (k > 0) c = c * (n - k + 1) / k;
        if (k >= need) sum += c * std::pow(p, k) * std::pow(1 - p, n - k);
    }
    return sum;
}
int main() {
    // ── stars ──
    for (int m = 0; m <= 5; ++m) check(BLRoundStars5(1, m, 0) == m && BLRoundStars5(2, m, 3) == m, "ch1–2: stars = shots made, take-backs free (" + S(m) + ")");
    check(BLRoundStars5(1, 9, 0) == 5 && BLRoundStars5(1, -3, 0) == 0, "ch1: clamped");
    check(BLRoundStars5(3, 5, 0) == 5 && BLRoundStars5(3, 5, 1) == 4 && BLRoundStars5(4, 3, 2) == 3, "ch3–4: a take-back caps at 4");
    const int s56[11] = {0, 0, 1, 1, 2, 2, 3, 3, 4, 5, 5}, s7[11] = {0, 0, 0, 1, 1, 2, 2, 3, 3, 4, 5};
    for (int m = 0; m <= 10; ++m) {
        check(BLRoundStars5(5, m, 0) == s56[m] && BLRoundStars5(6, m, 0) == s56[m], "ch5–6 table at " + S(m) + "/10");
        check(BLRoundStars5(7, m, 0) == s7[m] && BLRoundStars5(11, m, 0) == s7[m], "ch7+ table at " + S(m) + "/10");
    }
    check(BLRoundStars5(5, 10, 1) == 3 && BLRoundStars5(8, 10, 1) == 3 && BLRoundStars5(8, 5, 1) == 2, "ch5+: a take-back caps at 3");
    for (int c = 1; c <= 12; ++c) {
        int prev = -1; bool mono = true;
        for (int m = 0; m <= BLRoundShots(c); ++m) { const int s = BLRoundStars5(c, m, 0); mono = mono && s >= prev; prev = s; }
        check(mono && prev == 5 && BLRoundStars5(c, 0, 0) == 0, "ch" + S(c) + ": stars rise with shots made, 0…5");
        check(BLRoundShots(c) == (c <= 4 ? 5 : 10), "ch" + S(c) + ": round length");
        const int m3 = BLMadeForStars5(c, 3);
        check(m3 <= BLRoundShots(c) && BLRoundStars5(c, m3, 0) >= 3 && BLRoundStars5(c, m3 - 1, 0) < 3, "ch" + S(c) + ": made needed for 3 stars is exact");
    }
    check(BLMadeForStars5(1, 3) == 3 && BLMadeForStars5(5, 3) == 6 && BLMadeForStars5(7, 3) == 7 && BLMadeForStars5(5, 5) == 9 &&
          BLMadeForStars5(7, 5) == 10, "next ring: 3/5, 6/10 (ch5–6), 7/10 (ch7+); five stars 5/5, 9/10, 10/10");
    check(BLTierOpen5(1, 0) && !BLTierOpen5(2, 2) && BLTierOpen5(2, 3) && BLTierOpen5(3, 5), "next ring opens at 3 stars");
    check(BLWarmupMadeFor(1) == 5 && BLWarmupMadeFor(6) == 5 && BLWarmupMadeFor(7) == 0, "warm-up in ch1–6 only");
    check(BLRoundUndoLimit(6) == -1 && BLRoundUndoLimit(7) == 1 && BLRoundUndoLimit(12) == 1, "one take-back per round from ch7");

    // ── take-back fund ──
    check(BLChapterUndoFund(1, 27, 5) == -1 && BLChapterUndoFund(1, 3, 10) == -1, "ch1 unlimited");
    const int owner[] = {0, 0, 100, 70, 50, 30};
    for (int c = 2; c <= 5; ++c) check(BLChapterUndoFund(c, 27, 5) == owner[c], "27×5 reproduces the owner's fund in ch" + S(c));
    check(BLChapterUndoFund(6, 27, 5) == 24 && BLChapterUndoFund(7, 27, 5) == 20 && BLChapterUndoFund(8, 27, 5) == 16 &&
          BLChapterUndoFund(9, 27, 5) == 14 && BLChapterUndoFund(12, 27, 5) == 14, "ch6–9+ at 27×5: 24/20/16/14");
    check(BLChapterUndoFund(3, 9, 5) == 23 && BLChapterUndoFund(5, 9, 10) == 20 && BLChapterUndoFund(9, 1, 5) == 1,
          "fund scales with the chapter's shots, never below 1");
    check(BLChapterUndoFund(4, 0, 0) == 50, "unknown size → 27×5");
    for (int c = 3; c <= 12; ++c) check(BLChapterUndoFund(c, 27, 5) <= BLChapterUndoFund(c - 1, 27, 5), "fund never grows with the chapter (ch" + S(c) + ")");
    check(BLChapterUndoFundLeft(2, 27, 5, 99) == 1 && BLChapterUndoFundLeft(2, 27, 5, 400) == 0 && BLChapterUndoFundLeft(1, 27, 5, 9) == -1 &&
          BLChapterUndoFundLeft(3, 27, 5, -4) == 70, "fund left never negative");

    // ── completion and migration ──
    { const int32_t a[3] = {5, 5, 5}, b[4] = {5, 0, 3, 2}, c[2] = {9, -1};
      check(BLChapterPercent5(a, 3) == 100 && BLChapterPercent5(b, 4) == 50 && BLChapterPercent5(c, 2) == 50 && BLChapterPercent5(nullptr, 2) == 0,
            "chapter % = best stars / (5 × rungs)"); }
    check(BLStarsMigrate058(1, 3, 5) == 5 && BLStarsMigrate058(1, 3, 4) == 4 && BLStarsMigrate058(1, 1, 2) == 2 && BLStarsMigrate058(1, 2, 2) == 3,
          "migration: recomputed from the best round's made, never below the conservative map");
    check(BLStarsMigrate058(1, 0, -1) == 0 && BLStarsMigrate058(1, 1, -1) == 2 && BLStarsMigrate058(1, 3, -1) == 4, "migration without made: 1→2, 3→4");

    // ── start aim offset ──
    for (int c = 1; c <= 9; ++c) {
        double lo, hi; BLAimOffsetBand(c, &lo, &hi);
        int pos = 0, neg = 0; bool inBand = true, same = true;
        for (int r = 0; r < 20; ++r) for (int s = 0; s < 10; ++s) {
            const double o = BLStartAimOffsetDeg("cut-30-r", c, r, s);
            if (c == 1) { inBand = inBand && o == 0; continue; }
            const double a = std::fabs(o);
            inBand = inBand && a >= std::max(lo, BL_AIM_OFFSET_FLOOR_DEG) - 1e-9 && a <= hi + 1e-9;
            pos += o > 0; neg += o < 0;
            same = same && o == BLStartAimOffsetDeg("cut-30-r", c, r, s);
        }
        check(inBand && same, "ch" + S(c) + ": start aim offset in band, deterministic");
        if (c > 1) check(pos > 40 && neg > 40, "ch" + S(c) + ": offset goes both ways (" + S(pos) + "/" + S(neg) + ")");
    }
    check(!BLStartTipCentred(4) && BLStartTipCentred(5) && !BLStartCameraStanding(6) && BLStartCameraStanding(7), "tip centred from ch5, standing camera from ch7");

    // ── pose order ──
    for (int r = 0; r < 30; ++r) {
        int32_t o[BL_POSE_COUNT]; BLRoundPoseOrder("force-near-1", r, o);
        std::set<int> u(o, o + BL_POSE_COUNT);
        check(u.size() == 5 && *u.begin() == 0 && *u.rbegin() == 4, "round " + S(r) + ": a permutation of the 5 poses");
        std::set<int> first, second;
        for (int s = 0; s < 10; ++s) (s < 5 ? first : second).insert(BLRoundPose("force-near-1", r, s));
        check(first.size() == 5 && second.size() == 5, "round of 10: each half plays the whole set");
    }
    { BLDrillLayout a, b; const BLDrillSpec* f = BLDrillAt(BLDrillIndex("force-near-1"));
      check(BLDrillPoseCandidate(f, 1, 3, &a) == 0, "chapter 1 has no candidates (force control keeps one layout)");
      BLDrillPoseFor(f, 3, &a); BLDrillLayoutFor(f, 0, &b);
      check(a.x[0] == b.x[0] && a.y[0] == b.y[0] && BLPoseSetSize("force-near-1") == 1, "chapter 1 keeps one layout"); }

    // ── candidate geometry: legal, inside the chapter's band, both sides ──
    for (int32_t i = 0; i < BLDrillCount(); ++i) {
        const BLDrillSpec* d = BLDrillAt(i);
        if (d->chapter < 2 || d->chapter > 5 || d->kind != BL_DRILL_GOAL || d->solveSpeed <= 0) continue;
        const BLPoseBand band = BLPoseBandFor(d->chapter);
        BLDrillLayout base; BLDrillLayoutFor(d, 0, &base);
        int32_t cue, obj; double gx = 0, gy = 0; const int ghost = BLDrillGhost(d, &gx, &gy, &cue, &obj);
        check(ghost == 1, std::string(d->key) + ": ghost-ball point of the reference stroke found");
        int made = 0, left = 0, right = 0;
        for (int c = 1; c <= 24; ++c) {
            BLDrillLayout L;
            if (!BLDrillPoseCandidate(d, d->chapter, c, &L)) continue;
            ++made;
            check(BLPoseValid(d, &L, cue, obj, gx, gy), std::string(d->key) + ": candidate " + S(c) + " legal");
            const double a0 = std::atan2(gy - base.y[cue], gx - base.x[cue]), a1 = std::atan2(gy - L.y[cue], gx - L.x[cue]);
            const double turn = std::remainder(a1 - a0, 2 * pi) * 180 / pi;
            const double limit = band.cutDeg > 0 ? band.cutDeg : std::atan2(band.shiftMax, 0.12) * 180 / pi;
            check(std::fabs(turn) <= limit + 1e-6, std::string(d->key) + ": candidate " + S(c) + " turn " + std::to_string(turn) + "° in band");
            (turn > 0 ? left : right) += 1;
        }
        check(made >= 12 && left >= 4 && right >= 4, std::string(d->key) + ": candidates on both sides (" + S(left) + "/" + S(right) + ")");
    }

    // ── the stored set (DrillPoseData.h, picked by Tools/drills/pose_pick): re-proven with the same rating ──
    // Bar (owner: "khả thi để hoàn thành"): each pose made, make rate within 10 points of the catalogue layout's.
    const auto t0 = std::chrono::steady_clock::now();
    int sets = 0, poses = 0;
    for (size_t i = 0; i < sizeof(BLPoseSets) / sizeof(BLPoseSets[0]); ++i) {
        const BLPoseSet& ps = BLPoseSets[i];
        if (!ps.key) continue;
        ++sets;
        const int32_t di = BLDrillIndex(ps.key);
        check(di >= 0, std::string(ps.key) + ": pose set names a catalogue drill");
        if (di < 0) continue;
        const BLDrillSpec* d = BLDrillAt(di);
        check(ps.chapter == d->chapter, std::string(ps.key) + ": pose set chapter matches the catalogue");
        std::vector<std::pair<double, double>> spots;
        int32_t cue = 0; for (int k = 0; k < d->ballCount; ++k) if (d->balls[k].id == 0) cue = k;
        for (int p = 0; p < BL_POSE_COUNT; ++p) {
            BLDrillLayout L; BLDrillPoseFor(d, p, &L);
            if (p == 0 || ps.cand[p - 1] > 0) {
                for (auto& q : spots) check(std::hypot(L.x[cue] - q.first, L.y[cue] - q.second) >= BL_POSE_MIN_APART - 1e-9,
                                            std::string(ps.key) + ": pose " + S(p) + " at least 1.5 cm from every other pose");
                spots.push_back({L.x[cue], L.y[cue]});
            }
            if (p == 0 || ps.cand[p - 1] <= 0) continue;
            ++poses;
            const PoseStroke r = poseRateStroke(*d, L, poseReferenceAim(*d, L) + ps.aimDelta[p - 1], ps.speed[p - 1], ps.top[p - 1], 200);
            check(r.percent > 0, std::string(ps.key) + ": pose " + S(p) + " made by its stored stroke");
            check(std::abs(r.percent - ps.basePercent) <= 10, std::string(ps.key) + ": pose " + S(p) + " make " + S(r.percent) +
                  " % within 10 of the catalogue layout's " + S(ps.basePercent) + " %");
            check(std::abs(r.percent - ps.percent[p - 1]) <= 3, std::string(ps.key) + ": pose " + S(p) + " reproduces its stored rate (" +
                  S(r.percent) + " vs " + S(ps.percent[p - 1]) + ")");
        }
        check((int)spots.size() == BLPoseSetSize(ps.key), std::string(ps.key) + ": set size matches the stored picks");
    }
    std::printf("pose sets %d, stored poses re-proven %d, %.1f s\n", sets, poses,
                std::chrono::duration<double>(std::chrono::steady_clock::now() - t0).count());

    // ── the rule's own difficulty (information; the rungs set the real difficulty) ──
    std::printf("chance of 5 stars at make rate p, no take-back:\n");
    for (double p : {0.6, 0.7, 0.8, 0.9})
        std::printf("  p=%.1f  ch1–4 %3.0f %%  ch5–6 %3.0f %%  ch7+ %3.0f %%\n", p, 100 * atLeast(5, 5, p), 100 * atLeast(10, 9, p), 100 * atLeast(10, 10, p));
    check(atLeast(10, 10, 0.8) < atLeast(5, 5, 0.8), "ch7+ five stars is harder than ch1–4 at the same accuracy");

    std::cout << (fails ? "Mastery059Tests: FAIL " : "Mastery059Tests: PASS ") << checks - fails << "/" << checks << "\n";
    return fails ? 1 : 0;
}

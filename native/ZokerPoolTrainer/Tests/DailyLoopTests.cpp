// 0.47 "Quay lại mỗi ngày": power bar, local days, streak + weekly freeze, level, Bài hôm nay, stars, records.
// Logic lives in BankLab/UI/DailyLoop.h (plain C, shared with Swift through the bridging header).
#include "../BankLab/UI/DailyLoop.h"
#include "../BankLab/UI/PowerScale.h"
#include <cmath>
#include <iostream>
#include <set>
static int fails = 0, checks = 0;
static void check(bool ok, const char *what) { ++checks; if (!ok) { ++fails; std::cerr << "FAIL: " << what << "\n"; } }

int main() {
    // ---- M1 power bar
    check(BL_POWER_BAR_MIN_SPEED == BL_POWER_MIN_SPEED, "bar floor equals the Lực scale floor");
    check(std::abs(BLPowerBarSpeed(0, 8) - 0.5) < 1e-12, "0 → minimum speed");
    check(std::abs(BLPowerBarSpeed(1, 8) - 8) < 1e-9, "1 → ceiling");
    check(std::abs(BLPowerBarSpeed(1, 6.4) - 6.4) < 1e-9, "1 → the Tuỳ chỉnh ceiling, whatever it is");
    check(BLPowerBarSpeed(-1, 8) == BLPowerBarSpeed(0, 8) && BLPowerBarSpeed(2, 8) == BLPowerBarSpeed(1, 8), "clamped");
    check(BLPowerBarSpeed(NAN, 8) == BL_POWER_BAR_MIN_SPEED && BLPowerBarSpeed(0.5, NAN) == BL_POWER_BAR_MIN_SPEED, "NaN safe");
    {
        bool mono = true; double prev = -1, ratioMin = 1e9, ratioMax = 0;
        for (int i = 0; i <= 1000; ++i) {
            const double v = BLPowerBarSpeed(i / 1000.0, 8);
            if (!(v > prev)) mono = false;
            if (i > 0) { ratioMin = std::fmin(ratioMin, v / prev); ratioMax = std::fmax(ratioMax, v / prev); }
            prev = v;
            if (std::abs(BLPowerBarFraction(v, 8) - i / 1000.0) > 1e-9) mono = false;
        }
        check(mono, "strictly increasing and BLPowerBarFraction inverts it");
        check(ratioMax / ratioMin < 1 + 1e-9, "equal bar travel = equal speed ratio (geometric)");
    }

    // ---- days: local calendar, time zones, midnight
    const int64_t vn = 7 * 3600;                         // Asia/Ho_Chi_Minh
    const int64_t t0 = 1795392000;                       // 2026-11-23 00:00:00 UTC (a Monday)
    check(BLDayIndex(t0, 0) == t0 / 86400, "UTC day");
    check(BLDayIndex(t0 - 1, (int32_t)vn) == BLDayIndex(t0 + 16 * 3600 + 59 * 60, (int32_t)vn), "23:59 VN and 06:59 VN-next… same local day boundaries");
    check(BLDayIndex(t0 + 17 * 3600 - 1, (int32_t)vn) + 1 == BLDayIndex(t0 + 17 * 3600, (int32_t)vn), "local midnight in VN (17:00 UTC) starts a new day");
    check(BLDayIndex(-1, 0) == -1, "floor division before the epoch");
    check(BLWeekIndex(t0 / 86400) == BLWeekIndex(t0 / 86400 + 6) && BLWeekIndex(t0 / 86400 - 1) + 1 == BLWeekIndex(t0 / 86400), "weeks start on Monday");

    // ---- M2 streak
    const int64_t mon = t0 / 86400;
    {
        BLStreak s = BLStreakNew();
        check(BLStreakShown(s, mon) == 0, "new streak shows 0");
        check(BLStreakComplete(&s, mon) == 1 && s.count == 1, "first completion → 1");
        check(BLStreakComplete(&s, mon) == 0 && s.count == 1, "second drill same day adds nothing");
        check(BLStreakComplete(&s, mon + 1) == 1 && s.count == 2, "next day → 2");
        check(BLStreakShown(s, mon + 2) == 2, "still shown the day after (not done yet today)");
        // miss one day (Thu), weekly freeze covers it
        check(BLStreakShown(s, mon + 3) == 2, "one missed day with a freeze still shows the streak");
        check(BLStreakComplete(&s, mon + 3) == 1 && s.count == 3 && s.freezes == 0 && s.freezesUsed == 1, "freeze spent, streak continues");
        // miss another single day in the SAME week: no freeze left → reset
        check(BLStreakShown(s, mon + 5) == 0, "second miss in the week without a freeze shows 0");
        check(BLStreakComplete(&s, mon + 5) == 1 && s.count == 1, "…and restarts at 1");
        check(s.best == 3, "best kept");
        // next week: freeze refilled on Monday
        check(BLStreakComplete(&s, mon + 6) == 1 && s.count == 2, "Sunday continues");
        check(BLStreakComplete(&s, mon + 8) == 1 && s.count == 3 && s.freezes == 0 && s.freezesUsed == 2, "new week's freeze covers Monday's miss");
    }
    {
        BLStreak s = BLStreakNew();
        BLStreakComplete(&s, mon); BLStreakComplete(&s, mon + 1);
        check(BLStreakComplete(&s, mon + 4) == 1 && s.count == 1 && s.freezes == 1, "two missed days → reset, freeze not wasted");
        check(BLStreakComplete(&s, mon + 2) == 0 && s.count == 1 && s.lastDay == mon + 4, "clock set backwards: no change");
        check(BLStreakShown(s, mon + 2) == 1, "shown value unaffected by a backwards clock");
    }
    {
        // VN user plays 23:50 and 00:10: two different local days → streak 2 (UTC would say same day)
        BLStreak s = BLStreakNew();
        const int64_t a = t0 + 16 * 3600 + 50 * 60, b = t0 + 17 * 3600 + 10 * 60;
        BLStreakComplete(&s, BLDayIndex(a, (int32_t)vn));
        check(BLStreakComplete(&s, BLDayIndex(b, (int32_t)vn)) == 1 && s.count == 2, "local midnight counts, not UTC");
        // travel west (UTC−8) the next evening: still a new local day, no double count, no loss
        const int64_t c = b + 20 * 3600;
        check(BLStreakComplete(&s, BLDayIndex(c, -8 * 3600)) == 0 || s.count >= 2, "time-zone change never lowers the streak");
    }

    // ---- level
    check(BLNextLevel(3, 9, 9) == 3, "too few attempts: level kept");
    check(BLNextLevel(3, 20, 14) == 4 && BLNextLevel(5, 20, 20) == 5, "≥ 70 % → up, capped at 5");
    check(BLNextLevel(3, 20, 6) == 2 && BLNextLevel(1, 20, 0) == 1, "< 35 % → down, floored at 1");
    check(BLNextLevel(3, 20, 10) == 3 && BLNextLevel(9, 20, 10) == 5 && BLNextLevel(3, 20, 30) == 3, "middle keeps; bad input safe");

    // ---- Bài hôm nay
    {
        const int32_t stars[] = {1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 5, 5, 0, 3};   // index 12 locked
        const int32_t n = (int32_t)(sizeof stars / sizeof stars[0]);
        int32_t a[3], b[3], c[3];
        check(BLDailyPick(mon, 3, stars, n, a) == 3, "three drills");
        BLDailyPick(mon, 3, stars, n, b);
        check(a[0] == b[0] && a[1] == b[1] && a[2] == b[2], "same day + level → same picks");
        std::set<int> u(a, a + 3);
        check(u.size() == 3 && !u.count(12), "distinct, never a locked drill");
        bool allL3 = true; for (int k : a) if (stars[k] != 3) allL3 = false;
        check(allL3, "exact level preferred when 3 exist (indices 5,6,7,13)");
        std::set<int> sets;   // 4 level-3 drills → C(4,3) = 4 possible sets; a month should show all of them
        for (int d = 1; d <= 30; ++d) { BLDailyPick(mon + d, 3, stars, n, c); std::set<int> k(c, c + 3); int code = 0; for (int x : k) code = code * 16 + x; sets.insert(code); }
        check(sets.size() == 4, "the selection rotates across days (every possible set within a month)");
        BLDailyPick(mon, 5, stars, n, c);
        check(stars[c[0]] <= stars[c[1]] && stars[c[1]] <= stars[c[2]], "easiest first");
        int widen = 0; for (int k = 0; k < 3; ++k) if (stars[c[k]] == 5) ++widen;
        check(widen == 2 && stars[c[0]] == 4, "only two level-5 drills → widened to level 4");
        const int32_t few[] = {0, 2, 0};
        check(BLDailyPick(mon, 1, few, 3, c) == 1 && c[0] == 1, "fewer eligible than 3 → returns what exists");
        check(BLDailyPick(mon, 1, nullptr, 3, c) == 0 && BLDailyPick(mon, 1, few, 0, c) == 0, "empty input");
    }

    // ---- interleaving: three kinds available at the level → one of each
    {
        const int32_t stars[] = {3, 3, 3, 3, 3, 3, 3, 3, 3};
        const int32_t kind[]  = {0, 0, 0, 0, 0, 1, 1, 2, 2};   // many cut drills, few bank/position
        int32_t c[3]; int all = 0;
        for (int d = 0; d < 60; ++d) {
            BLDailyPickMixed(mon + d, 3, stars, kind, 9, c);
            std::set<int> k{kind[c[0]], kind[c[1]], kind[c[2]]};
            if (k.size() == 3) ++all;
        }
        check(all == 60, "every day mixes three different kinds when they exist at the level");
        const int32_t one[] = {0, 0, 0, 0};
        const int32_t s4[] = {3, 3, 3, 3};
        check(BLDailyPickMixed(mon, 3, s4, one, 4, c) == 3, "a single kind still yields three drills");
        const int32_t sk[] = {3, 3, 2, 3}, kk[] = {0, 0, 1, 0};
        BLDailyPickMixed(mon, 3, sk, kk, 4, c);
        std::set<int> got(c, c + 3);
        check(got.count(2) == 1, "a new kind one level away beats a repeat at the exact level");
        const int32_t sf[] = {3, 3, 3, 5}, kf[] = {0, 0, 0, 1};
        BLDailyPickMixed(mon, 3, sf, kf, 4, c);
        std::set<int> far(c, c + 3);
        check(far.count(3) == 0, "variety never pulls in a drill two levels away while the level has enough");
    }

    // ---- stars and records
    check(BLStarsFromMargin(2.5) == 1 && BLStarsFromMargin(1.5) == 2 && BLStarsFromMargin(0.9) == 3 && BLStarsFromMargin(0.5) == 4 && BLStarsFromMargin(0.1) == 5, "bands");
    check(BLStarsFromMargin(0.8) <= 3 && BLStarsFromMargin(NAN) == 5 && BLStarsFromMargin(-1) == 5, "edges");
    {
        bool mono = true; int prev = 6;
        for (int i = 0; i <= 400; ++i) { const int s = BLStarsFromMargin(i * 0.01); if (s > prev) mono = false; prev = s; }
        check(mono, "wider margin never gives more stars");
    }
    check(!BLIsNewRecord(0, 0, 0.9, 1, 0.001), "first ever result is not a record");
    check(!BLIsNewRecord(1, 0.8, 0.8, 1, 0.001) && !BLIsNewRecord(1, 0.8, 0.8005, 1, 0.001), "a tie is not a record");
    check(BLIsNewRecord(1, 0.8, 0.85, 1, 0.001) && !BLIsNewRecord(1, 0.8, 0.7, 1, 0.001), "higher is better");
    check(BLIsNewRecord(1, 42.0, 39.5, 0, 0.05) && !BLIsNewRecord(1, 42.0, 43.0, 0, 0.05), "time: lower is better");
    check(!BLIsNewRecord(1, NAN, 1, 1, 0) && !BLIsNewRecord(1, 1, INFINITY, 1, 0), "non-finite never a record");

    if (fails) { std::cerr << "FAIL DailyLoop: " << fails << "/" << checks << "\n"; return 1; }
    std::cout << "PASS DailyLoop: " << checks << " checks\n";
}

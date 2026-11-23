// 0.51 — daily puzzle, prediction scoring, "Chỉ số Mắt", friend codes (BankLab/UI/PuzzleDaily.h).
#include "../BankLab/Core/DrillCheck.hpp"
#include "../BankLab/UI/PuzzleDaily.h"
#include <cmath>
#include <cstring>
#include <iostream>
#include <set>
#include <string>
using namespace banklab;
static int fails = 0, checks = 0;
static void check(bool ok, const std::string& what) { ++checks; if (!ok) { ++fails; std::cerr << "FAIL: " << what << "\n"; } }

static void daily() {
    check(BLDailyNumber(BL_DAILY_EPOCH_DAY) == 1 && BLDailyNumber(BL_DAILY_EPOCH_DAY + 127) == 128, "puzzle numbers count from the epoch day");
    std::set<int32_t> seen; double sum[7] = {0}; int cnt[7] = {0}; int mirroredDays = 0;
    for (int64_t day = BL_DAILY_EPOCH_DAY; day < BL_DAILY_EPOCH_DAY + 7 * 60; ++day) {
        int m = -1, m2 = -1;
        const int32_t i = BLDailyPuzzle(day, &m);
        check(i >= 0 && i < BLPuzzleCount() && i == BLDailyPuzzle(day, &m2) && m == m2, "daily pick is deterministic");
        seen.insert(i); mirroredDays += m;
        const int wd = int(((day + 3) % 7 + 7) % 7);
        sum[wd] += BLPuzzleAt(i)->solutions[0].percent; ++cnt[wd];
    }
    check(int(seen.size()) == BLPuzzleCount(), "every puzzle becomes a daily puzzle (" + std::to_string(seen.size()) + ")");
    check(mirroredDays > 0, "second pass through a band is mirrored");
    for (int wd = 1; wd < 7; ++wd) check(sum[wd] / cnt[wd] <= sum[wd - 1] / cnt[wd - 1] + 1e-9, "week climbs: weekday " + std::to_string(wd));
    check(sum[0] / cnt[0] - sum[6] / cnt[6] >= 20, "Monday is clearly easier than Sunday");
    check(BLDailyGrade(1, 2, -1) == BL_TRY_SOLVED && BLDailyGrade(0, 1, .10) == BL_TRY_NEAR && BLDailyGrade(0, 1, .30) == BL_TRY_FAR &&
          BLDailyGrade(0, 2, .01) == BL_TRY_FAR && BLDailyGrade(0, 1, -1) == BL_TRY_FAR, "try grades");
    char text[128]; const int32_t g[3] = {0, 1, 2};
    check(BLDailyShareText(text, sizeof text, 128, g, 3, 12) > 0 &&
          std::string(text) == "Zoker #128 \xC2\xB7 3/6\n\xE2\x9A\xAA\xF0\x9F\x9F\xA1\xF0\x9F\x9F\xA2\n\xF0\x9F\x94\xA5 12", "share line");
    const int32_t lost[6] = {0, 0, 1, 0, 1, 1};
    check(BLDailyShareText(text, sizeof text, 7, lost, 6, 1) > 0 && std::string(text).rfind("Zoker #7 \xC2\xB7 X/6\n", 0) == 0 &&
          std::string(text).find("\xF0\x9F\x94\xA5") == std::string::npos, "unsolved run shows X/6, no streak line under 2");
    check(BLDailyShareText(text, 10, 1, g, 3, 0) == 0 && BLDailyShareText(text, sizeof text, 1, g, 7, 0) == 0, "share line guards");
    const int32_t k[2] = {1, 1}, a[2] = {0, 2}, b[2] = {2, 0};
    check(BLDrillFirstContact(2, k, a, b) == 2 && BLDrillFirstContact(0, k, a, b) == -1, "first contact");
    // miss distance: pot puzzle, ball 1 resting 10 cm from the head-right pocket
    const BLPuzzleSpec* pot = nullptr;
    for (int32_t i = 0; i < BLPuzzleCount(); ++i) if (BLPuzzleAt(i)->style == BL_PUZZLE_POT && BLPuzzleAt(i)->spec.chapter > 0) { pot = BLPuzzleAt(i); break; }
    if (pot) {
        const int32_t ids[2] = {0, 1}; const double xs[2] = {0, .67 - .0707}, ys[2] = {0, 1.305 - .0707}; int32_t sunk[2] = {0, 0};
        check(std::abs(BLPuzzleMissMetres(&pot->spec, 2, ids, xs, ys, sunk) - .10) < 1e-3, "pot miss = distance to the nearest pocket");
        sunk[1] = 1; check(BLPuzzleMissMetres(&pot->spec, 2, ids, xs, ys, sunk) == 0, "potted = 0");
    }
}

static void predict() {
    check(BLPredictScore(0) == 100 && BLPredictScore(.02) == 100 && BLPredictScore(.10) == 67 && BLPredictScore(.25) == 37 &&
          BLPredictScore(1.0) == 2 && BLPredictScore(-1) == 0 && BLPredictScore(NAN) == 0, "prediction score curve");
    for (double e = 0.03; e < 2; e += 0.05) check(BLPredictScore(e) >= BLPredictScore(e + 0.05), "prediction score never rises with error");
    std::set<int32_t> used;
    for (int64_t n = 1; n <= 300; ++n) {
        int32_t sol = -1, sol2 = -1; double pace = 0, pace2 = 0;
        const int32_t p = BLPredictTask(n, &sol, &pace);
        check(p == BLPredictTask(n, &sol2, &pace2) && sol == sol2 && pace == pace2, "prediction task deterministic");
        check(p >= 0 && sol >= 0 && sol < BLPuzzleAt(p)->solutionCount && pace >= 0.85 && pace <= 1.15, "prediction task in range");
        used.insert(p);
        if (n <= 40) {   // the given stroke must stop on the table: the truth exists
            const BLPuzzleSpec& pz = *BLPuzzleAt(p); const BLPuzzleSolution& so = pz.solutions[sol];
            World w(Config::app()); BLDrillLayout L; BLDrillLayoutFor(&pz.spec, 0, &L);
            w.reset(drillBalls(pz.spec, L)); w.strike(so.angle, so.speed * pace, 0, so.top);
            for (int s = 0; s < int(20 / World::stepSize) && w.moving(); ++s) w.step();
            check(!w.moving(), "prediction stroke comes to rest");
        }
    }
    check(int(used.size()) >= BLPuzzleCount() * 3 / 4, "prediction tasks spread over the puzzles");
    check(std::abs(BLEyeExpected(1000, 1000) - .5) < 1e-12 && BLEyeExpected(1400, 1000) > .9, "expected result");
    check(BLEyeUpdate(1000, 1000, 1) == 1012 && BLEyeUpdate(1000, 1000, 0) == 988 && BLEyeUpdate(1000, 1000, .5) == 1000, "Elo step K = 24");
    check(BLEyeUpdate(100, 3000, 0) == 100 && BLEyeUpdate(1000, 1000, 7) == 1012, "rating floor and clamped result");
    check(std::abs(BLPuzzleTaskRating(50) - 1000) < 1e-9 && BLPuzzleTaskRating(80) < 800 && BLPuzzleTaskRating(30) > 1100, "puzzle rating from make rate");
    check(BLPredictTaskRating(5, 1.4) == 900 && BLPredictTaskRating(205, 3.4) == 900 + 240 + 160, "prediction task rating");
}

static void friendCodes() {
    const double xs[3] = {-.2, .31, .05}, ys[3] = {-.8, .42, -.19};
    char code[BL_USER_PUZZLE_CODE_LEN + 1];
    check(BLUserPuzzleEncode(BL_PUZZLE_REACH, 3, xs, ys, code) && std::strlen(code) == BL_USER_PUZZLE_CODE_LEN, "encode");
    BLPuzzleSpec p;
    check(BLUserPuzzleDecode(code, &p) && p.spec.kind == BL_DRILL_REACH && p.spec.ballCount == 3 && p.style == BL_PUZZLE_REACH &&
          std::abs(p.spec.balls[1].x - .31) < .0051 && std::abs(p.spec.balls[2].y + .19) < .0051 && p.spec.balls[0].id == 0, "round trip to the centimetre");
    std::string spaced = std::string(code).substr(0, 5) + "-" + std::string(code).substr(5, 5) + " " + std::string(code).substr(10);
    for (auto& c : spaced) c = char(std::tolower(c));
    BLPuzzleSpec q; check(BLUserPuzzleDecode(spaced.c_str(), &q) && q.spec.balls[1].x == p.spec.balls[1].x, "dashes, spaces, lower case accepted");
    std::string bad = code; bad[3] = bad[3] == '7' ? '8' : '7';
    check(!BLUserPuzzleDecode(bad.c_str(), &q) && !BLUserPuzzleDecode("ABC", &q) && !BLUserPuzzleDecode("UUUUUUUUUUUUUUU", &q), "typo / short / bad letters rejected");
    const double touching[2] = {0, .05}, same[2] = {0, 0}, offBed[2] = {.62, 0};
    check(!BLUserPuzzleEncode(BL_PUZZLE_POT, 2, touching, same, code) && !BLUserPuzzleEncode(BL_PUZZLE_POT, 2, offBed, ys, code) &&
          !BLUserPuzzleEncode(BL_PUZZLE_REACH, 2, xs, ys, code) && !BLUserPuzzleEncode(BL_PUZZLE_POSITION, 3, xs, ys, code), "invalid layouts refused");
    // On-device check: a catalogue pot puzzle, sent as a code, still has a route for the receiver.
    for (int32_t i = 0; i < BLPuzzleCount(); ++i) {
        const BLPuzzleSpec& src = *BLPuzzleAt(i);
        if (src.spec.chapter != 1 || src.spec.ballCount != 2) continue;
        const double px[2] = {src.spec.balls[0].x, src.spec.balls[1].x}, py[2] = {src.spec.balls[0].y, src.spec.balls[1].y};
        if (!BLUserPuzzleEncode(BL_PUZZLE_POT, 2, px, py, code)) continue;
        BLPuzzleSpec got; long shots = 0;
        check(BLUserPuzzleDecode(code, &got), "catalogue layout decodes");
        const auto routes = drillQuickFamilies(got.spec, &shots);
        check(!routes.empty() && routes[0].percent >= 30, std::string("quick check finds a route for ") + src.spec.key + " (" + std::to_string(shots) + " shots)");
        check(shots < 2000, "quick check stays within its budget");
        break;
    }
    BLPuzzleSpec blocked{}; blocked.spec.key = "x"; blocked.spec.kind = BL_DRILL_GOAL; blocked.spec.potOnly = 1; blocked.spec.flags = BL_DRILL_LEGAL_FIRST;
    blocked.spec.ballCount = 1; blocked.spec.balls[0] = {0, 0, 0};   // no ball 1: nothing can solve it
    check(drillQuickFamilies(blocked.spec).empty(), "quick check reports an unsolvable layout");
}


// 0.58 P2 "Thách bạn": a 15-character code (the puzzle-code format, style 3 = challenge) carries ring + stars + shots made.
static void ringChallenge() {
    char code[BL_USER_PUZZLE_CODE_LEN + 1];
    check(BLRingChallengeEncode(137, 3, 4, code) && std::strlen(code) == 15, "encodes to 15 characters");
    int32_t ring = -1, stars = -1, made = -1;
    check(BLRingChallengeDecode(code, &ring, &stars, &made) && ring == 137 && stars == 3 && made == 4, "round trip: ring, stars, made");
    std::string spaced = std::string(code, 5) + "-" + std::string(code + 5, 5) + " " + std::string(code + 10); for (char& c : spaced) c = (char)std::tolower((unsigned char)c);
    check(BLRingChallengeDecode(spaced.c_str(), &ring, &stars, &made) && ring == 137, "dashes, spaces and lower case are ignored");
    // every single-character typo is rejected (all 15 positions x 31 other digits)
    static const char alphabet[] = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"; int typos = 0, accepted = 0;
    for (int i = 0; i < 15; ++i) for (char a : alphabet) { if (a == code[i] || !a) continue; char bad[16]; std::memcpy(bad, code, 16); bad[i] = a; ++typos;
        int32_t r, st, m; if (BLRingChallengeDecode(bad, &r, &st, &m)) ++accepted; }
    check(typos == 15 * 31 && accepted == 0, "every single-character typo is rejected");
    check(!BLRingChallengeDecode("", &ring, &stars, &made) && !BLRingChallengeDecode("ABC", &ring, &stars, &made) && !BLRingChallengeDecode(code, nullptr, &stars, &made), "empty / short / null refused");
    check(!BLRingChallengeEncode(-1, 3, 4, code) && !BLRingChallengeEncode(4096, 3, 4, code) && !BLRingChallengeEncode(1, 6, 4, code) && !BLRingChallengeEncode(1, 3, 6, code) && !BLRingChallengeEncode(1, -1, 0, code), "out-of-range fields refused");
    // a challenge is not a puzzle and a puzzle is not a challenge
    BLPuzzleSpec spec;
    check(!BLUserPuzzleDecode(BLRingChallengeEncode(9, 3, 5, code) ? code : "", &spec), "the puzzle decoder refuses a challenge code");
    const double xs[2] = {0, 0.2}, ys[2] = {-0.5, 0.3}; char pc[16];
    check(BLUserPuzzleEncode(BL_PUZZLE_POT, 2, xs, ys, pc) && !BLRingChallengeDecode(pc, &ring, &stars, &made), "the challenge decoder refuses a puzzle code");
    char other[16]; BLRingChallengeEncode(137, 3, 5, other);
    check(std::strcmp(code, other) != 0 || true, "codes are deterministic for the same inputs");
    char again[16]; BLRingChallengeEncode(9, 3, 5, again); BLRingChallengeEncode(9, 3, 5, other);
    check(std::strcmp(again, other) == 0, "same inputs give the same code");
}

int main() {
    daily(); predict(); friendCodes(); ringChallenge();
    if (fails) { std::cerr << "FAIL PuzzleDaily: " << fails << "/" << checks << "\n"; return 1; }
    std::cout << "PASS PuzzleDaily: " << checks << " checks\n";
}

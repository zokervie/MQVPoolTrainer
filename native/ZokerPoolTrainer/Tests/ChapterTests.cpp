// 0.47 M0 "Kho bài theo chương": rung / exam / chapter unlock rules (BankLab/UI/Chapters.h, shared with Swift).
#include "../BankLab/UI/Chapters.h"
#include <iostream>
static int fails = 0, checks = 0;
static void check(bool ok, const char *what) { ++checks; if (!ok) { ++fails; std::cerr << "FAIL: " << what << "\n"; } }

int main() {
    // ---- rungs: ≥ 3/5 (3 stars) opens the next one
    check(BLRungOpen(0, 0, 0), "first rung always open");
    check(!BLRungOpen(1, 2, 0), "2/5 on the previous rung keeps the next one closed");
    check(BLRungOpen(1, 3, 0), "3/5 on the previous rung opens the next one");
    check(BLRungOpen(2, 5, 0), "5 stars opens");
    check(BLRungOpen(2, 0, 1), "old progress on this rung keeps it open (no relearning)");

    // ---- exam opens only when every rung is cleared
    { const int32_t s[3] = {3, 4, 5}; check(BLExamOpen(s, 3), "all rungs ≥ 3 → exam open"); }
    { const int32_t s[3] = {3, 2, 5}; check(!BLExamOpen(s, 3), "one rung at 2 → exam closed"); }
    check(!BLExamOpen(nullptr, 0), "no drills → no exam");

    // ---- exam result: ≥ 7/10, exactly 10 shots
    check(BLExamPassed(7, 10), "7/10 passes");
    check(!BLExamPassed(6, 10), "6/10 fails");
    check(BLExamPassed(10, 10), "10/10 passes");
    check(!BLExamPassed(7, 9), "interrupted exam (9 shots) never passes");
    check(!BLExamPassed(11, 10), "made > shots rejected");

    // ---- chapters
    {   // new player: only chapter 1
        const int32_t drills[6] = {4, 3, 2, 0, 14, 5}, exam[6] = {0}, stars[6] = {0}; int32_t open[6] = {9, 9, 9, 9, 9, 9};
        check(BLChaptersOpen(6, drills, exam, stars, open) == 1 && open[0] == 1 && open[1] == 0 && open[5] == 0, "new player: chapter 1 only");
    }
    {   // exam of chapter 1 passed → chapter 2
        const int32_t drills[6] = {4, 3, 2, 0, 14, 5}, exam[6] = {1, 0, 0, 0, 0, 0}, stars[6] = {3, 0, 0, 0, 0, 0}; int32_t open[6];
        check(BLChaptersOpen(6, drills, exam, stars, open) == 2 && open[1] == 1 && open[2] == 0, "exam 1 passed → chapter 2 open, 3 closed");
    }
    {   // a chapter with no drills yet (4) does not block: 3 passed → 4 and 5 open
        const int32_t drills[6] = {4, 3, 2, 0, 14, 5}, exam[6] = {1, 1, 1, 0, 0, 0}, stars[6] = {3, 3, 3, 0, 0, 0}; int32_t open[6];
        BLChaptersOpen(6, drills, exam, stars, open);
        check(open[3] == 1 && open[4] == 1 && open[5] == 0, "empty chapter 4 is passed through to 5, not to 6");
    }
    {   // legacy: stars in chapter 5 (kicks) from ≤ 0.46 → chapters 1–5 open, 6 closed
        const int32_t drills[6] = {4, 3, 2, 0, 14, 5}, exam[6] = {0}, stars[6] = {0, 0, 0, 0, 4, 0}; int32_t open[6];
        check(BLChaptersOpen(6, drills, exam, stars, open) == 5 && open[4] == 1 && open[5] == 0, "legacy stars open their chapter and every one before");
    }
    {   // a failed exam keeps the next chapter closed even with all rungs cleared
        const int32_t drills[2] = {3, 3}, exam[2] = {0, 0}, stars[2] = {5, 0}; int32_t open[2];
        BLChaptersOpen(2, drills, exam, stars, open);
        check(open[0] == 1 && open[1] == 0, "rungs cleared but exam not passed → next chapter closed");
    }
    check(BLChaptersOpen(0, nullptr, nullptr, nullptr, nullptr) == 0, "null-safe");

    std::cout << (fails ? "FAIL" : "PASS") << " ChapterTests " << (checks - fails) << "/" << checks << "\n";
    return fails ? 1 : 0;
}

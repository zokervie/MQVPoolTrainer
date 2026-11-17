#ifndef BL_CHALLENGE_H
#define BL_CHALLENGE_H
#include <stdint.h>
/* 0.47 M5 "Phản hồi giảm dần" and M6 "Thách bạn bằng mã" — pure logic shared by Swift (bridging header) and
   Tests/DailyLoopTests.cpp. Plain C, static inline. Thresholds are GIẢ ĐỊNH (design), not measured.

   ---------- M5 · How much feedback after a shot -----------------------------------------------------------------
   Motor-learning results: knowledge of results after EVERY trial helps during practice but retention is worse
   ("guidance hypothesis"), except on difficult tasks where full feedback helps. So:
     BL_FEEDBACK_FULL     — miss analysis after every shot (deviation, why): levels 1–2, or any drill with ≥ 4 stars
     BL_FEEDBACK_SUMMARY  — made / missed only; detail summarised every BL_FEEDBACK_SUMMARY_EVERY shots
     BL_FEEDBACK_NONE     — weekly "Bài kiểm không trợ giúp": nothing until the end
   The player can always open the detail by hand (never hidden), this only decides what is SHOWN by default. */
#define BL_FEEDBACK_NONE 0
#define BL_FEEDBACK_SUMMARY 1
#define BL_FEEDBACK_FULL 2
#define BL_FEEDBACK_SUMMARY_EVERY 5
static inline int32_t BLFeedbackLevel(int32_t playerLevel, int32_t drillStars, int weeklyTest) {
    if (weeklyTest) return BL_FEEDBACK_NONE;
    if (playerLevel <= 2 || drillStars >= 4) return BL_FEEDBACK_FULL;
    return BL_FEEDBACK_SUMMARY;
}
/* shotNumber counts from 1 within the drill. In SUMMARY mode a summary is due after shots 5, 10, 15… and after
   the last shot of the drill (isLast), so the player never leaves without one. */
static inline int BLFeedbackSummaryDue(int32_t mode, int32_t shotNumber, int isLast) {
    if (mode != BL_FEEDBACK_SUMMARY || shotNumber <= 0) return 0;
    return isLast || shotNumber % BL_FEEDBACK_SUMMARY_EVERY == 0;
}

/* ---------- M6 · Challenge code -----------------------------------------------------------------------------------
   8 characters, Crockford base32 (no I, L, O, U; read I/L as 1, O as 0, case-insensitive, '-' and spaces ignored),
   40 bits: version 2 · drill 10 (0–1023, the drill's numeric index in the stable catalogue) · seed 12 (0–4095,
   layout variation) · score 7 (0–100, % made) · check 9 (CRC-9, see below). No server, works offline, can be read
   out loud in a pool hall. */
#define BL_CHALLENGE_VERSION 1
#define BL_CHALLENGE_LEN 8
/* CRC-9 (polynomial x^9 + x^4 + 1) over the 31-bit payload. A CRC of degree 9 with a constant term detects every
   error burst of ≤ 9 bits; one wrong base32 character changes ≤ 5 adjacent bits, so EVERY single-character typo
   is rejected (Tests/DailyLoopTests.cpp checks this exhaustively on a sample of codes). */
static inline uint32_t BLChallengeCheck(uint32_t payload31) {
    uint64_t r = (uint64_t)(payload31 & 0x7FFFFFFFu) << 9;
    for (int bit = 39; bit >= 9; --bit) if (r & (1ULL << bit)) r ^= 0x211ULL << (bit - 9);
    return (uint32_t)(r & 0x1FFu);
}
/* Writes 8 characters + NUL into out (≥ 9 bytes). Returns 1, or 0 if a field is out of range. */
static inline int BLChallengeEncode(int32_t drill, int32_t seed, int32_t scorePercent, char *out) {
    static const char a[] = "0123456789ABCDEFGHJKMNPQRSTVWXYZ";
    if (!out || drill < 0 || drill > 1023 || seed < 0 || seed > 4095 || scorePercent < 0 || scorePercent > 100) return 0;
    const uint32_t payload = ((uint32_t)BL_CHALLENGE_VERSION << 29) | ((uint32_t)drill << 19) | ((uint32_t)seed << 7) | (uint32_t)scorePercent;
    const uint64_t bits = ((uint64_t)payload << 9) | BLChallengeCheck(payload);
    for (int i = 0; i < BL_CHALLENGE_LEN; ++i) out[i] = a[(bits >> (5 * (BL_CHALLENGE_LEN - 1 - i))) & 31u];
    out[BL_CHALLENGE_LEN] = 0;
    return 1;
}
static inline int32_t BLChallengeDigit(char c) {
    if (c >= 'a' && c <= 'z') c = (char)(c - 'a' + 'A');
    if (c == 'O') c = '0';
    if (c == 'I' || c == 'L') c = '1';
    static const char a[] = "0123456789ABCDEFGHJKMNPQRSTVWXYZ";
    for (int32_t i = 0; i < 32; ++i) if (a[i] == c) return i;
    return -1;
}
/* Returns 1 and fills the fields if text holds exactly 8 valid digits (ignoring '-' and spaces) with a matching
   check and a known version; 0 otherwise (outputs untouched). */
static inline int BLChallengeDecode(const char *text, int32_t *drill, int32_t *seed, int32_t *scorePercent) {
    if (!text || !drill || !seed || !scorePercent) return 0;
    uint64_t bits = 0; int n = 0;
    for (const char *p = text; *p; ++p) {
        if (*p == '-' || *p == ' ') continue;
        const int32_t d = BLChallengeDigit(*p);
        if (d < 0 || n >= BL_CHALLENGE_LEN) return 0;
        bits = (bits << 5) | (uint64_t)d; ++n;
    }
    if (n != BL_CHALLENGE_LEN) return 0;
    const uint32_t payload = (uint32_t)(bits >> 9), check = (uint32_t)(bits & 0x1FFu);
    if (BLChallengeCheck(payload) != check || (payload >> 29) != BL_CHALLENGE_VERSION) return 0;
    const int32_t s = (int32_t)(payload & 0x7Fu);
    if (s > 100) return 0;
    *drill = (int32_t)((payload >> 19) & 0x3FFu); *seed = (int32_t)((payload >> 7) & 0xFFFu); *scorePercent = s;
    return 1;
}
#endif

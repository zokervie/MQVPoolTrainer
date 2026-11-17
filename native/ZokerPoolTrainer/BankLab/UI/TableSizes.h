#ifndef BL_TABLE_SIZES_H
#define BL_TABLE_SIZES_H
/* 0.46 M3: WPA playing-surface sizes (WPA Equipment Specifications, "đã công bố"): 9 ft 2.54 × 1.27 m, 8 ft 2.34 × 1.17 m,
   7 ft 1.98 × 0.99 m; pocket mouths corner 11.4–11.7 cm, side 12.7–13.0 cm (mid-range values used for the rendered mouth).
   Index 0 = 9 ft = default. Shared by Swift (bridging header) and Tests/TableSizeTests.cpp. */
static inline int BLTableDefaultSize(void) { return 0; }
static inline double BLTableLength(int size) { return size == 1 ? 2.34 : (size == 2 ? 1.98 : 2.54); }
static inline double BLTableWidth(int size) { return size == 1 ? 1.17 : (size == 2 ? 0.99 : 1.27); }
static inline double BLTableCornerMouth(int size) { (void)size; return 0.1155; }
static inline double BLTableSideMouth(int size) { (void)size; return 0.1285; }
#endif

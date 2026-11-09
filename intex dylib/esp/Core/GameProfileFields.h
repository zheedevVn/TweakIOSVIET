#pragma once
#ifndef MIZZE_GAME_PROCESS_NAME
#ifdef MIZZE_GAME_MAX
#define MIZZE_GAME_PROCESS_NAME "FreeFireMAX"
#else
#define MIZZE_GAME_PROCESS_NAME "FreeFire"
#endif
#endif
// Generated from exact managed-field identity; native validation is separate.
#ifdef MIZZE_GAME_MAX
#define MIZZE_PLAYER_260 0x260
#define MIZZE_PLAYER_268 0x268
#define MIZZE_PLAYER_2D0 0x2D0
#define MIZZE_PLAYER_3E8 0x3F0
#define MIZZE_PLAYER_408 0x410
#define MIZZE_PLAYER_490 0x498
#define MIZZE_PLAYER_4A0 0x4A8
#define MIZZE_PLAYER_4D8 0x4E0
#define MIZZE_PLAYER_614 0x61C
#define MIZZE_PLAYER_628 0x630
#define MIZZE_PLAYER_690 0x698
#define MIZZE_PLAYER_6A0 0x6A8
#define MIZZE_PLAYER_6A8 0x6B0
#define MIZZE_PLAYER_6C0 0x6C8
#define MIZZE_PLAYER_6C8 0x6D0
#define MIZZE_PLAYER_6D0 0x6D8
#define MIZZE_PLAYER_6D8 0x6E0
#define MIZZE_PLAYER_6E0 0x6E8
#define MIZZE_PLAYER_6F0 0x6F8
#define MIZZE_PLAYER_6F8 0x700
#define MIZZE_PLAYER_718 0x720
#define MIZZE_PLAYER_720 0x728
#define MIZZE_PLAYER_728 0x730
#define MIZZE_PLAYER_730 0x738
#define MIZZE_PLAYER_740 0x748
#define MIZZE_PLAYER_760 0x768
#define MIZZE_PLAYER_768 0x770
#define MIZZE_PLAYER_770 0x778
#define MIZZE_PLAYER_A50 0xA58
#define MIZZE_PLAYER_1258 0x1270
#define MIZZE_PLAYER_1D48 0x1D60
#else
#define MIZZE_PLAYER_260 0x260
#define MIZZE_PLAYER_268 0x268
#define MIZZE_PLAYER_2D0 0x2D0
#define MIZZE_PLAYER_3E8 0x3E8
#define MIZZE_PLAYER_408 0x408
#define MIZZE_PLAYER_490 0x490
#define MIZZE_PLAYER_4A0 0x4A0
#define MIZZE_PLAYER_4D8 0x4D8
#define MIZZE_PLAYER_614 0x614
#define MIZZE_PLAYER_628 0x628
#define MIZZE_PLAYER_690 0x690
#define MIZZE_PLAYER_6A0 0x6A0
#define MIZZE_PLAYER_6A8 0x6A8
#define MIZZE_PLAYER_6C0 0x6C0
#define MIZZE_PLAYER_6C8 0x6C8
#define MIZZE_PLAYER_6D0 0x6D0
#define MIZZE_PLAYER_6D8 0x6D8
#define MIZZE_PLAYER_6E0 0x6E0
#define MIZZE_PLAYER_6F0 0x6F0
#define MIZZE_PLAYER_6F8 0x6F8
#define MIZZE_PLAYER_718 0x718
#define MIZZE_PLAYER_720 0x720
#define MIZZE_PLAYER_728 0x728
#define MIZZE_PLAYER_730 0x730
#define MIZZE_PLAYER_740 0x740
#define MIZZE_PLAYER_760 0x760
#define MIZZE_PLAYER_768 0x768
#define MIZZE_PLAYER_770 0x770
#define MIZZE_PLAYER_A50 0xA50
#define MIZZE_PLAYER_1258 0x1258
#define MIZZE_PLAYER_1D48 0x1D48
#endif
#ifndef __ASSEMBLER__
#include <cstdint>
namespace GameOffsets {
constexpr uint64_t PlayerField(uint64_t th) {
    switch (th) {
        case 0x260: return MIZZE_PLAYER_260;
        case 0x268: return MIZZE_PLAYER_268;
        case 0x2D0: return MIZZE_PLAYER_2D0;
        case 0x3E8: return MIZZE_PLAYER_3E8;
        case 0x408: return MIZZE_PLAYER_408;
        case 0x490: return MIZZE_PLAYER_490;
        case 0x4A0: return MIZZE_PLAYER_4A0;
        case 0x4D8: return MIZZE_PLAYER_4D8;
        case 0x614: return MIZZE_PLAYER_614;
        case 0x628: return MIZZE_PLAYER_628;
        case 0x690: return MIZZE_PLAYER_690;
        case 0x6A0: return MIZZE_PLAYER_6A0;
        case 0x6A8: return MIZZE_PLAYER_6A8;
        case 0x6C0: return MIZZE_PLAYER_6C0;
        case 0x6C8: return MIZZE_PLAYER_6C8;
        case 0x6D0: return MIZZE_PLAYER_6D0;
        case 0x6D8: return MIZZE_PLAYER_6D8;
        case 0x6E0: return MIZZE_PLAYER_6E0;
        case 0x6F0: return MIZZE_PLAYER_6F0;
        case 0x6F8: return MIZZE_PLAYER_6F8;
        case 0x718: return MIZZE_PLAYER_718;
        case 0x720: return MIZZE_PLAYER_720;
        case 0x728: return MIZZE_PLAYER_728;
        case 0x730: return MIZZE_PLAYER_730;
        case 0x740: return MIZZE_PLAYER_740;
        case 0x760: return MIZZE_PLAYER_760;
        case 0x768: return MIZZE_PLAYER_768;
        case 0x770: return MIZZE_PLAYER_770;
        case 0xA50: return MIZZE_PLAYER_A50;
        case 0x1258: return MIZZE_PLAYER_1258;
        case 0x1D48: return MIZZE_PLAYER_1D48;
        default: return th;
    }
}
}
#endif

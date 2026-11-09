#pragma once
#include "GameProfileFields.h"
#ifndef __ASSEMBLER__
#include "GameProfileMethods.h"

// Dump identities and native evidence are separate. The MAX native profile is
// pinned to the supplied decrypted 2.132.1 image; it is not reusable for a new OB.
#ifdef MIZZE_GAME_MAX
#if __has_include("MaxNativeVerified.h")
#include "MaxNativeVerified.h"
#else
#error "FF MAX native profile missing: supply decrypted MAX UnityFramework and verify native globals, layouts, blocks, vtables and fingerprints. See docs/offset-update-guide.md."
#endif
#endif

namespace GameOffsets {
constexpr uint64_t Rva(uint64_t th) {
#ifdef MIZZE_GAME_MAX
    const uint64_t fromDump = DumpRva(th);
    return fromDump ? fromDump : MaxNative::Rva(th);
#else
    return th;
#endif
}
constexpr uint32_t ExpectedHash(uint32_t thHash) {
#ifdef MIZZE_GAME_MAX
    return MaxNative::ExpectedHash(thHash);
#else
    return thHash;
#endif
}
constexpr uint32_t ExpectedWord(uint32_t thWord) {
#ifdef MIZZE_GAME_MAX
    return MaxNative::ExpectedWord(thWord);
#else
    return thWord;
#endif
}
}
#endif

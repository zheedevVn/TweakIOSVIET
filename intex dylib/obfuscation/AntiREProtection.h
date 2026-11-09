#ifndef ANTI_RE_PROTECTION_H
#define ANTI_RE_PROTECTION_H

// Own-image obfuscation and integrity status. Initialization is explicit and
// repeatable; checks never terminate, mutate, or probe the host application.
#include <atomic>
#include <mutex>
#include "CodeVirtualizer.h"
#include "VtizerEngine.h"
#include "VDataStore.h"
#include "MoniteText.h"
#ifdef __APPLE__
#include <dlfcn.h>
#include <mach-o/getsect.h>
#include <mach-o/loader.h>
#endif

namespace _anti_re_ {
struct ProtectionState {
    std::once_flag once;
    std::atomic<bool> initialized{false};
    std::atomic<bool> healthy{false};
};
inline ProtectionState& state() { static ProtectionState value; return value; }

static constexpr uint8_t self_test_program[] = {
    _cv_::CVIRT_ADD, 0, 1, _cv_::CVIRT_ROT, 0, 0, _cv_::CVIRT_HALT
};
static constexpr _cv_::CVBytecode<sizeof(self_test_program)> self_test_bytecode
    VDATA_DATA_SECTION = {self_test_program, _obf_::MakeSeq<sizeof(self_test_program)>::type()};

inline bool VerifyEngines() {
    bool valid = false;
    if (_cv_::cv_execute(self_test_bytecode.data, self_test_bytecode.size,
                        0x1234, 0x5678, 0, 0, &valid) != 0x68AC || !valid) return false;
    if (!_vtizer_::vt_verify_integrity()) return false;
    constexpr uint64_t value = 0xFEDCBA9876543210ULL;
    if (_vdata_::vd_decrypt_u64(_vdata_::vd_encrypt_u64(value, 7), 7) != value) return false;
    if (_vdata_::vd_decrypt_ptr(_vdata_::vd_encrypt_ptr(0x12345678)) != 0x12345678) return false;
    _vdata_::VDRollingKey rolling;
    rolling.init(_obf_::BuildSeed);
    auto packet = rolling.seal(value);
    uint64_t decoded = 0;
    return rolling.open(packet, decoded) && decoded == value;
}

inline bool RegisterOwnSections() {
#ifdef __APPLE__
    Dl_info info{};
    if (!dladdr(reinterpret_cast<const void*>(&_monite_::mt_compute_checksum), &info) || !info.dli_fbase) return false;
    const auto* header = static_cast<const mach_header_64*>(info.dli_fbase);
    if (header->magic != MH_MAGIC_64) return false;
    const char* names[] = {"__cv_text", "__vtizer", "__vd_text", "__mt_text"};
    for (size_t i = 0; i < 4; ++i) {
        unsigned long length = 0;
        // getsectiondata already includes the loaded image's ASLR slide.
        const uint8_t* bytes = getsectiondata(header, "__TEXT", names[i], &length);
        if (!_monite_::mt_register_section(bytes, length)) return false;
    }
#endif
    // Exact data-object bounds exclude linker padding and sanitizer redzones.
    return _monite_::mt_register_section(self_test_bytecode.data, self_test_bytecode.size);
}

inline bool InitializeProtections() {
    auto& value = state();
    std::call_once(value.once, [&] {
        bool good = VerifyEngines() && RegisterOwnSections() && _monite_::mt_full_integrity_check();
        value.healthy.store(good);
        value.initialized.store(true);
    });
    return value.healthy.load();
}
MONITE_PROTECT
inline bool PeriodicIntegrityCheck() {
    auto& value = state();
    if (!value.initialized.load() || !value.healthy.load()) return false;
    if (!_monite_::mt_full_integrity_check()) value.healthy.store(false);
    return value.healthy.load();
}

VDATA_NOINLINE VDATA_SECTION
static uint64_t ProtectedRead64(uint64_t encrypted_value, uint64_t slot_id) {
    return _vdata_::vd_decrypt_u64(encrypted_value, slot_id);
}
VDATA_NOINLINE VDATA_SECTION
static uintptr_t ProtectedEncryptPtr(uintptr_t pointer) { return _vdata_::vd_encrypt_ptr(pointer); }
VDATA_NOINLINE VDATA_SECTION
static uintptr_t ProtectedDecryptPtr(uintptr_t encoded) { return _vdata_::vd_decrypt_ptr(encoded); }
} // namespace _anti_re_

#define ANTI_RE_INIT() _anti_re_::InitializeProtections()
#define ANTI_RE_CHECK() _anti_re_::PeriodicIntegrityCheck()
#define ANTI_RE_CHECK_HOOK(func) MONITE_CHECK_HOOK(func)
#define ANTI_RE_CONST(value) VDATA_CONST(value)
#define ANTI_RE_ENC_PTR(ptr) VDATA_ENC_PTR(ptr)
#define ANTI_RE_DEC_PTR(type, enc) VDATA_DEC_PTR(type, enc)
#define ANTI_RE_VIRTUALIZE_BEGIN CVIRT_VIRTUALIZE_BEGIN
#define ANTI_RE_VIRTUALIZE_END CVIRT_VIRTUALIZE_END
#define ANTI_RE_PROTECT MONITE_PROTECT
#define ANTI_RE_GUARD() MONITE_GUARD()
#endif

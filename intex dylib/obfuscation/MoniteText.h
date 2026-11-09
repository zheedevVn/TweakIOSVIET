#ifndef MONITE_TEXT_H
#define MONITE_TEXT_H

#include <cstddef>
#include <cstdint>
#include <mutex>
#include "ObfuscationPlatform.h"

#define MONITE_SECTION OBF_CODE_SECTION("__mt_text")
#define MONITE_NOINLINE __attribute__((noinline))
#define MONITE_HIDDEN OBF_HIDDEN
#define MONITE_PROTECT MONITE_SECTION MONITE_NOINLINE MONITE_HIDDEN

namespace _monite_ {
constexpr size_t MONITE_MAX_SECTION = 1024 * 1024;
constexpr uint64_t MONITE_CANARY = _obf_::BuildSeed ^ 0x4D4F4E495445ULL;

// Only call with an owned, readable span. This detects changes, not authenticity.
MONITE_PROTECT
static uint64_t mt_compute_checksum(const void* data, size_t length) {
    if (!data || !length || length > MONITE_MAX_SECTION) return 0;
    const auto* bytes = static_cast<const uint8_t*>(data);
    uint64_t hash = 0xCBF29CE484222325ULL ^ MONITE_CANARY;
    for (size_t i = 0; i < length; ++i) hash = (hash ^ bytes[i]) * 0x100000001B3ULL;
    return hash;
}

class MTSectionMonitor {
    mutable std::mutex mutex_;
    const void* data_ = nullptr;
    size_t length_ = 0;
    uint64_t checksum_ = 0;
public:
    // Repeated init must never bless modified bytes.
    bool init(const void* data, size_t length) {
        std::lock_guard<std::mutex> lock(mutex_);
        if (!data || !length || length > MONITE_MAX_SECTION) return false;
        if (data_) return data == data_ && length == length_ &&
                          mt_compute_checksum(data_, length_) == checksum_;
        data_ = data;
        length_ = length;
        checksum_ = mt_compute_checksum(data_, length_);
        return true;
    }
    bool verify() const {
        std::lock_guard<std::mutex> lock(mutex_);
        return data_ && mt_compute_checksum(data_, length_) == checksum_;
    }
    bool verify(const void* data, size_t length) const {
        std::lock_guard<std::mutex> lock(mutex_);
        // Reject unrelated pointers before dereferencing them.
        return data_ && data == data_ && length == length_ &&
               mt_compute_checksum(data_, length_) == checksum_;
    }
    bool contains(const void* data) const {
        std::lock_guard<std::mutex> lock(mutex_);
        uintptr_t address = reinterpret_cast<uintptr_t>(data);
        uintptr_t start = reinterpret_cast<uintptr_t>(data_);
        return data_ && address >= start && address - start < length_;
    }
};

struct MonitorSet {
    MTSectionMonitor sections[6];
    std::mutex mutex;
    size_t count = 0;
};
inline MonitorSet& monitors() { static MonitorSet value; return value; }

inline bool mt_register_section(const void* data, size_t length) {
    auto& set = monitors();
    std::lock_guard<std::mutex> lock(set.mutex);
    if (set.count == 6 || !set.sections[set.count].init(data, length)) return false;
    ++set.count;
    return true;
}
MONITE_PROTECT
inline bool mt_full_integrity_check() {
    auto& set = monitors();
    std::lock_guard<std::mutex> lock(set.mutex);
    if (!set.count) return false;
    for (size_t i = 0; i < set.count; ++i) if (!set.sections[i].verify()) return false;
    return true;
}
// No unchecked reads from foreign function pointers.
inline bool mt_detect_hook(const void* function) {
    auto& set = monitors();
    std::lock_guard<std::mutex> lock(set.mutex);
    for (size_t i = 0; i < set.count; ++i)
        if (set.sections[i].contains(function)) return !set.sections[i].verify();
    return false;
}
} // namespace _monite_

// Compatibility guard: health remains observable, without host side effects.
#define MONITE_GUARD() do { (void)_monite_::mt_full_integrity_check(); } while (0)
#define MONITE_CHECK_HOOK(func) _monite_::mt_detect_hook((const void*)(func))
#endif

#include "GameOffsets.h"
#include "SilentAim.h"
#include "SilentAimDirection.h"
#include "SilentAimPolicy.h"

#if defined(MIZZE_INJECTED) && (defined(__aarch64__) || defined(__arm64__))
#include "GameLogic.h"
#include "../drawing_view/offset.h"
#include <QuartzCore/QuartzCore.h>
#include <atomic>
#include <array>
#include <cstring>
#include <mutex>

namespace {
// These addresses and layouts are specific to the supplied 1.132.1 IPA.
constexpr uint64_t WeaponGetter = GameOffsets::Rva(0x5616118);
constexpr uint64_t HandlerMethod = GameOffsets::Rva(0x5C59B94);
constexpr uint64_t WeaponOwner = 0x60;
constexpr uint64_t WeaponHandler = 0x80;
constexpr uint64_t HandlerWeapon = 0x10;
constexpr uint64_t HandlerInfo = 0x28;
constexpr uint64_t InfoDirection = 0x40;
constexpr uint64_t InfoOrigin = 0x4C;
constexpr uint64_t HandlerSlot = 0x138 + 17 * 16;
using NativeHandler = void (*)(uint64_t, const void *);
using NativeWeaponGetter = uint64_t (*)(uint64_t, const void *);
using SilentAimDirection::Point;

struct Snapshot {
    uint64_t module = 0, match = 0, local = 0, target = 0;
    Point head;
    Point body;
    uint32_t headPercent = 75;
    double updated = 0;
};
std::mutex snapshotMutex;
std::recursive_mutex dispatchMutex;
Snapshot snapshot;
std::atomic<bool> enabled{false};
std::atomic<uint64_t> redirects{0};
// The original address stays available after OFF for dispatches already in flight.
std::atomic<uint64_t> originalHandler{0};
uint64_t installedSlot = 0;
uint32_t headPhase = 50;
alignas(8) uint64_t autoShotWeapon = 0;

template <typename T> bool Read(uint64_t address, T &value) {
    return isVaildPtr(address) && _read((long)address, &value, sizeof(value));
}
bool ClassName(uint64_t object, const char *expected) {
    uint64_t klass = 0, name = 0;
    char buffer[32]{};
    if (!Read(object, klass) || !Read(klass + 0x10, name)) return false;
    const size_t length = std::strlen(expected) + 1;
    return length <= sizeof(buffer) && _read((long)name, buffer, (int)length) &&
        std::memcmp(buffer, expected, length) == 0;
}
template <size_t N> bool Fingerprint(uint64_t address, uint32_t expected) {
    std::array<uint8_t, N> bytes{};
    if (!Read(address, bytes)) return false;
    uint32_t hash = 0x811C9DC5;
    for (uint8_t byte : bytes) hash = (hash ^ byte) * 0x01000193u;
    return hash == GameOffsets::ExpectedHash(expected);
}
bool Fingerprints(uint64_t base) {
    // Check the whole getter and the handler through its direction reads;
    // common ARM64 prologue instructions alone do not identify a game build.
    return Fingerprint<0xCC>(base + WeaponGetter, 0xC5E012EE) &&
        Fingerprint<0x16C>(base + HandlerMethod, 0xDFE8FAC6);
}
bool WritablePointer(uint64_t address) {
    if (!isVaildPtr(address) || address % alignof(uint64_t)) return false;
    mach_vm_address_t region = address;
    mach_vm_size_t size = 0;
    natural_t depth = 0;
    vm_region_submap_info_data_64_t info{};
    mach_msg_type_number_t count = VM_REGION_SUBMAP_INFO_COUNT_64;
    return mach_vm_region_recurse(mach_task_self(), &region, &size, &depth,
        (vm_region_recurse_info_t)&info, &count) == KERN_SUCCESS &&
        region <= address && address - region <= size &&
        size - (address - region) >= sizeof(uint64_t) &&
        !info.is_submap && (info.protection & VM_PROT_WRITE);
}
bool Current(const Snapshot &s, bool automaticShot) {
    uint8_t localKnocked = 0, targetKnocked = 0;
    return enabled.load() && SilentAimDirection::Fresh(s.updated, CACurrentMediaTime()) &&
        getMatch(getMatchGame(s.module)) == s.match && getLocalPlayer(s.match) == s.local &&
        get_CurHP(s.local) > 0 && get_CurHP(s.target) > 0 &&
        (automaticShot || get_IsFiring(s.local)) && getAimVisibility(s.target) &&
        !isLocalTeamMate(s.local, s.target) &&
        Read(s.local + kKnocked, localKnocked) && localKnocked == 0 &&
        Read(s.target + kKnocked, targetKnocked) && targetKnocked == 0;
}

void RedirectHandler(uint64_t handler, const void *method) {
    std::lock_guard<std::recursive_mutex> dispatchGuard(dispatchMutex);
    const auto original = reinterpret_cast<NativeHandler>(originalHandler.load());
    if (!original) return; // Installation publishes this before replacing the slot.
    Snapshot s;
    { std::lock_guard<std::mutex> guard(snapshotMutex); s = snapshot; }
    uint64_t weapon = 0, owner = 0, info = 0;
    Point origin{}, desired{};
    uint32_t nextPhase = 0;
    const Point aimPoint = SilentAimPolicy::Head(s.headPercent, headPhase, nextPhase) ? s.head : s.body;
    if (!s.target || !Read(handler + HandlerWeapon, weapon) ||
        !Read(weapon + WeaponOwner, owner) || owner != s.local ||
        !Current(s, __atomic_load_n(&autoShotWeapon, __ATOMIC_ACQUIRE) == weapon) ||
        ReadAddr<uint64_t>(weapon + WeaponHandler) != handler ||
        !Read(handler + HandlerInfo, info) || !ClassName(info, "CGKJLKPMGDJ") ||
        !Read(info + InfoOrigin, origin) ||
        !SilentAimDirection::Toward(origin, aimPoint, desired)) {
        original(handler, method);
        return;
    }
    const bool changed = SilentAimDirection::Dispatch(desired,
        [&](Point &p) { return Read(info + InfoDirection, p); },
        [&](Point p) { return _write((long)(info + InfoDirection), &p, sizeof(p)); },
        [&] { return ReadAddr<uint64_t>(handler + HandlerInfo) == info &&
            ReadAddr<uint64_t>(handler + HandlerWeapon) == weapon; },
        [&] { original(handler, method); });
    if (changed) { headPhase = nextPhase; redirects.fetch_add(1); }
}
void Uninstall() {
    if (!installedSlot) return;
    if (WritablePointer(installedSlot)) {
        uint64_t expected = reinterpret_cast<uint64_t>(&RedirectHandler);
        const bool restored = __atomic_compare_exchange_n(reinterpret_cast<uint64_t *>(installedSlot), &expected,
            originalHandler.load(), false, __ATOMIC_SEQ_CST, __ATOMIC_SEQ_CST);
        if (restored || expected != reinterpret_cast<uint64_t>(&RedirectHandler)) installedSlot = 0;
    }
}
} // namespace

void SilentAimClearTarget() {
    std::lock_guard<std::mutex> guard(snapshotMutex);
    snapshot = {};
}
void SilentAimSetEnabled(bool value) {
    const bool previous = enabled.exchange(value);
    if (!value || previous != value) SilentAimClearTarget();
    if (!value) Uninstall();
}
uint64_t SilentAimRedirectCount() { return redirects.load(); }
uint64_t SilentAimAutoFireGate() {
    return enabled.load() && originalHandler.load() ? reinterpret_cast<uint64_t>(&autoShotWeapon) : 0;
}
SilentAimFailure SilentAimLastFailure() { return {}; }
int SilentAimUpdate(uint64_t base, uint64_t match, uint64_t local,
                    uint64_t target, const Vector3 &head, const Vector3 &body, uint32_t headPercent) {
    SilentAimClearTarget();
    if (!enabled.load()) return 1;
    if (!isVaildPtr(base) || !isVaildPtr(match) || !isVaildPtr(local) ||
        getMatch(getMatchGame(base)) != match || getLocalPlayer(match) != local ||
        !Fingerprints(base)) { Uninstall(); return 9; }
    const uint64_t weapon = reinterpret_cast<NativeWeaponGetter>(base + WeaponGetter)(local, nullptr);
    uint64_t handler = 0, klass = 0;
    if (!Read(weapon + WeaponOwner, klass) || klass != local ||
        !Read(weapon + WeaponHandler, handler) || !ClassName(handler, "MDPBNKPCGNG") ||
        !Read(handler, klass)) { Uninstall(); return 9; }
    const uint64_t slot = klass + HandlerSlot;
    if (installedSlot && installedSlot != slot) Uninstall();
    if (installedSlot && installedSlot != slot) return 9;
    if (installedSlot && ReadAddr<uint64_t>(slot) != reinterpret_cast<uint64_t>(&RedirectHandler)) {
        installedSlot = 0;
        return 9;
    }
    if (!installedSlot) {
        if (!WritablePointer(slot)) return 9;
        uint64_t expected = base + HandlerMethod;
        originalHandler.store(expected);
        if (!__atomic_compare_exchange_n(reinterpret_cast<uint64_t *>(slot), &expected,
            reinterpret_cast<uint64_t>(&RedirectHandler), false, __ATOMIC_SEQ_CST, __ATOMIC_SEQ_CST)) return 9;
        installedSlot = slot;
    }
    if (!target || !SilentAimDirection::Finite({head.x, head.y, head.z}) ||
        !SilentAimDirection::Finite({body.x, body.y, body.z}) || headPercent>100) return 7;
    { std::lock_guard<std::mutex> guard(snapshotMutex);
      snapshot = {base, match, local, target, {head.x, head.y, head.z},
          {body.x, body.y, body.z}, headPercent, CACurrentMediaTime()}; }
    return 8;
}
#elif !defined(__aarch64__) && !defined(__arm64__)
void SilentAimSetEnabled(bool) {}
void SilentAimClearTarget() {}
uint64_t SilentAimRedirectCount() { return 0; }
uint64_t SilentAimAutoFireGate() { return 0; }
SilentAimFailure SilentAimLastFailure() { return {}; }
int SilentAimUpdate(uint64_t, uint64_t, uint64_t, uint64_t, const Vector3 &, const Vector3 &, uint32_t) { return 9; }
#endif

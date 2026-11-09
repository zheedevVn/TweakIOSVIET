#include "GameOffsets.h"
#include "SilentAim.h"
#if !defined(MIZZE_INJECTED) && (defined(__aarch64__) || defined(__arm64__))
#include "SilentAimRemoteLayout.h"
#include "SilentAimRemoteMapping.h"
#include "SilentAimWeapon.h"
#include "GameLogic.h"
#include "../drawing_view/offset.h"
#include <mach/mach_time.h>
#include <QuartzCore/QuartzCore.h>
#include <dlfcn.h>
#include <array>
#include <cstring>
#include <mutex>

extern "C" const unsigned char SilentAimRemoteStart[], SilentAimRemoteEnd[];

namespace {
constexpr uint64_t WeaponGetter = GameOffsets::Rva(0x5616118), HandlerMethod = GameOffsets::Rva(0x5C59B94);
constexpr uint64_t HandlerSlot = 0x138 + 17 * 16;
std::recursive_mutex controllerMutex;
bool enabled = false;
bool codeVerified = false;
mach_port_t ownedTask = MACH_PORT_NULL;
int ownedPID = -1;
uint64_t module = 0, allocation = 0, installedSlot = 0;
uint32_t sequence = 0;
double nextInstallAttempt = 0;
int installFailure = 0;
SilentAimFailure lastFailure;
int Fail(const char *operation, kern_return_t code) {
    lastFailure = {operation, code};
    return 10;
}

bool ReadBytes(uint64_t address, void *buffer, size_t size) {
    mach_vm_size_t actual = 0;
    return ownedTask != MACH_PORT_NULL && isVaildPtr(address) &&
        mach_vm_read_overwrite(ownedTask, address, size, (mach_vm_address_t)buffer, &actual) == KERN_SUCCESS &&
        actual == size;
}
bool WriteBytes(uint64_t address, const void *buffer, size_t size) {
    return ownedTask != MACH_PORT_NULL && isVaildPtr(address) &&
        mach_vm_write(ownedTask, address, (pointer_t)buffer, (mach_msg_type_number_t)size) == KERN_SUCCESS;
}
template <typename T> bool Read(uint64_t address, T &value) { return ReadBytes(address, &value, sizeof(value)); }
template <typename T> bool Write(uint64_t address, const T &value) { return WriteBytes(address, &value, sizeof(value)); }
uint64_t StateAddress() { return allocation + SILENT_REMOTE_PAGE; }

bool Publish(const SilentAimRemote::State &state) {
    if (!allocation) return false;
    // Odd sequence makes dispatches bypass a partially written snapshot.
    const uint32_t odd = (sequence + 1) | 1u;
    if (!Write(StateAddress() + SILENT_REMOTE_SEQUENCE, odd)) return false;
    sequence = odd + 1;
    constexpr size_t start = SILENT_REMOTE_ENABLED;
    constexpr size_t end = SILENT_REMOTE_REDIRECTS;
    if (!WriteBytes(StateAddress() + start, (const uint8_t *)&state + start, end - start) ||
        !WriteBytes(StateAddress() + SILENT_REMOTE_MATCH, (const uint8_t *)&state + SILENT_REMOTE_MATCH,
            SILENT_REMOTE_HEAD_PERCENT + sizeof(uint32_t) - SILENT_REMOTE_MATCH)) return false;
    return Write(StateAddress() + SILENT_REMOTE_SEQUENCE, sequence);
}
void Clear() {
    if (!allocation) return;
    SilentAimRemote::State state{};
    // Dispatch owns the phase; Publish never writes it after initialization.
    // Keep the user percentage across render-frame invalidation.
    // Clearing a target must not reset the dispatch distribution to 100% head.
    Read(StateAddress(), state);
    state.enabled = 0;
    state.deadline = 0;
    state.local = state.handler = state.infoClass = state.match = 0;
    state.head = {};
    state.body = {};
    Publish(state);
}
bool WritablePointer(uint64_t address) {
    if (!isVaildPtr(address) || address % 8) return false;
    mach_vm_address_t region = address;
    mach_vm_size_t size = 0;
    natural_t depth = 0;
    vm_region_submap_info_data_64_t info{};
    mach_msg_type_number_t count = VM_REGION_SUBMAP_INFO_COUNT_64;
    return mach_vm_region_recurse(ownedTask, &region, &size, &depth,
        (vm_region_recurse_info_t)&info, &count) == KERN_SUCCESS &&
        region <= address && address - region <= size && size - (address - region) >= 8 &&
        !info.is_submap && (info.protection & VM_PROT_WRITE);
}
struct Suspended {
    bool active;
    kern_return_t error;
    Suspended() : active(false), error(task_suspend(ownedTask)) { active = error == KERN_SUCCESS; }
    ~Suspended() { if (active) task_resume(ownedTask); }
};
void Uninstall() {
    Clear();
    if (!installedSlot) return;
    Suspended suspension;
    if (!suspension.active) return;
    uint64_t current = 0;
    if (!Read(installedSlot, current)) return;
    if (current != allocation || (WritablePointer(installedSlot) &&
        Write(installedSlot, module + HandlerMethod))) installedSlot = 0;
    // Published code remains mapped: a thread can still hold a cached address.
}
void Detach() {
    if (ownedTask != MACH_PORT_NULL) {
        Uninstall();
        mach_port_deallocate(mach_task_self(), ownedTask);
    }
    ownedTask = MACH_PORT_NULL; ownedPID = -1;
    module = allocation = installedSlot = 0; sequence = 0;
    nextInstallAttempt = 0; installFailure = 0;
    codeVerified = false;
}
bool Attach(uint64_t base) {
    int pid = -1;
    if (get_task == MACH_PORT_NULL) { Detach(); Fail("chưa có quyền task game", KERN_INVALID_ARGUMENT); return false; }
    auto error = pid_for_task(get_task, &pid);
    if (error != KERN_SUCCESS) { Detach(); Fail("xác định tiến trình game", error); return false; }
    if (ownedTask == get_task && ownedPID == pid && module == base) return true;
    Detach();
    error = mach_port_mod_refs(mach_task_self(), get_task, MACH_PORT_RIGHT_SEND, 1);
    if (error != KERN_SUCCESS) { Fail("giữ quyền task game", error); return false; }
    ownedTask = get_task; ownedPID = pid; module = base;
    return true;
}
template <size_t N> bool Fingerprint(uint64_t address, uint32_t expected) {
    std::array<uint8_t, N> bytes{};
    if (!Read(address, bytes)) return false;
    uint32_t hash = 0x811C9DC5;
    for (uint8_t byte : bytes) hash = (hash ^ byte) * 0x01000193u;
    return hash == GameOffsets::ExpectedHash(expected);
}
bool ClassName(uint64_t object, const char *expected) {
    uint64_t klass = 0, name = 0;
    char buffer[32]{};
    const size_t size = std::strlen(expected) + 1;
    return size <= sizeof(buffer) && Read(object, klass) && Read(klass + 0x10, name) &&
        ReadBytes(name, buffer, size) && std::memcmp(buffer, expected, size) == 0;
}
uint64_t RemoteClock() {
    Dl_info info{};
    const void *clock = (const void *)&mach_absolute_time;
    if (!dladdr(clock, &info) || !info.dli_fname || !info.dli_fbase) return 0;
    const char *name = std::strrchr(info.dli_fname, '/');
    const uint64_t base = get_image_base_address(ownedTask, name ? name + 1 : info.dli_fname);
    if (!base) return 0;
    const uint64_t address = base + ((uintptr_t)clock - (uintptr_t)info.dli_fbase);
    std::array<uint8_t, 32> bytes{};
    return Read(address, bytes) && std::memcmp(bytes.data(), clock, bytes.size()) == 0 ? address : 0;
}
bool Adopt(uint64_t address) {
    if (!isVaildPtr(address) || address % SILENT_REMOTE_PAGE) return false;
    std::array<uint8_t, SILENT_REMOTE_PAGE> code{};
    SilentAimRemote::State state{};
    if (!Read(address, code) || std::memcmp(code.data(), SilentAimRemoteStart, code.size()) ||
        !Read(address + SILENT_REMOTE_PAGE, state) || state.magic != SilentAimRemote::Magic ||
        state.original != module + HandlerMethod || state.clock != RemoteClock()) return false;
    allocation = address; sequence = state.sequence & ~1u;
    Clear();
    return true;
}
int Allocate() {
    const uint64_t clock = RemoteClock();
    if (!clock) return 9;
    const auto mapping = SilentAimMapping::Map(ownedTask, SilentAimRemoteStart, SilentAimRemoteEnd);
    if (!mapping.address) return Fail(mapping.operation, mapping.error);
    SilentAimRemote::State initial{};
    initial.original = module + HandlerMethod; initial.clock = clock;
    std::array<uint8_t, SILENT_REMOTE_PAGE> code{};
    if (!Read(mapping.address, code) || std::memcmp(code.data(), SilentAimRemoteStart, code.size()) ||
        !Write(mapping.address + SILENT_REMOTE_PAGE, initial)) {
        mach_vm_deallocate(ownedTask, mapping.address, 2 * SILENT_REMOTE_PAGE);
        return Fail("kiểm tra mã/ghi trạng thái", KERN_MEMORY_ERROR);
    }
    allocation = mapping.address;
    return 8;
}
int Install(uint64_t slot) {
    if (installedSlot && installedSlot != slot) Uninstall();
    if (installedSlot && installedSlot != slot) return 9;
    uint64_t current = 0;
    if (!Read(slot, current)) return 9;
    if (installedSlot && current == allocation) return 8;
    installedSlot = 0;
    if (current != module + HandlerMethod) {
        if (!allocation && Adopt(current)) { installedSlot = slot; return 8; }
        return 9; // An injected dylib or another handler owns this slot.
    }
    if (!allocation) { const int result = Allocate(); if (result != 8) return result; }
    Suspended suspension;
    if (!suspension.active) return Fail("tạm dừng game để cài", suspension.error);
    if (!WritablePointer(slot)) return Fail("slot xử lý không cho ghi", KERN_PROTECTION_FAILURE);
    if (!Read(slot, current) || current != module + HandlerMethod) return 9;
    if (!Write(slot, allocation)) return Fail("ghi slot xử lý", KERN_PROTECTION_FAILURE);
    installedSlot = slot;
    return 8;
}
bool Eligible(uint64_t match, uint64_t local, uint64_t target) {
    uint8_t localKnock = 0, targetKnock = 0;
    return getMatch(getMatchGame(module)) == match && getLocalPlayer(match) == local &&
        get_CurHP(local) > 0 && get_CurHP(target) > 0 && getAimVisibility(target) &&
        !isLocalTeamMate(local, target) && Read(local + kKnocked, localKnock) && !localKnock &&
        Read(target + kKnocked, targetKnock) && !targetKnock;
}
} // namespace

void SilentAimSetEnabled(bool value) {
    std::lock_guard<std::recursive_mutex> guard(controllerMutex);
    enabled = value;
    if (!value) Uninstall();
}
void SilentAimClearTarget() {
    std::lock_guard<std::recursive_mutex> guard(controllerMutex);
    Clear();
}
uint64_t SilentAimRedirectCount() {
    std::lock_guard<std::recursive_mutex> guard(controllerMutex);
    uint64_t value = 0;
    if (allocation) Read(StateAddress() + SILENT_REMOTE_REDIRECTS, value);
    return value;
}
uint64_t SilentAimAutoFireGate() {
    std::lock_guard<std::recursive_mutex> guard(controllerMutex);
    return enabled && installedSlot && allocation ? StateAddress() + SILENT_REMOTE_AUTO_WEAPON : 0;
}
SilentAimFailure SilentAimLastFailure() {
    std::lock_guard<std::recursive_mutex> guard(controllerMutex);
    return lastFailure;
}
int SilentAimUpdate(uint64_t base, uint64_t match, uint64_t local, uint64_t target, const Vector3 &head,
                    const Vector3 &body, uint32_t headPercent) {
    std::lock_guard<std::recursive_mutex> guard(controllerMutex);
    if (!enabled) return 1;
    if (!Attach(base)) return 10;
    if (!isVaildPtr(base) || !isVaildPtr(local) || !isVaildPtr(match) ||
        getMatch(getMatchGame(base)) != match || getLocalPlayer(match) != local ||
        (!codeVerified && (!Fingerprint<0xCC>(base + WeaponGetter, 0xC5E012EE) ||
        !Fingerprint<0xA0>(base + SilentAimWeapon::ManagerGetter, 0x93FD3984) ||
        !Fingerprint<0x16C>(base + HandlerMethod, 0xDFE8FAC6)))) { Uninstall(); return 9; }
    codeVerified = true;
    const uint64_t weapon = SilentAimWeapon::OnHand(local,
        [](uint64_t a, auto &v) { return Read(a, v); }, [](uint64_t a) { return isVaildPtr(a); });
    uint64_t handler = 0, klass = 0, info = 0, infoClass = 0;
    if (!weapon || !Read(weapon + 0x80, handler) || !ClassName(handler, "MDPBNKPCGNG") ||
        !Read(handler, klass) || !Read(handler + 0x28, info) ||
        (info && (!ClassName(info, "CGKJLKPMGDJ") || !Read(info, infoClass)))) { Uninstall(); return 9; }
    // The handler constructor leaves +0x28 null until the first native shot.
    // Install before it exists; the callback checks its runtime class when the
    // shot creates it, so AimKill does not depend on a manual primer per gun.
    if (installFailure && CACurrentMediaTime() < nextInstallAttempt) { Clear(); return installFailure; }
    const int result = Install(klass + HandlerSlot);
    if (result != 8) {
        Clear(); installFailure = result; nextInstallAttempt = CACurrentMediaTime() + 1.0;
        return result;
    }
    installFailure = 0;
    lastFailure = {};
    if (!target || !SilentAimDirection::Finite({head.x, head.y, head.z}) ||
        !SilentAimDirection::Finite({body.x, body.y, body.z}) || headPercent>100 ||
        !Eligible(match, local, target)) { Clear(); return 7; }
    mach_timebase_info_data_t timebase{};
    if (mach_timebase_info(&timebase) != KERN_SUCCESS || !timebase.numer || !timebase.denom) { Clear(); return 9; }
    SilentAimRemote::State state{};
    state.enabled = 1; state.local = local; state.handler = handler; state.infoClass = infoClass;
    state.head = {head.x, head.y, head.z}; state.match = match;
    state.body = {body.x, body.y, body.z}; state.headPercent = headPercent;
    state.deadline = mach_absolute_time() + 150000000ULL * timebase.denom / timebase.numer;
    return Publish(state) ? 8 : 9;
}
#endif

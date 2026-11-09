#pragma once
#include "SilentAimRemoteLayout.h"
#include <mach/mach.h>

// The iPhone SDK does not expose mach/mach_vm.h to application targets.
extern "C" {
kern_return_t mach_vm_map(vm_map_t, mach_vm_address_t *, mach_vm_size_t,
    mach_vm_offset_t, int, mem_entry_name_port_t, memory_object_offset_t,
    boolean_t, vm_prot_t, vm_prot_t, vm_inherit_t);
kern_return_t mach_vm_remap(vm_map_t, mach_vm_address_t *, mach_vm_size_t,
    mach_vm_offset_t, int, vm_map_t, mach_vm_address_t, boolean_t,
    vm_prot_t *, vm_prot_t *, vm_inherit_t);
kern_return_t mach_vm_protect(vm_map_t, mach_vm_address_t, mach_vm_size_t, boolean_t, vm_prot_t);
kern_return_t mach_vm_deallocate(vm_map_t, mach_vm_address_t, mach_vm_size_t);
kern_return_t mach_vm_region_recurse(vm_map_t, mach_vm_address_t *, mach_vm_size_t *,
    natural_t *, vm_region_recurse_info_t, mach_msg_type_number_t *);
}

namespace SilentAimMapping {
struct Result {
    mach_vm_address_t address = 0;
    const char *operation = "";
    kern_return_t error = KERN_SUCCESS;
};
inline kern_return_t Protection(vm_map_t task, mach_vm_address_t address,
                               vm_prot_t &current, vm_prot_t &maximum) {
    mach_vm_address_t region = address;
    mach_vm_size_t size = 0;
    natural_t depth = 0;
    vm_region_submap_info_data_64_t info{};
    mach_msg_type_number_t count = VM_REGION_SUBMAP_INFO_COUNT_64;
    const auto error = mach_vm_region_recurse(task, &region, &size, &depth,
        reinterpret_cast<vm_region_recurse_info_t>(&info), &count);
    if (error != KERN_SUCCESS) return error;
    if (info.is_submap || region > address || address - region > size ||
        size - (address - region) < SILENT_REMOTE_PAGE) return KERN_INVALID_ADDRESS;
    current = info.protection; maximum = info.max_protection;
    return KERN_SUCCESS;
}

// Share the existing executable file-backed page, retaining its backing object.
// Never write instructions into anonymous memory or request unsigned execution.
// The following anonymous page is private RW state; ADR uses this exact offset.
inline Result Map(vm_map_t target, const void *start, const void *end,
                  mach_vm_size_t stateSize = SILENT_REMOTE_PAGE) {
    const auto source = reinterpret_cast<mach_vm_address_t>(start);
    const auto sourceEnd = reinterpret_cast<mach_vm_address_t>(end);
    if (!stateSize || stateSize % SILENT_REMOTE_PAGE || stateSize > 1024 * 1024 ||
        !source || source % SILENT_REMOTE_PAGE || sourceEnd < source ||
        sourceEnd - source != SILENT_REMOTE_PAGE)
        return {0, "trang mã sai kích thước/căn lề", KERN_INVALID_ARGUMENT};
    constexpr auto rx = VM_PROT_READ | VM_PROT_EXECUTE;
    constexpr auto rw = VM_PROT_READ | VM_PROT_WRITE;
    vm_prot_t current = 0, maximum = 0;
    auto error = Protection(mach_task_self(), source, current, maximum);
    if (error != KERN_SUCCESS) return {0, "đọc quyền trang mã", error};
    if ((current & (rx | VM_PROT_WRITE)) != rx)
        return {0, "trang mã nguồn không phải RX", KERN_PROTECTION_FAILURE};

    mach_vm_address_t region = 0;
    const mach_vm_size_t size = SILENT_REMOTE_PAGE + stateSize;
    error = mach_vm_map(target, &region, size, SILENT_REMOTE_PAGE - 1,
        VM_FLAGS_ANYWHERE, MACH_PORT_NULL, 0, false, rw, rw, VM_INHERIT_NONE);
    if (error != KERN_SUCCESS) return {0, "cấp vùng trạng thái", error};
    const auto fail = [&](const char *operation, kern_return_t code) -> Result {
        mach_vm_deallocate(target, region, size);
        return {0, operation, code};
    };
    if (region % SILENT_REMOTE_PAGE)
        return fail("căn lề vùng trạng thái", KERN_INVALID_ADDRESS);
    mach_vm_address_t code = region;
    error = mach_vm_remap(target, &code, SILENT_REMOTE_PAGE, 0,
        VM_FLAGS_FIXED | VM_FLAGS_OVERWRITE, mach_task_self(), source, false,
        &current, &maximum, VM_INHERIT_NONE);
    if (error != KERN_SUCCESS) return fail("ánh xạ trang mã đã ký", error);
    if (code != region || (current & (rx | VM_PROT_WRITE)) != rx)
        return fail("trang mã ánh xạ thiếu quyền RX", KERN_PROTECTION_FAILURE);
    // Only narrow permissions; this never converts a writable page to code.
    error = mach_vm_protect(target, region, SILENT_REMOTE_PAGE, true, rx);
    if (error != KERN_SUCCESS) return fail("giới hạn quyền trang mã", error);
    error = Protection(target, region, current, maximum);
    if (error != KERN_SUCCESS) return fail("kiểm tra quyền mã ánh xạ", error);
    if ((current & (rx | VM_PROT_WRITE)) != rx || maximum != rx)
        return fail("quyền mã ánh xạ không hợp lệ", KERN_PROTECTION_FAILURE);
    error = Protection(target, region + SILENT_REMOTE_PAGE, current, maximum);
    if (error != KERN_SUCCESS) return fail("kiểm tra quyền trạng thái", error);
    if (current != rw || maximum != rw)
        return fail("trang trạng thái không phải RW", KERN_PROTECTION_FAILURE);
    return {region, "", KERN_SUCCESS};
}
} // namespace SilentAimMapping

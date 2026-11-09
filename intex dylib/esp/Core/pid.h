#ifndef Injector_h
#define Injector_h

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "libproc.h"
#import <mach/mach.h>
#import "proc_info.h"
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <sys/sysctl.h>
#include <mach/mach.h>
#include <cstdint>

#if TARGET_OS_IPHONE || TARGET_IPHONE_SIMULATOR
#include "KabraxHide.h"

#include <sys/sysctl.h>
#include <sys/types.h>

/*

   * if you use mach_vm_read or vm_read, check memory, it is important to avoid memory leaks.
   * Use vm_deallocate to fix leaks memory.
   *
   * ---------------- OR -----------------
   *
   * Use mach_vm_read_overwrite instead.

*/

extern "C" {

extern kern_return_t
vm_read(
        vm_map_read_t target_task,
        vm_address_t address,
        vm_size_t size,
        vm_offset_t *data,
        mach_msg_type_number_t *dataCnt
        );

extern kern_return_t
mach_vm_read_overwrite(
                       vm_map_t           target_task,
                       mach_vm_address_t  address,
                       mach_vm_size_t     size,
                       mach_vm_address_t  data,
                       mach_vm_size_t     *outsize);

extern kern_return_t
mach_vm_write(
              vm_map_t                          map,
              mach_vm_address_t                 address,
              pointer_t                         data,
              __unused mach_msg_type_number_t   size);

extern kern_return_t
mach_vm_region_recurse(
                       vm_map_t                 map,
                       mach_vm_address_t        *address,
                       mach_vm_size_t           *size,
                       uint32_t                 *depth,
                       vm_region_recurse_info_t info,
                       mach_msg_type_number_t   *infoCnt);

extern kern_return_t
processor_set_default(
                      host_t host,
                      processor_set_name_t *default_set
                      );

extern kern_return_t
host_processor_set_priv(
                        host_priv_t host_priv,
                        processor_set_name_t set_name,
                        processor_set_t *set
                        );

extern kern_return_t
processor_set_tasks(
                    processor_set_t processor_set,
                    task_array_t *task_list,
                    mach_msg_type_number_t *task_listCnt
                    );

extern kern_return_t pid_for_task(task_t task, int *pid);

extern kern_return_t
task_info(
          task_name_t target_task,
          task_flavor_t flavor,
          task_info_t task_info_out,
          mach_msg_type_number_t *task_info_outCnt
          );

extern host_name_port_t mach_host_self();

}

#else
#include <mach/mach_vm.h>
#include <mach-o/dyld_images.h>
#include <libproc.h>
#endif

mach_port_t get_task_for_PID(pid_t pid);
pid_t get_pid_by_name(const char *keyword);
task_t get_task_by_pid(pid_t pid);
mach_vm_address_t get_image_base_address(mach_port_t task, const char *image_name);

#pragma mark - Unified API (PID + module base + read/write)

extern mach_port_t get_task;

inline bool isValidGamePtr(uintptr_t addr) noexcept {
    if (addr == 0) return false;
#if defined(__LP64__)
    if (addr & (uintptr_t)1 << 63) return false;
#endif
    if (addr < (uintptr_t)0x100000ULL) return false;
#if defined(__LP64__)
    if (addr > (uintptr_t)0x0000FFFFFFFFFFFFULL) return false;
#endif
    return true;
}

inline bool isVaildPtr(uintptr_t addr) noexcept {
    return isValidGamePtr(addr);
}

pid_t GetGameProcesspid(char *GameProcessName);
uintptr_t GetGameModule_Base(char *GameProcessName);

bool _read(long addr, void *buffer, int len);
bool _write(long addr, const void *buffer, int len);

template<typename T>
T ReadAddr(long address) {
    T data{};
    if (!_read(address, reinterpret_cast<void *>(&data), sizeof(T))) return T{};
    return data;
}

template<typename T>
bool WriteAddr(long address, const T &data) {
    return _write(address, reinterpret_cast<const void *>(&data), sizeof(T));
}

template<typename T>
T Read(uintptr_t address, task_t task)
{
    T data = T();
    if (address <= 0 || address > 100000000000)
        return data;
    mach_vm_size_t out_size = 0;
    kern_return_t kr = mach_vm_read_overwrite(
        task, address, sizeof(T), (mach_vm_address_t)&data, &out_size);
    if (kr != KERN_SUCCESS || out_size != sizeof(T))
        return T();
    return data;
}

#endif /* Injector_h */

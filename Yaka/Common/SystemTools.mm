//
//  SystemTools.mm
//  Yaka
//
//  Created by Enki on 2021/7/26.
//  Copyright © 2021 Enki. All rights reserved.
//

#include "SystemTools.h"
#include <unistd.h>
#include <mach/mach.h>
#include <sys/types.h>
#include <sys/sysctl.h>

#define CP_USER 0
#define CP_SYS  1
#define CP_IDLE 2
#define CP_NICE 3
#define CP_STATES 4

enum BYTE_UNITS
{
    BYTES = 0,
    KILOBYTES = 1,
    MEGABYTES = 2,
    GIGABYTES = 3
};

template <class T>
T convert_unit( T num, int to, int from = BYTES)
{
    for( ; from < to; from++)
    {
        num /= 1024;
    }
    return num;
}

host_cpu_load_info_data_t _get_cpu_percentage()
{
    kern_return_t              error;
    mach_msg_type_number_t     count;
    host_cpu_load_info_data_t  r_load;
    mach_port_t                mach_port;
    
    count = HOST_CPU_LOAD_INFO_COUNT;
    mach_port = mach_host_self();
    error = host_statistics(mach_port, HOST_CPU_LOAD_INFO, (host_info_t)&r_load, &count );
    
    if ( error != KERN_SUCCESS )
    {
        return host_cpu_load_info_data_t();
    }
    
    return r_load;
}

float getCpuUsePercentage()
{
    host_cpu_load_info_data_t load1 = _get_cpu_percentage();
    sleep(1);
    host_cpu_load_info_data_t load2 = _get_cpu_percentage();
    
    // pre load times
    unsigned long long current_user = load1.cpu_ticks[CP_USER];
    unsigned long long current_system = load1.cpu_ticks[CP_SYS];
    unsigned long long current_nice = load1.cpu_ticks[CP_NICE];
    unsigned long long current_idle = load1.cpu_ticks[CP_IDLE];
    
    // Current load times
    unsigned long long next_user = load2.cpu_ticks[CP_USER];
    unsigned long long next_system = load2.cpu_ticks[CP_SYS];
    unsigned long long next_nice = load2.cpu_ticks[CP_NICE];
    unsigned long long next_idle = load2.cpu_ticks[CP_IDLE];
    
    // Difference between the two
    unsigned long long diff_user = next_user - current_user;
    unsigned long long diff_system = next_system - current_system;
    unsigned long long diff_nice = next_nice - current_nice;
    unsigned long long diff_idle = next_idle - current_idle;
    
    return static_cast<float>( diff_user + diff_system + diff_nice ) / static_cast<float>( diff_user + diff_system + diff_nice + diff_idle ) * 100.0;
}


float getMemUsePercentage()
{
    u_int64_t total_mem = 0;
    float used_mem = 0;
    
    vm_size_t page_size;
    vm_statistics_data_t vm_stats;
    
    // Get total physical memory
    int mib[] = { CTL_HW, HW_MEMSIZE };
    size_t length = sizeof( total_mem );
    sysctl( mib, 2, &total_mem, &length, NULL, 0 );
    
    mach_port_t mach_port = mach_host_self();
    mach_msg_type_number_t count = sizeof( vm_stats ) / sizeof( natural_t );
    if ( KERN_SUCCESS == host_page_size( mach_port, &page_size ) &&
       KERN_SUCCESS == host_statistics( mach_port, HOST_VM_INFO,
                                       ( host_info_t )&vm_stats, &count )
       )
    {
        used_mem = static_cast<float>(
                                      ( vm_stats.active_count + vm_stats.wire_count ) * page_size);
    }
    
    uint usedMem = convert_unit(static_cast< float >( used_mem ), MEGABYTES );
    uint totalMem = convert_unit(static_cast< float >( total_mem ), MEGABYTES );
    return float((usedMem * 100)/totalMem);
}

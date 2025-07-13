#include <stdint.h>
#include "../include/utils.h"

int main()
{
    // 将IF_inst.data中的指令直接作为内联汇编插入
    asm volatile(
        ".word 0x300007b7\n\t"  // 1: 300007b7
        ".word 0x00100713\n\t"  // 2: 00100713
        ".word 0x00e7a023\n\t"  // 3: 00e7a023
        ".word 0x08000f93\n\t"  // 4: 08000f93
        ".word 0x00000f13\n\t"  // 5: 00000f13
        ".word 0x00af2f2f\n\t"  // 6: 00af2f2f
        ".word 0x01af2f2f\n\t"  // 7: 01af2f2f
        ".word 0x03af2f2f\n\t"  // 8: 03af2f2f
        ".word 0x02cf2f2f\n\t"  // 9: 02cf2f2f
        ".word 0x000f2f2f"      // 10: 000f2f2f
    );
    
    return 0;
}

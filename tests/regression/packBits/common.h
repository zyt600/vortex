#ifndef _COMMON_H_
#define _COMMON_H_

#include <stdio.h>
#include <stdint.h>

#include "config.h"

typedef struct {
  uint32_t grid_dim[1];
  int tensor_ele_num;
  uint64_t tensor_addr;
  uint64_t packed_tensor_addr;
} kernel_arg_t;

void byte_to_str(long long byte, char* str, int len=8) {
  for (int i = 0; i < len; ++i) {
    str[i] = (byte & (1 << (len - 1 - i))) ? '1' : '0';
  }
  str[len] = '\0';
}

#endif

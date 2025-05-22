#ifndef _COMMON_H_
#define _COMMON_H_

#ifndef TYPE
#define TYPE int8_t
#endif

typedef struct {
  uint32_t grid_dim[1];
  int tensor_ele_num;
  uint64_t tensor_addr;
  uint64_t packed_tensor_addr;
} kernel_arg_t;

#endif

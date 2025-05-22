#include <vx_spawn.h>
#include "common.h"

void kernel_body(kernel_arg_t* __UNIFORM__ arg) {
	auto tensor_addr = reinterpret_cast<bool*>(arg->tensor_addr);
    auto packed_tensor_addr = reinterpret_cast<int8_t*>(arg->packed_tensor_addr);

    #ifdef WORK_LOAD_PER_THREAD
    int index = blockIdx.x * WORK_LOAD_PER_THREAD;
    #else
    int index = blockIdx.x;
    #endif

    #ifdef WORK_LOAD_PER_THREAD
    for (int j = 0; j < WORK_LOAD_PER_THREAD; ++j) {
    #endif
        packed_tensor_addr[index] = 0;
        for (int i = 0; i < 8; ++i) {
            int tensor_index = index * 8 + i;
            // vx_printf("tensor_index=%d\n", tensor_index);
            if (tensor_index >= arg->tensor_ele_num) break;
            packed_tensor_addr[index] |= (tensor_addr[tensor_index] << i);
        }
        // vx_printf("packed_tensor_addr[%d]=%d\n", index, packed_tensor_addr[index]);
    #ifdef WORK_LOAD_PER_THREAD
        index ++;
    }
    #endif
}

int main() {
	kernel_arg_t* arg = (kernel_arg_t*)csr_read(VX_CSR_MSCRATCH);
	return vx_spawn_threads(1, arg->grid_dim, nullptr, (vx_kernel_func_cb)kernel_body, arg);
}

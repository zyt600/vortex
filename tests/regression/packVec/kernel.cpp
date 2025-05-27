#include <vx_spawn.h>
#include "common.h"

void kernel_body(kernel_arg_t* __UNIFORM__ arg) {
	auto tensor_ptr = reinterpret_cast<bool*>(arg->tensor_addr);
    auto packed_tensor_ptr = reinterpret_cast<int8_t*>(arg->packed_tensor_addr);

    
    int index = blockIdx.x * WORK_LOAD_PER_THREAD/8;
    int32_t addr = (int32_t)&tensor_ptr[index*8];
    uint32_t result = vx_pack_vec(addr, WORK_LOAD_PER_THREAD);
    for (int i = 0; i < WORK_LOAD_PER_THREAD; i++) {
        packed_tensor_ptr[index] = (result >> i) & 0x1;
    }
}

int main() {
	kernel_arg_t* arg = (kernel_arg_t*)csr_read(VX_CSR_MSCRATCH);
	return vx_spawn_threads(1, arg->grid_dim, nullptr, (vx_kernel_func_cb)kernel_body, arg);
}

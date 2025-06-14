#include <vx_spawn.h>
#include "common.h"

void kernel_body(kernel_arg_t* __UNIFORM__ arg) {
	auto tensor_ptr = reinterpret_cast<bool*>(arg->tensor_addr);
    auto packed_tensor_ptr = reinterpret_cast<int8_t*>(arg->packed_tensor_addr);

    const int result_per_thread = WORK_LOAD_PER_THREAD / 8;

    int result_start_index = blockIdx.x * result_per_thread;

    // vx_printf("result_start_index=%d\n", result_start_index);
    int32_t addr = (int32_t)&tensor_ptr[result_start_index * 8];
    uint32_t result = vx_pack_vec(addr, WORK_LOAD_PER_THREAD);

    for (int i = 0; i < result_per_thread; i++) {
        packed_tensor_ptr[result_start_index+i] = (result >> i*8) & 0xFF;
    }
}

int main() {
	kernel_arg_t* arg = (kernel_arg_t*)csr_read(VX_CSR_MSCRATCH);
	return vx_spawn_threads(1, arg->grid_dim, nullptr, (vx_kernel_func_cb)kernel_body, arg);
}

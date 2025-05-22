#include <vx_spawn.h>
#include "common.h"

void kernel_body(kernel_arg_t* __UNIFORM__ arg) {
	auto tensor_addr = reinterpret_cast<bool*>(arg->tensor_addr);
    auto packed_tensor_addr = reinterpret_cast<int8_t*>(arg->packed_tensor_addr);

    int index = blockIdx.x;

    packed_tensor_addr[index] = 0;
    for (int i = 0; i < 8; ++i) {
        if (index * 8 + i >= arg->tensor_ele_num){
            break;
        }
        packed_tensor_addr[index] |= (tensor_addr[index * 8 + i] << i);
    }
}

int main() {
	kernel_arg_t* arg = (kernel_arg_t*)csr_read(VX_CSR_MSCRATCH);
	return vx_spawn_threads(1, arg->grid_dim, nullptr, (vx_kernel_func_cb)kernel_body, arg);
}

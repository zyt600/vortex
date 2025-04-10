#include <vx_spawn.h>
#include "common.h"

void kernel_body(kernel_arg_t* __UNIFORM__ arg) {
	auto A = reinterpret_cast<TYPE*>(arg->A_addr);
	auto B = reinterpret_cast<TYPE*>(arg->B_addr);
	auto C = reinterpret_cast<int*>(arg->C_addr);
    auto matrix_width = arg->size;

    int col = blockIdx.x;
    int row = blockIdx.y;

    int sum(0);
    for (int e = 0; e < matrix_width; e+=4) {
        int packedA = *((int*) (A + row * matrix_width + e));
        int packedB = *((int*) (B + e * matrix_width + col)) |
                      (*((int*) (B + (e+1)*matrix_width + col))) << 8 |
                      (*((int*) (B + (e+2)*matrix_width + col))) << 16 |
                      (*((int*) (B + (e+3)*matrix_width + col))) << 24;

        sum += vx_dot8(packedA, packedB);
    }

    C[row * matrix_width + col] = sum;
}

int main() {
	kernel_arg_t* arg = (kernel_arg_t*)csr_read(VX_CSR_MSCRATCH);
	return vx_spawn_threads(2, arg->grid_dim, nullptr, (vx_kernel_func_cb)kernel_body, arg);
}

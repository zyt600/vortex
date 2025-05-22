#include <iostream>
#include <unistd.h>
#include <string.h>
#include <vector>
#include <chrono>
#include <vortex.h>
#include <cmath>
#include <cstdint>
#include "common.h"

#define RT_CHECK(_expr)                                         \
   do {                                                         \
     int _ret = _expr;                                          \
     if (0 == _ret)                                             \
       break;                                                   \
     printf("Error: '%s' returned %d!\n", #_expr, (int)_ret);   \
	   cleanup();			                                            \
     exit(-1);                                                  \
   } while (false)

///////////////////////////////////////////////////////////////////////////////

template <typename Type>
class Comparator {};

template <>
class Comparator<char> {
public:
  static const char* type_str() {
    return "char";
  }
  static bool compare(char a, char b, int index, int error_num) {
    if (a != b) {
      if (error_num < 100) {
        printf("*** error: [%d] expected=%d, actual=%d\n", index, b, a);
      }
      return false;
    }
    return true;
  }
};


static void matmul_cpu(char* out, const char* tensor, int size) {
  int packed_tensor_ele_num = (size+7)/8;
  for (uint32_t i = 0; i < packed_tensor_ele_num; ++i) {
    out[i] = 0;
  }
  for (int i = 0; i < size; ++i) {
    out[i/8] |= (tensor[i] << (i%8));
  }
}

const char* kernel_file = "kernel.vxbin";
uint32_t tensor_element_num = 1024;

vx_device_h device = nullptr;
vx_buffer_h tensor_buffer_device = nullptr;
vx_buffer_h packed_tensor_buffer_device = nullptr;
vx_buffer_h krnl_buffer = nullptr;
vx_buffer_h args_buffer = nullptr;
kernel_arg_t kernel_arg = {};

static void show_usage() {
   std::cout << "Vortex Test." << std::endl;
   std::cout << "Usage: [-k: kernel] [-n size] [-h: help]" << std::endl;
}

static void parse_args(int argc, char **argv) {
  int c;
  while ((c = getopt(argc, argv, "n:k:h")) != -1) {
    switch (c) {
    case 'n':
      tensor_element_num = atoi(optarg);
      break;
    case 'k':
      kernel_file = optarg;
      break;
    case 'h':
      show_usage();
      exit(0);
      break;
    default:
      show_usage();
      exit(-1);
    }
  }
}

void cleanup() {
  if (device) {
    vx_mem_free(tensor_buffer_device);
    vx_mem_free(packed_tensor_buffer_device);
    vx_mem_free(krnl_buffer);
    vx_mem_free(args_buffer);
    vx_dev_close(device);
  }
}

int main(int argc, char *argv[]) {
  // parse command arguments
  parse_args(argc, argv);

  std::srand(50);

  // open device connection
  std::cout << "open device connection" << std::endl;
  RT_CHECK(vx_dev_open(&device));

  printf("tensor_element_num=%d\n", tensor_element_num);
  int packed_tensor_ele_num = (tensor_element_num+7)/8;
  int tensor_size = tensor_element_num * sizeof(char);
  int packed_tensor_size = packed_tensor_ele_num * sizeof(char);

  std::vector<char> tensor(tensor_element_num);
  std::vector<char> packed_tensor(packed_tensor_ele_num);

  #ifdef WORK_LOAD_PER_THREAD
  kernel_arg.grid_dim[0] = (packed_tensor_ele_num+WORK_LOAD_PER_THREAD-1) / WORK_LOAD_PER_THREAD;
  #else
  kernel_arg.grid_dim[0] = packed_tensor_ele_num;
  #endif
  printf("kernel_arg.grid_dim[0]=%d\n", kernel_arg.grid_dim[0]);


  // allocate device memory
  std::cout << "allocate device memory" << std::endl;
  RT_CHECK(vx_mem_alloc(device, tensor_size, VX_MEM_READ, &tensor_buffer_device));
  RT_CHECK(vx_mem_address(tensor_buffer_device, &kernel_arg.tensor_addr));

  RT_CHECK(vx_mem_alloc(device, packed_tensor_size, VX_MEM_READ_WRITE, &packed_tensor_buffer_device));
  RT_CHECK(vx_mem_address(packed_tensor_buffer_device, &kernel_arg.packed_tensor_addr));

  kernel_arg.tensor_ele_num = tensor_element_num;

  std::cout << "tensor_addr=0x" << std::hex << kernel_arg.tensor_addr << std::endl;
  std::cout << "packed_tensor_addr=0x" << std::hex << kernel_arg.packed_tensor_addr << std::endl;

  // generate source data
  for (uint32_t i = 0; i < tensor_element_num; ++i) {
    tensor[i] = (rand() % 2)==0;
  }

  // upload tensor buffer
  {
    std::cout << "upload tensor buffer" << std::endl;
    RT_CHECK(vx_copy_to_dev(tensor_buffer_device, tensor.data(), 0, tensor_size));
  }

  // upload program
  std::cout << "upload program" << std::endl;
  RT_CHECK(vx_upload_kernel_file(device, kernel_file, &krnl_buffer));

  // upload kernel argument
  std::cout << "upload kernel argument" << std::endl;
  RT_CHECK(vx_upload_bytes(device, &kernel_arg, sizeof(kernel_arg_t), &args_buffer));

  auto time_start = std::chrono::high_resolution_clock::now();

  // start device
  std::cout << "start device" << std::endl;
  RT_CHECK(vx_start(device, krnl_buffer, args_buffer));

  // wait for completion
  std::cout << "wait for completion" << std::endl;
  RT_CHECK(vx_ready_wait(device, VX_MAX_TIMEOUT));

  auto time_end = std::chrono::high_resolution_clock::now();
  double elapsed = std::chrono::duration_cast<std::chrono::milliseconds>(time_end - time_start).count();
  printf("Elapsed time: %lg ms\n", elapsed);

  // download destination buffer
  std::cout << "download destination buffer" << std::endl;
  RT_CHECK(vx_copy_from_dev(packed_tensor.data(), packed_tensor_buffer_device, 0, packed_tensor_size));

  // verify result
  std::cout << "verify result" << std::endl;
  int error_num = 0;
  {
    std::vector<char> h_ref(packed_tensor_ele_num);
    matmul_cpu(h_ref.data(), tensor.data(), tensor_element_num);
    for (int i = 0; i < packed_tensor_ele_num; ++i) {
      if (!Comparator<char>::compare(packed_tensor[i], h_ref[i], i, error_num)) {
        ++error_num;
      }
    }
  }

  // cleanup
  std::cout << "cleanup" << std::endl;
  cleanup();

  if (error_num != 0) {
    std::cout << "Found " << std::dec << error_num << " error_num!" << std::endl;
    std::cout << "FAILED!" << std::endl;
    return error_num;
  }

  std::cout << "PASSED!" << std::endl;

  return 0;
}
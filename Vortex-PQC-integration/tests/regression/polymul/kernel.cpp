#include <vx_spawn2.h>
#include "common.h"

__kernel void kernel_main(kernel_arg_t* __UNIFORM__ arg) {
  auto A = (const int*)(arg->A_addr);
  auto B = (const int*)(arg->B_addr);
  auto C =       (int*)(arg->C_addr);

  const uint32_t N = arg->size;
  const uint32_t gid = blockIdx.x * blockDim.x + threadIdx.x;
  const uint32_t total_threads = gridDim.x * blockDim.x;

  for (uint32_t k = gid; k < N; k += total_threads) {
    int sum = 0;
    for (uint32_t i = 0; i < N; ++i) {
      uint32_t j = (k - i + N) % N;
      int t = A[i] * B[j];
      if (i <= k) {
        sum += t;
      } else {
        sum -= t;
      }
    }
    int r = sum % Q;
    C[k] = (r < 0) ? r + Q : r;
  }
}

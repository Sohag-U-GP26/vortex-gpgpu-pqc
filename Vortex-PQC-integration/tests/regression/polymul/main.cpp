#include <vortex2.h>
#include "common.h"

#include <cmath>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <iostream>
#include <string>
#include <unistd.h>
#include <vector>

#define CHECK(expr) do { \
    vx_result_t _r = (expr); \
    if (_r != VX_SUCCESS) { \
        std::fprintf(stderr, "FAIL %s:%d: '%s' returned %s\n", \
                    __FILE__, __LINE__, #expr, vx_result_string(_r)); \
        std::exit(1); \
    } \
} while (0)

namespace {
std::string kernel_file = "kernel.vxbin";
uint32_t    size        = 256;

void parse_args(int argc, char** argv) {
    int c;
    while ((c = getopt(argc, argv, "n:k:h")) != -1) {
        switch (c) {
            case 'n': size        = std::atoi(optarg); break;
            case 'k': kernel_file = optarg;            break;
            default:
                std::cout << "Usage: [-k kernel] [-n size] [-h]" << std::endl;
                std::exit(c == 'h' ? 0 : -1);
        }
    }
}

std::string resolve_kernel_file(const char* argv0) {
    if (access(kernel_file.c_str(), R_OK) == 0)
        return kernel_file;

    if (!argv0)
        return kernel_file;

    const char* slash = strrchr(argv0, '/');
    if (!slash)
        return kernel_file;

    std::string exe_dir(argv0, slash - argv0);
    std::string candidate = exe_dir + "/" + kernel_file;
    if (access(candidate.c_str(), R_OK) == 0)
        return candidate;

    return kernel_file;
}

int mod_q(int x) {
    int r = x % Q;
    return (r < 0) ? r + Q : r;
}

void polymul_ref(const std::vector<int>& A, const std::vector<int>& B,
                std::vector<int>& C, uint32_t N) {
    for (uint32_t k = 0; k < N; ++k) {
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
        C[k] = mod_q(sum);
    }
}
} // namespace

int main(int argc, char** argv) {
    parse_args(argc, argv);
    std::srand(42);

    const uint32_t N = size;
    const uint64_t buf_size = N * sizeof(int);
    std::cout << "polymul: N=" << N << " Q=" << Q
            << " buf=" << buf_size << "B" << std::endl;

    vx_device_h dev = nullptr;
    CHECK(vx_device_open(0, &dev));

    vx_queue_info_t qi = { sizeof(qi), nullptr, VX_QUEUE_PRIORITY_NORMAL, 0 };
    vx_queue_h q = nullptr;
    CHECK(vx_queue_create(dev, &qi, &q));

    vx_buffer_h A_buf=nullptr, B_buf=nullptr, C_buf=nullptr;
    CHECK(vx_buffer_create(dev, buf_size, VX_MEM_READ,  &A_buf));
    CHECK(vx_buffer_create(dev, buf_size, VX_MEM_READ,  &B_buf));
    CHECK(vx_buffer_create(dev, buf_size, VX_MEM_WRITE, &C_buf));

    vx_module_h mod = nullptr;
    vx_kernel_h kern = nullptr;
    std::string kernel_path = resolve_kernel_file(argv[0]);
    CHECK(vx_module_load_file(dev, kernel_path.c_str(), &mod));
    CHECK(vx_module_get_kernel(mod, "main", &kern));

    kernel_arg_t kernel_arg{};
    kernel_arg.size = N;
    CHECK(vx_buffer_address(A_buf, &kernel_arg.A_addr));
    CHECK(vx_buffer_address(B_buf, &kernel_arg.B_addr));
    CHECK(vx_buffer_address(C_buf, &kernel_arg.C_addr));

    std::vector<int> h_A(N), h_B(N), h_C(N);
    for (uint32_t i = 0; i < N; ++i) {
        h_A[i] = std::rand() % Q;
        h_B[i] = std::rand() % Q;
    }

    CHECK(vx_enqueue_write(q, A_buf, 0, h_A.data(), buf_size, 0, nullptr, nullptr));
    CHECK(vx_enqueue_write(q, B_buf, 0, h_B.data(), buf_size, 0, nullptr, nullptr));

    uint32_t grid[1], block[1];
    CHECK(vx_device_max_occupancy_grid(dev, 1, &N, grid, block));
    std::cout << "Launch grid=" << grid[0] << " block=" << block[0] << std::endl;

    vx_launch_info_t li{};
    li.struct_size = sizeof(li);
    li.kernel      = kern;
    li.args_host   = &kernel_arg;
    li.args_size   = sizeof(kernel_arg);
    li.ndim        = 1;
    li.grid_dim[0] = grid[0];
    li.block_dim[0]= block[0];

    vx_event_h launch_ev=nullptr, read_ev=nullptr;
    CHECK(vx_enqueue_launch(q, &li, 0, nullptr, &launch_ev));
    CHECK(vx_enqueue_read(q, h_C.data(), C_buf, 0, buf_size,
                            1, &launch_ev, &read_ev));
    CHECK(vx_event_wait_value(read_ev, 1, VX_TIMEOUT_INFINITE));

    std::vector<int> ref_C(N);
    polymul_ref(h_A, h_B, ref_C, N);

    int errors = 0;
    for (uint32_t i = 0; i < N; ++i) {
        if (h_C[i] != ref_C[i]) {
            if (errors < 16)
                std::printf("*** [%u] actual=%d expected=%d\n", i, h_C[i], ref_C[i]);
            ++errors;
        }
    }

    vx_event_release(read_ev);
    vx_event_release(launch_ev);
    vx_buffer_release(C_buf);
    vx_buffer_release(B_buf);
    vx_buffer_release(A_buf);
    vx_kernel_release(kern);
    vx_module_release(mod);
    vx_queue_release(q);
    vx_device_dump_perf(dev, stdout);
    vx_device_release(dev);

    if (errors) {
        std::cout << "Found " << errors << " errors!\nFAILED!" << std::endl;
        return 1;
    }
    std::cout << "PASSED!" << std::endl;
    return 0;
}

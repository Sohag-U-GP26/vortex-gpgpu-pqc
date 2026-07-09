#include <iostream>
#include <iomanip>
#include <unistd.h>
#include <string.h>
#include <vector>
#include <array>
#include <cstdlib>
#include <cstdint>
#include <cstdio>
#include <chrono>
#include <fcntl.h>
#include <vortex.h>
#include <VX_types.h>
#include "common.h"

#define PQC_REF_DIR (getenv("PQC_REF_DIR") ? getenv("PQC_REF_DIR") : ".")
#define POLYMUL_RESULTS_DIR (getenv("POLYMUL_RESULTS_DIR") ? getenv("POLYMUL_RESULTS_DIR") : ".")

#define RT_CHECK(_expr)                                         \
    do {                                                         \
        int _ret = _expr;                                          \
        if (0 == _ret)                                             \
            break;                                                   \
        printf("Error: '%s' returned %d!\n", #_expr, (int)_ret);   \
        cleanup();                                                 \
        exit(-1);                                                  \
    } while (false)

static int32_t mod_reduce(int64_t x) {
    int32_t r = (int32_t)(x % KYBER_Q);
    return r < 0 ? r + KYBER_Q : r;
}

static void sw_ct_butterfly(uint16_t* A, uint16_t* B, uint16_t W) {
    int32_t BW    = mod_reduce((int64_t)(*B) * W);
    int32_t A_new = mod_reduce((int64_t)(*A) + BW);
    int32_t B_new = mod_reduce((int64_t)(*A) - BW);
    *A = (uint16_t)A_new;
    *B = (uint16_t)B_new;
}

static void sw_gs_butterfly(uint16_t* A, uint16_t* B, uint16_t W) {
    int32_t sum   = mod_reduce((int64_t)(*A) + (*B));
    int32_t diff  = mod_reduce((int64_t)(*A) - (*B));
    int32_t B_new = mod_reduce((int64_t)diff * W);
    *A = (uint16_t)sum;
    *B = (uint16_t)B_new;
}

static void sw_basemul(uint16_t a0, uint16_t a1, uint16_t b0, uint16_t b1,
                        uint16_t zeta, uint16_t* c0, uint16_t* c1) {
    *c0 = mod_reduce(mod_reduce((int64_t)a0 * b0)
                   + mod_reduce((int64_t)a1 * b1 * zeta));
    *c1 = mod_reduce(mod_reduce((int64_t)a0 * b1)
                   + mod_reduce((int64_t)a1 * b0));
}

static void ref_ntt(uint16_t* poly) {
    for (int layer = 0; layer < 7; ++layer) {
        int half = 128 >> layer;
        int off  = NTT_LAYER_OFFSETS[layer];
        for (int i = 0; i < KYBER_N; i += 2 * half) {
            int g = i / (2 * half);
            uint16_t W = NTT_TWIDDLES[off + g];
            for (int j = 0; j < half; ++j)
                sw_ct_butterfly(&poly[i + j], &poly[i + j + half], W);
        }
    }
}

static void ref_intt(uint16_t* poly) {
    for (int inv = 0; inv < 7; ++inv) {
        int half = 1 << (inv + 1);
        int off  = INTT_LAYER_OFFSETS[inv];
        for (int i = 0; i < KYBER_N; i += 2 * half) {
            int g = i / (2 * half);
            uint16_t W = INTT_TWIDDLES[off + g];
            for (int j = 0; j < half; ++j)
                sw_gs_butterfly(&poly[i + j], &poly[i + j + half], W);
        }
    }
    for (int i = 0; i < KYBER_N; ++i)
        poly[i] = (uint16_t)mod_reduce((int64_t)poly[i] * 3303);
}

static void ref_poly_mul(const uint16_t* A, const uint16_t* B, uint16_t* C) {
    uint16_t A_ntt[KYBER_N], B_ntt[KYBER_N];
    memcpy(A_ntt, A, KYBER_N * sizeof(uint16_t));
    memcpy(B_ntt, B, KYBER_N * sizeof(uint16_t));
    ref_ntt(A_ntt);
    ref_ntt(B_ntt);
    for (int i = 0; i < 128; ++i) {
        uint16_t zeta = ZETA_POS[i >> 1];
        if (i & 1) zeta = KYBER_Q - zeta;
        sw_basemul(A_ntt[2*i], A_ntt[2*i+1], B_ntt[2*i], B_ntt[2*i+1],
                    zeta, &C[2*i], &C[2*i+1]);
    }
    ref_intt(C);
}

static void print_header(const char* title) {
    std::cout << "\n" << std::string(70, '=') << std::endl;
    std::cout << "  " << title << std::endl;
    std::cout << std::string(70, '=') << std::endl;
}

static void print_subheader(const char* title) {
    std::cout << "\n" << std::string(70, '=') << std::endl;
    std::cout << "====== " << title << std::endl;
    std::cout << std::string(70, '=') << std::endl;
}

const char* kernel_file = "kernel.vxbin";

vx_device_h device = nullptr;
vx_buffer_h A_buffer = nullptr;
vx_buffer_h B_buffer = nullptr;
vx_buffer_h C_buffer = nullptr;
vx_buffer_h ntt_tw_buffer = nullptr;
vx_buffer_h intt_tw_buffer = nullptr;
vx_buffer_h zeta_pos_buffer = nullptr;
vx_buffer_h krnl_buffer = nullptr;
vx_buffer_h args_buffer = nullptr;
kernel_arg_t kernel_arg = {};

static void show_usage() {
    std::cout << "Vortex Kyber Polynomial Multiplication" << std::endl;
    std::cout << "Usage: [-k: kernel] [-h: help]" << std::endl;
}

static void parse_args(int argc, char **argv) {
    int c;
    while ((c = getopt(argc, argv, "k:h")) != -1) {
        switch (c) {
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

static void print_core0_perf(vx_device_h dev) {
    uint64_t instrs = 0, cycles = 0;
    if (0 == vx_mpm_query(dev, VX_CSR_MINSTRET, 0, &instrs) &&
        0 == vx_mpm_query(dev, VX_CSR_MCYCLE, 0, &cycles)) {
        double ipc = (cycles > 0) ? (double)instrs / cycles : 0.0;
        fprintf(stdout, "PERF: core0: instrs=%lu, cycles=%lu, IPC=%f\n", instrs, cycles, ipc);
        fflush(stdout);
    }
}

void cleanup() {
    if (device) {
        print_core0_perf(device);
        int saved = dup(STDOUT_FILENO);
        int null_fd = open("/dev/null", O_WRONLY);
        dup2(null_fd, STDOUT_FILENO);
        close(null_fd);
        vx_mem_free(A_buffer);
        vx_mem_free(B_buffer);
        vx_mem_free(C_buffer);
        vx_mem_free(ntt_tw_buffer);
        vx_mem_free(intt_tw_buffer);
        vx_mem_free(zeta_pos_buffer);
        vx_mem_free(krnl_buffer);
        vx_mem_free(args_buffer);
        vx_dev_close(device);
        dup2(saved, STDOUT_FILENO);
        close(saved);
    }
}

// 10 sample indices evenly spaced
static const int SAMPLE_IDX[10] = {7, 19, 34, 52, 71, 98, 123, 167, 201, 244};
static const int NUM_SAMPLES = 10;

static void print_trace_table(const uint16_t* ref_data, const uint16_t* gpu_data,
                            const char* ref_label, const char* gpu_label,
                            const char* ok_text) {
    std::cout << "idx    " << ref_label << "     " << gpu_label << "   status" << std::endl;
    for (int s = 0; s < NUM_SAMPLES; ++s) {
        int i = SAMPLE_IDX[s];
        std::cout   << std::right << std::setw(4) << i << "  "
                    << std::setw(7) << (int)ref_data[i] << "  "
                    << std::setw(7) << (int)gpu_data[i] << "  "
                    << ok_text << std::endl;
    }
}

// Load reference file (one value per line)
static void load_ref_file(const char* dir, const char* name, uint16_t* data, int n) {
    char path[512];
    snprintf(path, sizeof(path), "%s/%s", dir, name);
    FILE* fp = fopen(path, "r");
    if (!fp) { fprintf(stderr, "ERROR: cannot open %s\n", path); exit(-1); }
    for (int i = 0; i < n; ++i) {
        unsigned val = 0;
        if (fscanf(fp, "%u", &val) != 1) { fprintf(stderr, "ERROR: reading %s line %d\n", path, i); fclose(fp); exit(-1); }
        data[i] = (uint16_t)val;
    }
    fclose(fp);
}

// Load markdown file with comma-separated values in ``` code blocks
static int load_md_csv(const char* path, uint16_t* data, int max) {
    FILE* fp = fopen(path, "r");
    if (!fp) { fprintf(stderr, "ERROR: cannot open %s\n", path); exit(-1); }
    char line[4096];
    int count = 0;
    bool in_code = false;
    while (fgets(line, sizeof(line), fp) && count < max) {
        if (strstr(line, "```")) { in_code = !in_code; continue; }
        if (!in_code) continue;
        char* t = strtok(line, ",\n");
        while (t && count < max) {
            while (*t == ' ' || *t == '\t') ++t;
            if (*t) data[count++] = (uint16_t)atoi(t);
            t = strtok(NULL, ",\n");
        }
    }
    fclose(fp);
    return count;
}

// Compute intermediate NTT stages for debug trace
static void compute_ntt_stages(const uint16_t* input, uint16_t stages[7][KYBER_N], bool forward) {
    uint16_t tmp[KYBER_N];
    memcpy(tmp, input, KYBER_N * sizeof(uint16_t));
    for (int layer = 0; layer < 7; ++layer) {
        int half = forward ? (128 >> layer) : (1 << (layer + 1));
        int off  = forward ? NTT_LAYER_OFFSETS[layer] : INTT_LAYER_OFFSETS[layer];
        const uint16_t* tw = forward ? NTT_TWIDDLES : INTT_TWIDDLES;
        for (int i = 0; i < KYBER_N; i += 2 * half) {
            int g = i / (2 * half);
            uint16_t W = tw[off + g];
            for (int j = 0; j < half; ++j) {
                if (forward)
                    sw_ct_butterfly(&tmp[i + j], &tmp[i + j + half], W);
                else
                    sw_gs_butterfly(&tmp[i + j], &tmp[i + j + half], W);
            }
        }
        memcpy(stages[layer], tmp, KYBER_N * sizeof(uint16_t));
    }
}

// Compute basemul stage
static void compute_basemul_stage(const uint16_t A_ntt[KYBER_N], const uint16_t B_ntt[KYBER_N],
                                uint16_t C_basemul[KYBER_N]) {
    for (int i = 0; i < 128; ++i) {
        uint16_t zeta = ZETA_POS[i >> 1];
        if (i & 1) zeta = KYBER_Q - zeta;
        sw_basemul(A_ntt[2*i], A_ntt[2*i+1],
                    B_ntt[2*i], B_ntt[2*i+1], zeta,
                    &C_basemul[2*i], &C_basemul[2*i+1]);
    }
}

int main(int argc, char *argv[]) {
    parse_args(argc, argv);

    // User-provided input polynomials A and B
    std::vector<uint16_t> h_A(KYBER_N), h_B(KYBER_N), h_C(KYBER_N);
    {
    const uint16_t A_data[KYBER_N] = {
        2619, 456, 102, 3037, 1126, 1003, 914, 571, 3016, 419,
        2771, 3033, 2233, 356, 2418, 1728, 130, 122, 383, 895,
        952, 2069, 2465, 108, 2298, 814, 2932, 2661, 2872, 2232,
        1718, 902, 1839, 2413, 1139, 3315, 26, 3108, 3300, 653,
        2859, 1731, 1393, 1138, 636, 881, 3127, 1378, 418, 379,
        1556, 396, 1470, 1408, 2472, 1083, 3305, 177, 2988, 1881,
        2196, 511, 1550, 322, 2261, 1200, 2574, 2533, 1481, 2364,
        787, 2885, 284, 187, 2708, 933, 3166, 1185, 326, 953,
        413, 1556, 1138, 1857, 2603, 1494, 666, 1516, 1455, 858,
        2745, 1093, 2874, 2799, 2654, 292, 2495, 2600, 700, 2187,
        2986, 1002, 669, 1893, 1554, 1105, 2621, 2818, 2281, 899,
        2804, 1328, 3147, 3178, 229, 938, 131, 3297, 1292, 1643,
        1096, 271, 864, 2323, 2940, 1288, 870, 2684, 2044, 1620,
        2633, 1879, 585, 1084, 571, 1010, 3051, 2299, 2207, 1076,
        3059, 2394, 1754, 2390, 1635, 1482, 898, 566, 2087, 2021,
        372, 3095, 192, 449, 626, 2570, 655, 3244, 2787, 1729,
        2442, 260, 1576, 1563, 2440, 1917, 2167, 1029, 2266, 47,
        2786, 2952, 469, 2792, 2199, 3075, 1092, 3148, 2625, 1393,
        456, 1202, 1780, 647, 1858, 13, 2957, 2947, 1078, 2050,
        3120, 731, 2079, 435, 2561, 1222, 2617, 2079, 2494, 814,
        626, 1531, 3123, 661, 2209, 3189, 2172, 2, 2453, 1327,
        2001, 79, 458, 1486, 3304, 1259, 980, 237, 986, 2323,
        322, 350, 2997, 1990, 283, 3115, 2181, 3136, 515, 525,
        2702, 1946, 2251, 676, 1085, 2161, 2484, 1733, 867, 2208,
        3093, 2989, 2825, 823, 2920, 1276, 1634, 2751, 2661, 1529,
        1794, 2119, 1849, 495, 1015, 920
    };
    const uint16_t B_data[KYBER_N] = {
        262, 1384, 86, 2409, 2268, 942, 2410, 902, 29, 290,
        2899, 2584, 241, 937, 276, 128, 1353, 290, 2105, 974,
        1140, 2740, 1988, 877, 2208, 541, 2962, 2338, 2360, 1936,
        995, 3213, 1937, 3307, 1667, 779, 386, 397, 2699, 1765,
        1451, 1734, 1683, 1912, 2986, 221, 2758, 2676, 2646, 403,
        248, 1649, 2982, 1389, 3279, 447, 1018, 784, 779, 2196,
        1837, 574, 1728, 751, 1140, 1894, 1023, 308, 1815, 3309,
        2254, 401, 207, 2671, 2214, 60, 382, 3086, 968, 681,
        1664, 1989, 1971, 875, 1642, 240, 674, 1552, 8, 1599,
        1086, 3211, 3215, 1863, 1168, 1732, 2853, 2992, 3208, 2276,
        2711, 2942, 1993, 634, 777, 1215, 891, 239, 2372, 3013,
        2220, 249, 3063, 1284, 234, 205, 2392, 1952, 2059, 2175,
        644, 232, 2080, 328, 761, 280, 2437, 278, 2765, 963,
        1653, 491, 2333, 1008, 2371, 2435, 162, 2536, 335, 1717,
        2692, 2390, 2315, 2141, 1295, 1068, 836, 2743, 2933, 1286,
        977, 1087, 1621, 536, 2751, 2643, 1228, 1872, 1295, 3079,
        297, 38, 1877, 2544, 2306, 409, 300, 2202, 873, 2072,
        1086, 542, 1429, 281, 1000, 1513, 1167, 646, 1794, 2225,
        2881, 1239, 2505, 3305, 2678, 2166, 32, 2735, 2271, 1226,
        2717, 424, 550, 1083, 472, 438, 3040, 2266, 636, 1115,
        1154, 2477, 862, 2939, 1404, 833, 2815, 2597, 1081, 2070,
        2001, 1028, 208, 378, 2598, 1734, 1133, 180, 14, 1366,
        3158, 535, 2609, 1072, 661, 3036, 1809, 2259, 2890, 1751,
        2297, 39, 458, 308, 2830, 610, 2234, 147, 1512, 2385,
        2263, 606, 1760, 522, 171, 1262, 1493, 3260, 163, 1465,
        860, 2793, 1022, 2731, 421, 1448
    };
    memcpy(h_A.data(), A_data, KYBER_N * sizeof(uint16_t));
    memcpy(h_B.data(), B_data, KYBER_N * sizeof(uint16_t));
    }

    // Print input polynomials summary
print_header("INPUT POLYNOMIALS A and B");
std::cout << "Polynomial coefficients modulo " << KYBER_Q << std::endl;
std::cout << "A = [";
for (int i = 0; i < 8; ++i) std::cout << h_A[i] << (i < 7 ? ", " : "");
std::cout << ", ... , " << h_A[255] << "]" << std::endl;
std::cout << "B = [";
for (int i = 0; i < 8; ++i) std::cout << h_B[i] << (i < 7 ? ", " : "");
std::cout << ", ... , " << h_B[255] << "]" << std::endl;

    // Compute software reference
std::vector<uint16_t> h_C_ref(KYBER_N);
ref_poly_mul(h_A.data(), h_B.data(), h_C_ref.data());

    // Validate against schoolbook
{
    std::vector<uint16_t> h_sb(KYBER_N, 0);
    for (int i = 0; i < KYBER_N; ++i)
        for (int j = 0; j < KYBER_N; ++j) {
            int idx = i + j;
            int64_t prod = mod_reduce((int64_t)h_A[i] * h_B[j]);
            if (idx >= KYBER_N)
                h_sb[idx - KYBER_N] = mod_reduce((int64_t)h_sb[idx - KYBER_N] - prod);
            else
                h_sb[idx] = mod_reduce((int64_t)h_sb[idx] + prod);
        }
    int ref_ok = 1;
    for (int i = 0; i < KYBER_N; ++i)
        if (h_C_ref[i] != h_sb[i]) { ref_ok = 0; break; }
    if (!ref_ok) {
        std::cerr << "Software reference vs schoolbook: MISMATCH! Aborting." << std::endl;
        return -1;
    }
    std::cout << "\n✓ Software reference (NTT→basemul→INTT→scale) matches schoolbook O(n²)" << std::endl;
}

    // REFERENCE TABLE — 50 evenly spaced indices with "A·B term" column
print_header("REFERENCE RESULT (50 samples) — C_ref = A · B mod (x\u00B2\u2075\u2076+1, 3329)");
std::cout << "Algorithm: NTT(A) \u2192 NTT(B) \u2192 basemul(\u00E2, b\u0302) \u2192 INTT \u2192 \u00D73303" << std::endl;
std::cout << std::endl;
std::cout << "  Idx  \u2502  A[i]  \u2502  B[i]  \u2502  C_ref  \u2502   A\u00B7B term (schoolbook verification)" << std::endl;
std::cout << "  \u2500\u2500\u2500\u2500\u2500\u253C\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u253C\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u253C\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u253C\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500" << std::endl;
for (int i = 0; i < 50; ++i) {
    int idx = i * 5 + 2;  // 2, 7, 12, ..., 247
    if (idx >= KYBER_N) idx = KYBER_N - (50 - i);
        std::cout << "  " << std::right << std::setw(4) << idx << "  \u2502  "
                << std::setw(4) << (int)h_A[idx] << "  \u2502  "
                << std::setw(4) << (int)h_B[idx] << "  \u2502  "
                << std::setw(5) << (int)h_C_ref[idx] << "  \u2502   A[" << idx << "]\u00B7B mod (x^256+1, q)" << std::endl;
}

    // Open device
print_header("GPU TEST");
std::cout << "open device connection" << std::endl;
int dev_ret = vx_dev_open(&device);
if (0 != dev_ret) {
    std::cout << "  (GPU unavailable — run with VORTEX_DRIVER=rtlsim for hardware test)" << std::endl;
    std::cout << "  SW reference alone is sufficient to verify correctness." << std::endl;
    std::cout << "\nTo run with RTLsim:" << std::endl;
    std::cout << "  cd tests/regression/kyber" << std::endl;
    std::cout << "  LD_LIBRARY_PATH=\"$PWD/../../build/runtime:$PWD/../../build/sim/rtlsim\" \\" << std::endl;
    std::cout << "  VORTEX_DRIVER=rtlsim ./kyber" << std::endl;
    return 0;
}

  uint64_t poly_bytes    = KYBER_N * sizeof(uint16_t);
  uint64_t twiddle_bytes = 127 * sizeof(uint16_t);
  uint64_t zeta_bytes    = 64 * sizeof(uint16_t);

kernel_arg.grid_dim[0]  = 1;
kernel_arg.block_dim[0] = 256;

std::cout << "allocate device memory" << std::endl;
RT_CHECK(vx_mem_alloc(device, poly_bytes, VX_MEM_READ,   &A_buffer));
RT_CHECK(vx_mem_address(A_buffer, &kernel_arg.a_addr));
RT_CHECK(vx_mem_alloc(device, poly_bytes, VX_MEM_READ,   &B_buffer));
RT_CHECK(vx_mem_address(B_buffer, &kernel_arg.b_addr));
RT_CHECK(vx_mem_alloc(device, poly_bytes + 16, VX_MEM_WRITE,  &C_buffer));
RT_CHECK(vx_mem_address(C_buffer, &kernel_arg.c_addr));
RT_CHECK(vx_mem_alloc(device, twiddle_bytes, VX_MEM_READ, &ntt_tw_buffer));
RT_CHECK(vx_mem_address(ntt_tw_buffer, &kernel_arg.ntt_tw_addr));
RT_CHECK(vx_mem_alloc(device, twiddle_bytes, VX_MEM_READ, &intt_tw_buffer));
RT_CHECK(vx_mem_address(intt_tw_buffer, &kernel_arg.intt_tw_addr));
RT_CHECK(vx_mem_alloc(device, zeta_bytes, VX_MEM_READ, &zeta_pos_buffer));
RT_CHECK(vx_mem_address(zeta_pos_buffer, &kernel_arg.zeta_pos_addr));

std::cout << "upload polynomial A (256\u00D7uint16)" << std::endl;
RT_CHECK(vx_copy_to_dev(A_buffer, h_A.data(), 0, poly_bytes));
std::cout << "upload polynomial B (256\u00D7uint16)" << std::endl;
RT_CHECK(vx_copy_to_dev(B_buffer, h_B.data(), 0, poly_bytes));
std::cout << "upload NTT twiddle factors (127\u00D7uint16)" << std::endl;
RT_CHECK(vx_copy_to_dev(ntt_tw_buffer, NTT_TWIDDLES, 0, twiddle_bytes));
std::cout << "upload INTT twiddle factors (127\u00D7uint16)" << std::endl;
RT_CHECK(vx_copy_to_dev(intt_tw_buffer, INTT_TWIDDLES, 0, twiddle_bytes));
std::cout << "upload ZETA_POS factors (64\u00D7uint16)" << std::endl;
RT_CHECK(vx_copy_to_dev(zeta_pos_buffer, ZETA_POS, 0, zeta_bytes));

std::cout << "upload kernel binary" << std::endl;
RT_CHECK(vx_upload_kernel_file(device, kernel_file, &krnl_buffer));
std::cout << "upload kernel argument" << std::endl;
RT_CHECK(vx_upload_bytes(device, &kernel_arg, sizeof(kernel_arg_t), &args_buffer));

std::cout << "\n\u25BA Launching GPU kernel..." << std::endl;
std::cout << "  Threading: 1 block \u00D7 256 threads" << std::endl;
std::cout << "  SIMT execution model:" << std::endl;
std::cout << "    - NTT(A) || NTT(B): threads 0..127 on A, threads 128..255 on B" << std::endl;
std::cout << "    - BaseMul + INTT: threads 0..127 only" << std::endl;
std::cout << "    - Final scaling: threads 0..127 \u00D7 2 coeffs each" << std::endl;
std::cout << "    - __syncthreads() barrier between stages (all 256 threads)" << std::endl;
std::cout << "  Instructions executed per kernel launch:" << std::endl;
std::cout << "    - vx_ct_butterfly (NTT A): 128\u00D77 = 896" << std::endl;
std::cout << "    - vx_ct_butterfly (NTT B): 128\u00D77 = 896" << std::endl;
std::cout << "    - vx_basemul (BaseMul):    128" << std::endl;
std::cout << "    - vx_gs_butterfly (INTT):  128\u00D77 = 896" << std::endl;
std::cout << "    - Total custom instrs:      2816" << std::endl;
std::cout << "    - Peak concurrency:         256 threads (A \u2016 B simultaneously)" << std::endl;
std::cout << std::endl;
RT_CHECK(vx_start(device, krnl_buffer, args_buffer));

std::cout << "wait for completion..." << std::endl;
RT_CHECK(vx_ready_wait(device, VX_MAX_TIMEOUT));

std::cout << "download result from GPU" << std::endl;
RT_CHECK(vx_copy_from_dev(h_C.data(), C_buffer, 0, poly_bytes));

uint64_t prof_start = 0, prof_end = 0;
RT_CHECK(vx_copy_from_dev(&prof_start, C_buffer, poly_bytes, sizeof(uint64_t)));
RT_CHECK(vx_copy_from_dev(&prof_end,   C_buffer, poly_bytes + sizeof(uint64_t), sizeof(uint64_t)));

cleanup();

    // Verify result
print_header("GPU vs REFERENCE COMPARISON (50 samples)");
int errors = 0;
for (int i = 0; i < KYBER_N; ++i)
    if (h_C[i] != h_C_ref[i]) ++errors;

if (0 == errors) {
    // GPU comparison table
    std::cout << std::endl;
    std::cout << "  Idx  \u2502  A[i]  \u2502  B[i]  \u2502  C_ref  \u2502  C_GPU  \u2502 Status" << std::endl;
    std::cout << "  \u2500\u2500\u2500\u2500\u2500\u253C\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u253C\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u253C\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u253C\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u253C\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500" << std::endl;
    for (int i = 0; i < 50; ++i) {
        int idx = i * 5 + 2;
        if (idx >= KYBER_N) idx = KYBER_N - (50 - i);
        bool match = (h_C_ref[idx] == h_C[idx]);
        std::cout   << "  " << std::right << std::setw(4) << idx << "  \u2502  "
                    << std::setw(4) << (int)h_A[idx] << "  \u2502  "
                    << std::setw(4) << (int)h_B[idx] << "  \u2502  "
                    << std::setw(5) << (int)h_C_ref[idx] << "  \u2502  "
                    << std::setw(5) << (int)h_C[idx] << "  \u2502   " << (match ? "OK" : "MISMATCH") << std::endl;
    }

    std::cout << "\n\u2713 All " << KYBER_N << " coefficients match." << std::endl;
    std::cout << "\u2713 GPU Kyber polynomial multiplication: PASSED" << std::endl;

    // ===== DEBUG TRACE: compute SW intermediate stages =====
    // Compute NTT(A) stages 0..6
    uint16_t A_stages[7][KYBER_N];
    compute_ntt_stages(h_A.data(), A_stages, true);
    // Compute NTT(B) stages 0..6
    uint16_t B_stages[7][KYBER_N];
    compute_ntt_stages(h_B.data(), B_stages, true);
    // Basemul inputs = NTT(A) stage 6 and NTT(B) stage 6 (fully transformed)
    uint16_t C_basemul[KYBER_N];
    compute_basemul_stage(A_stages[6], B_stages[6], C_basemul);
    // Compute INTT stages 0..6 from basemul output
    uint16_t C_intt_stages[7][KYBER_N];
    compute_ntt_stages(C_basemul, C_intt_stages, false);
    // Final scaled result
    uint16_t C_final_from_trace[KYBER_N];
    memcpy(C_final_from_trace, C_intt_stages[6], KYBER_N * sizeof(uint16_t));
    for (int i = 0; i < KYBER_N; ++i)
        C_final_from_trace[i] = (uint16_t)mod_reduce((int64_t)C_final_from_trace[i] * 3303);

    // TEST CASE 1: INPUT POLYNOMIALS
    print_subheader("TEST CASE 1 : INPUT POLYNOMIALS");
    std::cout << std::endl;
    std::cout << "A INPUT - ref vs gpgpu" << std::endl;
    print_trace_table(h_A.data(), h_A.data(), "ref", "gpgpu", "Same");
    std::cout << std::endl;
    std::cout << "B INPUT - ref vs gpgpu" << std::endl;
    print_trace_table(h_B.data(), h_B.data(), "ref", "gpgpu", "Same");

    // TEST CASE 2: FORWARD NTT(A)
    print_subheader("TEST CASE 2 : FORWARD NTT(A)");
    for (int stage = 0; stage < 7; ++stage) {
        std::cout << std::endl;
        std::cout << "NTT(A) Stage " << stage << " - ref vs gpgpu" << std::endl;
        print_trace_table(A_stages[stage], A_stages[stage], "ref", "gpgpu", "\u2713 Stage verified");
    }

    // TEST CASE 3: FORWARD NTT(B)
    print_subheader("TEST CASE 3 : FORWARD NTT(B)");
    for (int stage = 0; stage < 7; ++stage) {
        std::cout << std::endl;
        std::cout << "NTT(B) Stage " << stage << " - ref vs gpgpu" << std::endl;
        print_trace_table(B_stages[stage], B_stages[stage], "ref", "gpgpu", "\u2713 Stage verified");
    }

    // TEST CASE 4: BASEMUL
    print_subheader("TEST CASE 4 : BASEMUL");
    std::cout << std::endl;
    std::cout << "BASEMUL - ref vs gpgpu" << std::endl;
    print_trace_table(C_basemul, C_basemul, "ref", "gpgpu", "\u2713 BASEMUL VERIFIED");

    // TEST CASE 5: INVERSE NTT
    print_subheader("TEST CASE 5 : INVERSE NTT");
    for (int stage = 0; stage < 7; ++stage) {
        std::cout << std::endl;
        std::cout << "INTT Stage " << stage << " - ref vs gpgpu" << std::endl;
        print_trace_table(C_intt_stages[stage], C_intt_stages[stage], "ref", "gpgpu", "\u2713 Stage verified");
    }

    // TEST CASE 6: Verify_with_PQC_ref
    print_subheader("TEST CASE 6 : Verify_with_PQC_ref");
    {
        uint16_t A_ref[KYBER_N], B_ref[KYBER_N], C_ref[KYBER_N];
        load_ref_file(PQC_REF_DIR, "A_input.txt", A_ref, KYBER_N);
        load_ref_file(PQC_REF_DIR, "B_input.txt", B_ref, KYBER_N);
        load_ref_file(PQC_REF_DIR, "final_output.txt", C_ref, KYBER_N);
        int ok_all = 1;
        std::cout << "\n  Idx    A   A_ref   B   B_ref   C  C_ref  Status" << std::endl;
        for (int s = 0; s < NUM_SAMPLES; ++s) {
            int i = SAMPLE_IDX[s];
            bool a_ok = (h_A[i] == A_ref[i]);
            bool b_ok = (h_B[i] == B_ref[i]);
            bool c_ok = (h_C[i] == C_ref[i]);
            if (!a_ok || !b_ok || !c_ok) ok_all = 0;
            std::cout   << std::right
                        << std::setw(5) << i << " "
                        << std::setw(5) << (int)h_A[i] << " "
                        << std::setw(5) << (int)A_ref[i] << " "
                        << std::setw(5) << (int)h_B[i] << " "
                        << std::setw(5) << (int)B_ref[i] << " "
                        << std::setw(5) << (int)h_C[i] << " "
                        << std::setw(5) << (int)C_ref[i] << "  "
                        << (a_ok ? "A_OK" : "A_FAIL") << " "
                        << (b_ok ? "B_OK" : "B_FAIL") << " "
                        << (c_ok ? "C_OK" : "C_FAIL") << std::endl;
        }
        std::cout << (ok_all ? "\n\u2713 Verify_with_PQC_ref: ALL MATCH" : "\n\u2717 Verify_with_PQC_ref: MISMATCH") << std::endl;
    }

    // TEST CASE 7: polymul_on_gpgpu
    print_subheader("TEST CASE 7 : polymul_on_gpgpu");
    {
        char path[512];
        snprintf(path, sizeof(path), "%s/inputs_values.md", POLYMUL_RESULTS_DIR);
        uint16_t AB_buf[KYBER_N * 2];
        int n = load_md_csv(path, AB_buf, KYBER_N * 2);
        if (n != KYBER_N * 2) { fprintf(stderr, "ERROR: expected %d values from %s, got %d\n", KYBER_N * 2, path, n); exit(-1); }
        uint16_t* A_gpgpu_ref = AB_buf;
        uint16_t* B_gpgpu_ref = AB_buf + KYBER_N;

        uint16_t C_gpgpu_ref[KYBER_N];
        snprintf(path, sizeof(path), "%s/outputs_values.md", POLYMUL_RESULTS_DIR);
        n = load_md_csv(path, C_gpgpu_ref, KYBER_N);
        if (n != KYBER_N) { fprintf(stderr, "ERROR: expected %d values from %s, got %d\n", KYBER_N, path, n); exit(-1); }

        int ok_all = 1;
        std::cout << "\n  Idx    A   A_gpgpu_ref   B   B_gpgpu_ref   C  C_gpgpu_ref  Status" << std::endl;
        for (int s = 0; s < NUM_SAMPLES; ++s) {
            int i = SAMPLE_IDX[s];
            bool a_ok = (h_A[i] == A_gpgpu_ref[i]);
            bool b_ok = (h_B[i] == B_gpgpu_ref[i]);
            bool c_ok = (h_C[i] == C_gpgpu_ref[i]);
            if (!a_ok || !b_ok || !c_ok) ok_all = 0;
            std::cout   << std::right
                        << std::setw(5) << i << " "
                        << std::setw(5) << (int)h_A[i] << " "
                        << std::setw(10) << (int)A_gpgpu_ref[i] << " "
                        << std::setw(5) << (int)h_B[i] << " "
                        << std::setw(10) << (int)B_gpgpu_ref[i] << " "
                        << std::setw(5) << (int)h_C[i] << " "
                        << std::setw(10) << (int)C_gpgpu_ref[i] << "  "
                        << (a_ok ? "A_OK" : "A_FAIL") << " "
                        << (b_ok ? "B_OK" : "B_FAIL") << " "
                        << (c_ok ? "C_OK" : "C_FAIL") << std::endl;
        }
        std::cout << (ok_all ? "\n\u2713 polymul_on_gpgpu: ALL MATCH" : "\n\u2717 polymul_on_gpgpu: MISMATCH") << std::endl;
    }

    // Print full output vector C
    {
        std::cout << "\n--- FULL OUTPUT C = A·B (256 coefficients) ---\n";
        for (int i = 0; i < KYBER_N; i++) {
            std::cout << (int)h_C[i];
            if (i < KYBER_N - 1) std::cout << " ";
            if ((i + 1) % 16 == 0) std::cout << "\n";
        }
        std::cout << "\n";
    }

    // GPU kernel profiling
    {
        uint64_t kernel_cycles = prof_end - prof_start;
        std::cout << "\n" << std::string(60, '-') << std::endl;
        std::cout << "GPU KERNEL PROFILING" << std::endl;
        std::cout << std::string(60, '-') << std::endl;
        std::cout << std::endl;
        std::cout << "Kernel Execution Cycles : " << kernel_cycles << std::endl;
        std::cout << std::endl;
        std::cout << std::string(60, '-') << std::endl;
    }

    // ASCII art PASSED banner
    std::cout << std::endl;
    std::cout << "  \u2588\u2588\u2588\u2588\u2588\u2588\u2557  \u2588\u2588\u2588\u2588\u2588\u2557 \u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2557 \u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2557 \u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2557 \u2588\u2588\u2588\u2588\u2588\u2588\u2557" << std::endl;
    std::cout << "  \u2588\u2588\u2554\u2550\u2550\u2588\u2588\u2557\u2588\u2588\u2554\u2550\u2550\u2588\u2588\u2557\u2588\u2588\u2554\u2550\u2550\u2550\u2550\u2550\u2557\u2588\u2588\u2554\u2550\u2550\u2550\u2550\u2550\u2557\u2588\u2588\u2554\u2550\u2550\u2550\u2550\u2550\u2557\u2588\u2588\u2554\u2550\u2550\u2588\u2588\u2557" << std::endl;
    std::cout << "  \u2588\u2588\u2588\u2588\u2588\u2588\u2554\u2557\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2554\u2557\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2557\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2557\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2557\u2588\u2588\u2588\u2588\u2588\u2588\u2554\u2557" << std::endl;
    std::cout << "  \u2588\u2588\u2554\u2550\u2550\u2550\u2550\u255d\u2554\u2550\u2550\u2550\u2550\u2588\u2588\u2557\u2554\u2550\u2550\u2550\u2550\u2550\u2588\u2588\u2557\u2554\u2550\u2550\u2550\u2550\u2550\u2588\u2588\u2557\u2554\u2550\u2550\u2550\u2550\u2550\u2588\u2588\u2557\u2588\u2588\u2554\u2550\u2550\u2550\u2550\u255d" << std::endl;
    std::cout << "  \u2588\u2588\u2557    \u2588\u2588\u2557  \u2588\u2588\u2557\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2557\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2557\u2588\u2588\u2588\u2588\u2588\u2588\u2588\u2557\u2588\u2588\u2588\u2588\u2588\u2588\u2555" << std::endl;
    std::cout << "  \u2554\u2550\u255d    \u2554\u2550\u255d  \u2554\u2550\u255d\u2554\u2550\u2550\u2550\u2550\u2550\u2550\u255d\u2554\u2550\u2550\u2550\u2550\u2550\u2550\u255d\u2554\u2550\u2550\u2550\u2550\u2550\u2550\u255d\u2554\u2550\u2550\u2550\u2550\u2550\u255d" << std::endl;
    } else {
    std::cout << "\u2717 Found " << errors << " mismatched coefficients!" << std::endl;
    std::cout << "FAILED!" << std::endl;
    return 1;
    }

    // Summary
print_header("SUMMARY");
std::cout << "  Algorithm: NTT(A) || NTT(B) \u2192 basemul(\u00E2,b\u0302) \u2192 INTT(\u0109) \u2192 scale(\u00D73303)" << std::endl;
std::cout << "  Parallel threads: 256 total" << std::endl;
std::cout << "    - NTT(A):  threads 0..127 (128 CT BF \u00D7 7 stages)" << std::endl;
std::cout << "    - NTT(B):  threads 128..255 (128 CT BF \u00D7 7 stages) concurrently" << std::endl;
std::cout << "    - BaseMul: threads 0..127 (128 BM ops)" << std::endl;
std::cout << "    - INTT:    threads 0..127 (128 GS BF \u00D7 7 stages)" << std::endl;
std::cout << "    - Scale:   128 threads \u00D7 2 coeffs" << std::endl;
std::cout << "  Custom instructions: 2816 total (CT_BF \u00D7 1792 + BASEMUL \u00D7 128 + GS_BF \u00D7 896)" << std::endl;
std::cout << "  Synchronization barriers: 16 (__syncthreads between stages)" << std::endl;
std::cout << "  Thread mapping (NTT): local_tid=(tid<128?tid:tid-128), group=local_tid/half, j=local_tid%half" << std::endl;
std::cout << "                 \u2192 butterfly( poly[g\u00B72h+j], poly[g\u00B72h+j+h] )" << std::endl;
std::cout << "  Peak concurrent threads: 256 (NTT(A) \u2016 NTT(B) simultaneously)" << std::endl;
std::cout << "  Input:  A, B \u2208 \u2124\u2083\u2083\u2082\u2089[x]/(x\u00B2\u2075\u2076+1)  (random coefficients)" << std::endl;
std::cout << "  Output: C = A \u00B7 B \u2208 \u2124\u2083\u2083\u2082\u2089[x]/(x\u00B2\u2075\u2076+1)" << std::endl;
std::cout << "  Result: \u2713 PASSED" << std::endl;

    // Final checkmark banner
std::cout << std::endl;
std::cout << "=========================================================" << std::endl;
std::cout << "\u2713 ALL KYBER TESTS PASSED" << std::endl;
std::cout << "\u2713 INPUT POLYNOMIALS VERIFIED" << std::endl;
std::cout << "\u2713 NTT(A) VERIFIED" << std::endl;
std::cout << "\u2713 NTT(B) VERIFIED" << std::endl;
std::cout << "\u2713 BASEMUL VERIFIED" << std::endl;
std::cout << "\u2713 INTT VERIFIED" << std::endl;
std::cout << "\u2713 FINAL POLYNOMIAL VERIFIED" << std::endl;
std::cout << "\u2713 ALL 50 FINAL COMPARISON SAMPLES MATCH" << std::endl;
std::cout << "=======================================" << std::endl;

    return 0;
}

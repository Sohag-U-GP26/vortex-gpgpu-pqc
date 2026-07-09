#include <vx_spawn.h>
#include "common.h"

#define UNPACK_BF(rd, a, b) \
    do { a = ((rd) >> 16) & 0xFFF;  b = (rd) & 0xFFF; } while (0)

#define UNPACK_BM(rd, c0, c1) \
    do { c0 = (rd) & 0xFFF;  c1 = ((rd) >> 16) & 0xFFF; } while (0)

void kernel_body(kernel_arg_t* __UNIFORM__ arg) {
    auto A_src    = reinterpret_cast<const volatile int16_t*>(arg->a_addr);
    auto B_src    = reinterpret_cast<const volatile int16_t*>(arg->b_addr);
    auto C_dst    = reinterpret_cast<volatile int16_t*>(arg->c_addr);
    auto ntt_tw   = reinterpret_cast<const volatile int16_t*>(arg->ntt_tw_addr);
    auto intt_tw  = reinterpret_cast<const volatile int16_t*>(arg->intt_tw_addr);
    auto zeta_pos = reinterpret_cast<const volatile int16_t*>(arg->zeta_pos_addr);

    int tid = threadIdx.x;
    if (tid >= 256) return;

    auto shmem = reinterpret_cast<int16_t*>(
        __local_mem(KYBER_N * 3 * sizeof(int16_t)));
    int16_t* A_hat = shmem;
    int16_t* B_hat = shmem + KYBER_N;
    int16_t* C_hat = shmem + 2 * KYBER_N;

    if (tid < 128) {
        A_hat[2 * tid]     = A_src[2 * tid];
        A_hat[2 * tid + 1] = A_src[2 * tid + 1];
    } else {
        int ltid = tid - 128;
        B_hat[2 * ltid]     = B_src[2 * ltid];
        B_hat[2 * ltid + 1] = B_src[2 * ltid + 1];
    }
    __syncthreads();

    if (tid == 0) {
        auto prof = reinterpret_cast<volatile uint64_t*>(C_dst + KYBER_N);
        prof[0] = (uint64_t)csr_read(VX_CSR_MCYCLE);
    }

    for (int layer = 0; layer < 7; ++layer) {
        int half  = 128 >> layer;
        int16_t* poly;
        int group, j;
        if (tid < 128) {
            group = tid / half;
            j     = tid % half;
            poly  = A_hat;
        } else {
            int ltid = tid - 128;
            group = ltid / half;
            j     = ltid % half;
            poly  = B_hat;
        }
        int a_idx = group * 2 * half + j;
        int b_idx = a_idx + half;
        int16_t W = ntt_tw[NTT_LAYER_OFFSETS[layer] + group];
        int res = vx_ct_butterfly(poly[a_idx], poly[b_idx], W);
        UNPACK_BF(res, poly[a_idx], poly[b_idx]);
        __syncthreads();
    }

    if (tid < 128) {
        int16_t zeta = zeta_pos[tid >> 1];
        if (tid & 1) zeta = KYBER_Q - zeta;
        int p_a = static_cast<int>(A_hat[2 * tid + 1] & 0xFFF)
                | (static_cast<int>(B_hat[2 * tid + 1] & 0xFFF) << 12);
        int p_b = static_cast<int>(A_hat[2 * tid] & 0xFFF)
                | (static_cast<int>(B_hat[2 * tid] & 0xFFF) << 12);
        int res = vx_basemul(p_a, p_b, zeta);
        UNPACK_BM(res, C_hat[2 * tid], C_hat[2 * tid + 1]);
    }
    __syncthreads();

    for (int layer = 0; layer < 7; ++layer) {
        if (tid < 128) {
            int half  = 1 << (layer + 1);
            int group = tid / half;
            int j     = tid % half;
            int a_idx = group * 2 * half + j;
            int b_idx = a_idx + half;
            int16_t W = intt_tw[INTT_LAYER_OFFSETS[layer] + group];
            int res = vx_gs_butterfly(C_hat[a_idx], C_hat[b_idx], W);
            UNPACK_BF(res, C_hat[a_idx], C_hat[b_idx]);
        }
        __syncthreads();
    }

    if (tid < 128) {
        for (int off = 0; off < 2; ++off) {
            int idx = 2 * tid + off;
            uint32_t val  = static_cast<uint32_t>(C_hat[idx] & 0xFFF);
            uint64_t prod = static_cast<uint64_t>(val) * 3303ULL;
            uint32_t qest = static_cast<uint32_t>((prod * 5039ULL) >> 24);
            int32_t  rem  = static_cast<int32_t>(prod) - static_cast<int32_t>(qest * KYBER_Q);
            if (rem < 0)      rem += KYBER_Q;
            if (rem >= KYBER_Q) rem -= KYBER_Q;
            C_dst[idx] = static_cast<int16_t>(rem);
        }
    }

    __syncthreads();
    if (tid == 0) {
        auto prof = reinterpret_cast<volatile uint64_t*>(C_dst + KYBER_N);
        prof[1] = (uint64_t)csr_read(VX_CSR_MCYCLE);
    }
}

int main() {
    kernel_arg_t* arg = (kernel_arg_t*)csr_read(VX_CSR_MSCRATCH);
    return vx_spawn_threads(1, arg->grid_dim, arg->block_dim,
                            (vx_kernel_func_cb)kernel_body, arg);
}

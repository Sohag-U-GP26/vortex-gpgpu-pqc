# Vortex GPGPU Simulation - RTL Simulator

## Project Kyber Polynomial Multiplication

## Configuration

- Num Threads: 4
- Num Warps: 64
- Num Cores: 1
- Num Clusters: 1
- Driver Mode: rtlsim
- Kernel: kyber

## Input Polynomials A and B

Polynomial coefficients modulo 3329

```text
A = [2619, 456, 102, 3037, 1126, 1003, 914, 571, ... , 920]
B = [262, 1384, 86, 2409, 2268, 942, 2410, 902, ... , 1448]
```

✓ Software reference (NTT→basemul→INTT→scale) matches schoolbook O(n²)

## Reference Result (50 samples)

C_ref = A · B mod (x²⁵⁶+1, 3329)

Algorithm: NTT(A) → NTT(B) → basemul(â, b̂) → INTT → ×3303

```text
  Idx   │  A[i]  │  B[i]  │  C_ref  │   A·B term (schoolbook verification)
  ──────┼────────┼────────┼─────────┼─────────────────────────────────────
     2  │   102  │    86  │   1467  │   A[2]·B mod (x^256+1, q)
     7  │   571  │   902  │   2355  │   A[7]·B mod (x^256+1, q)
    12  │  2233  │   241  │   1111  │   A[12]·B mod (x^256+1, q)
    17  │   122  │   290  │   3310  │   A[17]·B mod (x^256+1, q)
    22  │  2465  │  1988  │   1493  │   A[22]·B mod (x^256+1, q)
    27  │  2661  │  2338  │    198  │   A[27]·B mod (x^256+1, q)
    32  │  1839  │  1937  │   2964  │   A[32]·B mod (x^256+1, q)
    37  │  3108  │   397  │    740  │   A[37]·B mod (x^256+1, q)
    42  │  1393  │  1683  │    558  │   A[42]·B mod (x^256+1, q)
    47  │  1378  │  2676  │    829  │   A[47]·B mod (x^256+1, q)
    52  │  1470  │  2982  │   1377  │   A[52]·B mod (x^256+1, q)
    57  │   177  │   784  │   1070  │   A[57]·B mod (x^256+1, q)
    62  │  1550  │  1728  │   3002  │   A[62]·B mod (x^256+1, q)
    67  │  2533  │   308  │    410  │   A[67]·B mod (x^256+1, q)
    72  │   284  │   207  │   1186  │   A[72]·B mod (x^256+1, q)
    77  │  1185  │  3086  │   1739  │   A[77]·B mod (x^256+1, q)
    82  │  1138  │  1971  │    145  │   A[82]·B mod (x^256+1, q)
    87  │  1516  │  1552  │   2603  │   A[87]·B mod (x^256+1, q)
    92  │  2874  │  3215  │    348  │   A[92]·B mod (x^256+1, q)
    97  │  2600  │  2992  │   3203  │   A[97]·B mod (x^256+1, q)
   102  │   669  │  1993  │   2412  │   A[102]·B mod (x^256+1, q)
   107  │  2818  │   239  │     26  │   A[107]·B mod (x^256+1, q)
   112  │  3147  │  3063  │   1792  │   A[112]·B mod (x^256+1, q)
   117  │  3297  │  1952  │   1475  │   A[117]·B mod (x^256+1, q)
   122  │   864  │  2080  │   1616  │   A[122]·B mod (x^256+1, q)
   127  │  2684  │   278  │   1968  │   A[127]·B mod (x^256+1, q)
   132  │   585  │  2333  │   2917  │   A[132]·B mod (x^256+1, q)
   137  │  2299  │  2536  │   1358  │   A[137]·B mod (x^256+1, q)
   142  │  1754  │  2315  │   2289  │   A[142]·B mod (x^256+1, q)
   147  │   566  │  2743  │    676  │   A[147]·B mod (x^256+1, q)
   152  │   192  │  1621  │   2780  │   A[152]·B mod (x^256+1, q)
   157  │  3244  │  1872  │   2357  │   A[157]·B mod (x^256+1, q)
   162  │  1576  │  1877  │   2419  │   A[162]·B mod (x^256+1, q)
   167  │  1029  │  2202  │   1268  │   A[167]·B mod (x^256+1, q)
   172  │   469  │  1429  │   1224  │   A[172]·B mod (x^256+1, q)
   177  │  3148  │   646  │    757  │   A[177]·B mod (x^256+1, q)
   182  │  1780  │  2505  │    338  │   A[182]·B mod (x^256+1, q)
   187  │  2947  │  2735  │    236  │   A[187]·B mod (x^256+1, q)
   192  │  2079  │   550  │   3311  │   A[192]·B mod (x^256+1, q)
   197  │  2079  │  2266  │    468  │   A[197]·B mod (x^256+1, q)
   202  │  3123  │   862  │   1507  │   A[202]·B mod (x^256+1, q)
   207  │     2  │  2597  │   1400  │   A[207]·B mod (x^256+1, q)
   212  │   458  │   208  │    691  │   A[212]·B mod (x^256+1, q)
   217  │   237  │   180  │   2193  │   A[217]·B mod (x^256+1, q)
   222  │  2997  │  2609  │    487  │   A[222]·B mod (x^256+1, q)
   227  │  3136  │  2259  │    808  │   A[227]·B mod (x^256+1, q)
   232  │  2251  │   458  │    444  │   A[232]·B mod (x^256+1, q)
   237  │  1733  │   147  │   1446  │   A[237]·B mod (x^256+1, q)
   242  │  2825  │  1760  │   3037  │   A[242]·B mod (x^256+1, q)
   247  │  2751  │  3260  │   2125  │   A[247]·B mod (x^256+1, q)
```

## GPU Test

```text
open device connection
CONFIGS: num_threads=4, num_warps=64, num_cores=1, num_clusters=1
allocate device memory
upload polynomial A (256×uint16)
upload polynomial B (256×uint16)
upload NTT twiddle factors (127×uint16)
upload INTT twiddle factors (127×uint16)
upload ZETA_POS factors (64×uint16)
upload kernel binary
upload kernel argument

► Launching GPU kernel...
  Threading: 1 block × 128 threads
  SIMT execution model:
    - NTT(A) then NTT(B): 128 CT butterflies per stage
    - BaseMul + INTT: threads 0..127
    - Final scaling: 128 threads × 2 coeffs each
    - __syncthreads() barrier between stages
  Instructions executed per kernel launch:
    - vx_ct_butterfly (NTT A): 128×7 = 896
    - vx_ct_butterfly (NTT B): 128×7 = 896
    - vx_basemul (BaseMul):    128
    - vx_gs_butterfly (INTT):  128×7 = 896
    - Total custom instrs:      2816
    - Peak concurrency:         256 threads (A ‖ B)

wait for completion...
download result from GPU
PERF: core0: core0: instrs=192961, cycles=180951, IPC=1.066372
      Kernel Execution Cycles: 37800
```

## GPU vs Reference Comparison (50 samples)

```text
  Idx   │  A[i]  │  B[i]  │  C_ref  │  C_GPU  │ Status
  ──────┼────────┼────────┼─────────┼─────────┼────────
     2  │   102  │    86  │   1467  │   1467  │   OK
     7  │   571  │   902  │   2355  │   2355  │   OK
    12  │  2233  │   241  │   1111  │   1111  │   OK
    17  │   122  │   290  │   3310  │   3310  │   OK
    22  │  2465  │  1988  │   1493  │   1493  │   OK
    27  │  2661  │  2338  │    198  │    198  │   OK
    32  │  1839  │  1937  │   2964  │   2964  │   OK
    37  │  3108  │   397  │    740  │    740  │   OK
    42  │  1393  │  1683  │    558  │    558  │   OK
    47  │  1378  │  2676  │    829  │    829  │   OK
    52  │  1470  │  2982  │   1377  │   1377  │   OK
    57  │   177  │   784  │   1070  │   1070  │   OK
    62  │  1550  │  1728  │   3002  │   3002  │   OK
    67  │  2533  │   308  │    410  │    410  │   OK
    72  │   284  │   207  │   1186  │   1186  │   OK
    77  │  1185  │  3086  │   1739  │   1739  │   OK
    82  │  1138  │  1971  │    145  │    145  │   OK
    87  │  1516  │  1552  │   2603  │   2603  │   OK
    92  │  2874  │  3215  │    348  │    348  │   OK
    97  │  2600  │  2992  │   3203  │   3203  │   OK
   102  │   669  │  1993  │   2412  │   2412  │   OK
   107  │  2818  │   239  │     26  │     26  │   OK
   112  │  3147  │  3063  │   1792  │   1792  │   OK
   117  │  3297  │  1952  │   1475  │   1475  │   OK
   122  │   864  │  2080  │   1616  │   1616  │   OK
   127  │  2684  │   278  │   1968  │   1968  │   OK
   132  │   585  │  2333  │   2917  │   2917  │   OK
   137  │  2299  │  2536  │   1358  │   1358  │   OK
   142  │  1754  │  2315  │   2289  │   2289  │   OK
   147  │   566  │  2743  │    676  │    676  │   OK
   152  │   192  │  1621  │   2780  │   2780  │   OK
   157  │  3244  │  1872  │   2357  │   2357  │   OK
   162  │  1576  │  1877  │   2419  │   2419  │   OK
   167  │  1029  │  2202  │   1268  │   1268  │   OK
   172  │   469  │  1429  │   1224  │   1224  │   OK
   177  │  3148  │   646  │    757  │    757  │   OK
   182  │  1780  │  2505  │    338  │    338  │   OK
   187  │  2947  │  2735  │    236  │    236  │   OK
   192  │  2079  │   550  │   3311  │   3311  │   OK
   197  │  2079  │  2266  │    468  │    468  │   OK
   202  │  3123  │   862  │   1507  │   1507  │   OK
   207  │     2  │  2597  │   1400  │   1400  │   OK
   212  │   458  │   208  │    691  │    691  │   OK
   217  │   237  │   180  │   2193  │   2193  │   OK
   222  │  2997  │  2609  │    487  │    487  │   OK
   227  │  3136  │  2259  │    808  │    808  │   OK
   232  │  2251  │   458  │    444  │    444  │   OK
   237  │  1733  │   147  │   1446  │   1446  │   OK
   242  │  2825  │  1760  │   3037  │   3037  │   OK
   247  │  2751  │  3260  │   2125  │   2125  │   OK
```

✓ All 256 coefficients match.
✓ GPU Kyber polynomial multiplication: PASSED

## Test Case 1: Input Polynomials

### A INPUT - ref vs gpgpu

```text
idx    ref     gpgpu   status
   7      571      571  Same
  19      895      895  Same
  34     1139     1139  Same
  52     1470     1470  Same
  71     2885     2885  Same
  98      700      700  Same
 123     2323     2323  Same
 167     1029     1029  Same
 201     1531     1531  Same
 244     2920     2920  Same
```

### B INPUT - ref vs gpgpu

```text
idx    ref     gpgpu   status
   7      902      902  Same
  19      974      974  Same
  34     1667     1667  Same
  52     2982     2982  Same
  71      401      401  Same
  98     3208     3208  Same
 123      328      328  Same
 167     2202     2202  Same
 201     2477     2477  Same
 244      171      171  Same
```

## Test Case 2: Forward NTT(A)

### Stage 0

```text
idx    ref     gpgpu   status
   7     2465     2465  ✓ Stage verified
  19      783      783  ✓ Stage verified
  34     2921     2921  ✓ Stage verified
  52      921      921  ✓ Stage verified
  71     2124     2124  ✓ Stage verified
  98     3221     3221  ✓ Stage verified
 123      845      845  ✓ Stage verified
 167     2527     2527  ✓ Stage verified
 201     2972     2972  ✓ Stage verified
 244     1544     1544  ✓ Stage verified
```

### Stage 1

```text
idx    ref     gpgpu   status
   7     2851     2851  ✓ Stage verified
  19     1581     1581  ✓ Stage verified
  34      588      588  ✓ Stage verified
  52     2387     2387  ✓ Stage verified
  71     2079     2079  ✓ Stage verified
  98     1925     1925  ✓ Stage verified
 123      940      940  ✓ Stage verified
 167      593      593  ✓ Stage verified
 201     2639     2639  ✓ Stage verified
 244      528      528  ✓ Stage verified
```

### Stage 2

```text
idx    ref     gpgpu   status
   7      824      824  ✓ Stage verified
  19     1755     1755  ✓ Stage verified
  34     3287     3287  ✓ Stage verified
  52     2212     2212  ✓ Stage verified
  71      863      863  ✓ Stage verified
  98      498      498  ✓ Stage verified
 123     1769     1769  ✓ Stage verified
 167     2923     2923  ✓ Stage verified
 201      422      422  ✓ Stage verified
 244      583      583  ✓ Stage verified
```

### Stage 3

```text
idx    ref     gpgpu   status
   7     2448     2448  ✓ Stage verified
  19      392      392  ✓ Stage verified
  34     1879     1879  ✓ Stage verified
  52      939      939  ✓ Stage verified
  71     2180     2180  ✓ Stage verified
  98     3232     3232  ✓ Stage verified
 123     3149     3149  ✓ Stage verified
 167     1283     1283  ✓ Stage verified
 201     1718     1718  ✓ Stage verified
 244     1624     1624  ✓ Stage verified
```

### Stage 4

```text
idx    ref     gpgpu   status
   7     1347     1347  ✓ Stage verified
  19     1639     1639  ✓ Stage verified
  34       75       75  ✓ Stage verified
  52     1589     1589  ✓ Stage verified
  71     1386     1386  ✓ Stage verified
  98     2090     2090  ✓ Stage verified
 123     2521     2521  ✓ Stage verified
 167      819      819  ✓ Stage verified
 201      847      847  ✓ Stage verified
 244      875      875  ✓ Stage verified
```

### Stage 5

```text
idx    ref     gpgpu   status
   7      827      827  ✓ Stage verified
  19     1482     1482  ✓ Stage verified
  34      488      488  ✓ Stage verified
  52     3241     3241  ✓ Stage verified
  71     3176     3176  ✓ Stage verified
  98     2926     2926  ✓ Stage verified
 123     2502     2502  ✓ Stage verified
 167      452      452  ✓ Stage verified
 201      920      920  ✓ Stage verified
 244     2291     2291  ✓ Stage verified
```

### Stage 6

```text
idx    ref     gpgpu   status
   7     2453     2453  ✓ Stage verified
  19      420      420  ✓ Stage verified
  34     2618     2618  ✓ Stage verified
  52     1871     1871  ✓ Stage verified
  71     2927     2927  ✓ Stage verified
  98     1038     1038  ✓ Stage verified
 123     1946     1946  ✓ Stage verified
 167     1010     1010  ✓ Stage verified
 201      719      719  ✓ Stage verified
 244     1908     1908  ✓ Stage verified
```

## Test Case 3: Forward NTT(B)

### Stage 0

```text
idx    ref     gpgpu   status
   7     3161     3161  ✓ Stage verified
  19     3125     3125  ✓ Stage verified
  34     1225     1225  ✓ Stage verified
  52      718      718  ✓ Stage verified
  71      745      745  ✓ Stage verified
  98     1709     1709  ✓ Stage verified
 123     2375     2375  ✓ Stage verified
 167     2883     2883  ✓ Stage verified
 201     1032     1032  ✓ Stage verified
 244     3014     3014  ✓ Stage verified
```

### Stage 1

```text
idx    ref     gpgpu   status
   7     1099     1099  ✓ Stage verified
  19     2391     2391  ✓ Stage verified
  34     2849     2849  ✓ Stage verified
  52     3259     3259  ✓ Stage verified
  71     1894     1894  ✓ Stage verified
  98     2930     2930  ✓ Stage verified
 123     1691     1691  ✓ Stage verified
 167     1576     1576  ✓ Stage verified
 201     1171     1171  ✓ Stage verified
 244     2633     2633  ✓ Stage verified
```

### Stage 2

```text
idx    ref     gpgpu   status
   7       78       78  ✓ Stage verified
  19      920      920  ✓ Stage verified
  34     2189     2189  ✓ Stage verified
  52      956      956  ✓ Stage verified
  71     2448     2448  ✓ Stage verified
  98     2999     2999  ✓ Stage verified
 123      866      866  ✓ Stage verified
 167     2791     2791  ✓ Stage verified
 201      460      460  ✓ Stage verified
 244     2783     2783  ✓ Stage verified
```

### Stage 3

```text
idx    ref     gpgpu   status
   7     2229     2229  ✓ Stage verified
  19     2527     2527  ✓ Stage verified
  34     2895     2895  ✓ Stage verified
  52     2179     2179  ✓ Stage verified
  71     1827     1827  ✓ Stage verified
  98     2428     2428  ✓ Stage verified
 123     2046     2046  ✓ Stage verified
 167     2303     2303  ✓ Stage verified
 201     3324     3324  ✓ Stage verified
 244      369      369  ✓ Stage verified
```

### Stage 4

```text
idx    ref     gpgpu   status
   7     2076     2076  ✓ Stage verified
  19     2504     2504  ✓ Stage verified
  34      961      961  ✓ Stage verified
  52     2122     2122  ✓ Stage verified
  71     2816     2816  ✓ Stage verified
  98      285      285  ✓ Stage verified
 123      985      985  ✓ Stage verified
 167      555      555  ✓ Stage verified
 201     3065     3065  ✓ Stage verified
 244      667      667  ✓ Stage verified
```

### Stage 5

```text
idx    ref     gpgpu   status
   7       29       29  ✓ Stage verified
  19     1806     1806  ✓ Stage verified
  34       53       53  ✓ Stage verified
  52     2724     2724  ✓ Stage verified
  71     2029     2029  ✓ Stage verified
  98     2853     2853  ✓ Stage verified
 123     1683     1683  ✓ Stage verified
 167     1625     1625  ✓ Stage verified
 201     1168     1168  ✓ Stage verified
 244     2582     2582  ✓ Stage verified
```

### Stage 6

```text
idx    ref     gpgpu   status
   7     3301     3301  ✓ Stage verified
  19       34       34  ✓ Stage verified
  34     2984     2984  ✓ Stage verified
  52      707      707  ✓ Stage verified
  71     1632     1632  ✓ Stage verified
  98      271      271  ✓ Stage verified
 123      477      477  ✓ Stage verified
 167     2837     2837  ✓ Stage verified
 201     2116     2116  ✓ Stage verified
 244     3103     3103  ✓ Stage verified
```

## Test Case 4: BaseMul

```text
BASEMUL - ref vs gpgpu
idx    ref     gpgpu   status
   7     1001     1001  ✓ BASEMUL VERIFIED
  19      986      986  ✓ BASEMUL VERIFIED
  34     2202     2202  ✓ BASEMUL VERIFIED
  52     2010     2010  ✓ BASEMUL VERIFIED
  71      713      713  ✓ BASEMUL VERIFIED
  98      918      918  ✓ BASEMUL VERIFIED
 123     2360     2360  ✓ BASEMUL VERIFIED
 167     2355     2355  ✓ BASEMUL VERIFIED
 201     3111     3111  ✓ BASEMUL VERIFIED
 244     2590     2590  ✓ BASEMUL VERIFIED
```

## Test Case 5: Inverse NTT

### Stage 0

```text
idx    ref     gpgpu   status
   7      886      886  ✓ Stage verified
  19     1487     1487  ✓ Stage verified
  34      410      410  ✓ Stage verified
  52     1571     1571  ✓ Stage verified
  71     2939     2939  ✓ Stage verified
  98     2811     2811  ✓ Stage verified
 123      525      525  ✓ Stage verified
 167       46       46  ✓ Stage verified
 201      958      958  ✓ Stage verified
 244      339      339  ✓ Stage verified
```

### Stage 1

```text
idx    ref     gpgpu   status
   7      971      971  ✓ Stage verified
  19     1431     1431  ✓ Stage verified
  34     3111     3111  ✓ Stage verified
  52      279      279  ✓ Stage verified
  71      207      207  ✓ Stage verified
  98     1121     1121  ✓ Stage verified
 123     3071     3071  ✓ Stage verified
 167     1147     1147  ✓ Stage verified
 201      318      318  ✓ Stage verified
 244     2873     2873  ✓ Stage verified
```

### Stage 2

```text
idx    ref     gpgpu   status
   7     2046     2046  ✓ Stage verified
  19       89       89  ✓ Stage verified
  34      478      478  ✓ Stage verified
  52     2356     2356  ✓ Stage verified
  71     3168     3168  ✓ Stage verified
  98       32       32  ✓ Stage verified
 123     1689     1689  ✓ Stage verified
 167     1217     1217  ✓ Stage verified
 201     2061     2061  ✓ Stage verified
 244     1179     1179  ✓ Stage verified
```

### Stage 3

```text
idx    ref     gpgpu   status
   7     2862     2862  ✓ Stage verified
  19     2102     2102  ✓ Stage verified
  34     1161     1161  ✓ Stage verified
  52      427      427  ✓ Stage verified
  71      797      797  ✓ Stage verified
  98     3063     3063  ✓ Stage verified
 123      794      794  ✓ Stage verified
 167     3251     3251  ✓ Stage verified
 201      607      607  ✓ Stage verified
 244      716      716  ✓ Stage verified
```

### Stage 4

```text
idx    ref     gpgpu   status
   7     2968     2968  ✓ Stage verified
  19      205      205  ✓ Stage verified
  34      624      624  ✓ Stage verified
  52      466      466  ✓ Stage verified
  71     2018     2018  ✓ Stage verified
  98     3206     3206  ✓ Stage verified
 123     2265     2265  ✓ Stage verified
 167      203      203  ✓ Stage verified
 201     3047     3047  ✓ Stage verified
 244     2146     2146  ✓ Stage verified
```

### Stage 5

```text
idx    ref     gpgpu   status
   7     1657     1657  ✓ Stage verified
  19     2208     2208  ✓ Stage verified
  34      501      501  ✓ Stage verified
  52     1974     1974  ✓ Stage verified
  71     1381     1381  ✓ Stage verified
  98     3248     3248  ✓ Stage verified
 123     2747     2747  ✓ Stage verified
 167     3006     3006  ✓ Stage verified
 201     2784     2784  ✓ Stage verified
 244     1576     1576  ✓ Stage verified
```

### Stage 6

```text
idx    ref     gpgpu   status
   7     1830     1830  ✓ Stage verified
  19     2764     2764  ✓ Stage verified
  34      409      409  ✓ Stage verified
  52     3148     3148  ✓ Stage verified
  71     1530     1530  ✓ Stage verified
  98     1800     1800  ✓ Stage verified
 123     1968     1968  ✓ Stage verified
 167     2512     2512  ✓ Stage verified
 201     1736     1736  ✓ Stage verified
 244      310      310  ✓ Stage verified
```

## Test Case 6: Verify with PQC Ref

```text
  Idx    A   A_ref   B   B_ref   C  C_ref  Status
    7   571   571   902   902  2355  2355  A_OK B_OK C_OK
   19   895   895   974   974  1374  1374  A_OK B_OK C_OK
   34  1139  1139  1667  1667  2682  2682  A_OK B_OK C_OK
   52  1470  1470  2982  2982  1377  1377  A_OK B_OK C_OK
   71  2885  2885   401   401   168   168  A_OK B_OK C_OK
   98   700   700  3208  3208  3135  3135  A_OK B_OK C_OK
  123  2323  2323   328   328  2096  2096  A_OK B_OK C_OK
  167  1029  1029  2202  2202  1268  1268  A_OK B_OK C_OK
  201  1531  1531  2477  2477  1470  1470  A_OK B_OK C_OK
  244  2920  2920   171   171  1927  1927  A_OK B_OK C_OK
```

✓ Verify_with_PQC_ref: ALL MATCH

## Test Case 7: polymul_on_gpgpu

```text
  Idx    A   A_gpgpu_ref   B   B_gpgpu_ref  C   C_gpgpu_ref  Status
    7   571      571      902      902     2355     2355     A_OK B_OK C_OK
   19   895      895      974      974     1374     1374     A_OK B_OK C_OK
   34  1139     1139     1667     1667     2682     2682     A_OK B_OK C_OK
   52  1470     1470     2982     2982     1377     1377     A_OK B_OK C_OK
   71  2885     2885      401      401      168      168     A_OK B_OK C_OK
   98   700      700     3208     3208     3135     3135     A_OK B_OK C_OK
  123  2323     2323      328      328     2096     2096     A_OK B_OK C_OK
  167  1029     1029     2202     2202     1268     1268     A_OK B_OK C_OK
  201  1531     1531     2477     2477     1470     1470     A_OK B_OK C_OK
  244  2920     2920      171      171     1927     1927     A_OK B_OK C_OK
```

✓ polymul_on_gpgpu: ALL MATCH

## Full Output C = A·B (256 coefficients)

```text
1331 2055 1467 538 3010 343 1781 2355 2072 1993 941 2575 1111 2575 1538 2705
2467 3310 168 1374 419 2012 1493 779 3166 2606 2570 198 1744 1189 778 1609
2964 1471 2682 1138 1224 740 1310 2041 2787 1461 558 1058 1320 2788 933 829
1177 1350 3031 1226 1377 1899 651 829 445 1070 2803 1647 764 2436 3002 3080
3146 1496 419 410 2581 1632 2517 168 1186 3311 1509 1466 71 1739 690 2796
598 3164 145 558 1011 1826 1200 2603 2173 2121 3016 70 348 2112 744 2158
2863 3203 3135 1640 1872 664 2412 337 1157 548 2481 26 3145 2245 970 1728
1792 224 2596 97 727 1475 1946 1033 1662 1785 1616 2096 3290 257 3290 1968
2493 108 297 228 2917 56 1303 1905 1408 1358 3096 1426 248 73 2289 3200
928 2853 2450 676 1285 548 1668 620 2780 2706 830 1744 841 2357 1093 850
815 2291 2419 932 3220 300 2397 1268 572 1841 3269 1977 1224 2577 3270 3199
878 757 1865 1249 13 2278 338 856 714 1950 654 236 1256 95 2335 507
3311 253 1289 2637 1180 468 2450 2084 2554 1470 1507 1825 589 232 3189 1400
2834 1633 3300 2361 691 662 3216 335 999 2193 2414 1165 1208 323 487 994
493 1681 2107 808 1978 870 2530 1606 444 798 2388 1781 2440 1446 288 700
1566 2381 3037 2628 1927 819 1691 2125 2042 2627 2266 798 2338 1724 1185 2538
```

## Summary

Algorithm: NTT(A) || NTT(B) → basemul(â,b̂) → INTT(ĉ) → scale(×3303)

- Parallel threads: 128 total
  - NTT(A): threads 0..127 (128 CT BF × 7 stages)
  - NTT(B): threads 0..127 (128 CT BF × 7 stages)
  - BaseMul: threads 0..127 (128 BM ops)
  - INTT: threads 0..127 (128 GS BF × 7 stages)
  - Scale: 128 threads × 2 coeffs
- Custom instructions: 2816 total (CT_BF × 1792 + BASEMUL × 128 + GS_BF × 896)
- Synchronization barriers: 23 (\_\_syncthreads between stages)
- Thread mapping: local_tid=tid%128, group=local_tid/half, j=local_tid%half → butterfly(poly[g·2h+j], poly[g·2h+j+h])
- Peak concurrent threads: 256 (NTT(A) ‖ NTT(B) in same stage)
- Input: A, B ∈ ℤ₃₃₂₉[x]/(x²⁵⁶+1) (random coefficients)
- Output: C = A · B ∈ ℤ₃₃₂₉[x]/(x²⁵⁶+1)
- Result: ✓ PASSED

## Final Status

- ✓ ALL KYBER TESTS PASSED
- ✓ INPUT POLYNOMIALS VERIFIED
- ✓ NTT(A) VERIFIED
- ✓ NTT(B) VERIFIED
- ✓ BASEMUL VERIFIED
- ✓ INTT VERIFIED
- ✓ FINAL POLYNOMIAL VERIFIED
- ✓ ALL 50 FINAL COMPARISON SAMPLES MATCH

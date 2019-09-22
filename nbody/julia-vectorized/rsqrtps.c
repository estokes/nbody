#include <stdio.h>
#include <xmmintrin.h>
#include <math.h>

void rsqrtps(int idx, float *data) {
  *(__m128 *)(data+idx) = __builtin_ia32_rsqrtps(*(__m128 *)(data+idx));
}

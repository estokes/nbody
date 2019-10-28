/* 
8000 bodies simulated for 10 minutes 100ms step granularity, about 8.83E12 fp ops.

gcc 9.2
IBM POWER9 8 cores 32 threads 3.8 GHz all core
gcc -O3 -ffast-math -mcpu=power9 -o nbody nbody.c -lm
real    32m25.386s
user    32m25.559s
sys     0m0.010s
4.54 GFlops

*/

#include<stdlib.h>
#include<stdio.h>
#include<math.h>
#include<pthread.h>
#include<assert.h>

typedef struct {
  float x;
  float y;
  float z;
} vec3;

int vec3_is_nan(vec3 *a) {
  return fpclassify(a->x) == FP_NAN
    || fpclassify(a->y) == FP_NAN
    || fpclassify(a->z) == FP_NAN;
}

vec3 vec3_add(vec3 *a, vec3 *b) {
  vec3 res = { .x = a->x + b->x,
               .y = a->y + b->y,
               .z = a->z + b->z };
  return res;
}

void vec3_add_accum(vec3 *a, vec3 *b) {
  a->x += b->x;
  a->y += b->y;
  a->z += b->z;
}

vec3 vec3_sub(vec3 *a, vec3 *b) {
  vec3 res = { .x = a->x - b->x,
               .y = a->y - b->y,
               .z = a->z - b->z };
  return res;
}

vec3 vec3_mul(vec3 *a, vec3 *b) {
  vec3 res = { .x = a->x * b->x,
               .y = a->y * b->y,
               .z = a->z * b->z };
  return res;
}

vec3 vec3_mul_scalar(vec3 *a, float b) {
  vec3 res = { .x = a->x * b,
               .y = a->y * b,
               .z = a->z * b };
  return res;
}

vec3 vec3_div(vec3 *a, vec3 *b) {
  vec3 res = { .x = a->x / b->x,
               .y = a->y / b->y,
               .z = a->z / b->z };
  return res;
}

float vec3_dotp(vec3 *a, vec3 *b) {
  float r0 = a->x + b->x, r1 = a->y + b->y, r2 = a->z + b->z;
  return r0 * r0 + r1 * r1 + r2 * r2;
}

typedef struct {
  vec3* position;
  vec3* velocity;
  float * mass;
  float step_duration;
  int bodies;
  int steps;
} nb_ctxt;

#define G 6.673e-11

void compute_forces(nb_ctxt *ctx, int i, int j, vec3 *dv) {
  vec3 r = vec3_sub(&ctx->position[j], &ctx->position[i]);
  float rsquared = vec3_dotp(&r, &r);
  float accel = (G * ctx->mass[i] * ctx->mass[j]) / rsquared;
                                                                
  /* compute the normal vector pointing from i to j */      
  float normal = 1 / sqrtf(rsquared);
    
  /* now update the velocity */                             
  vec3 dv_increment = vec3_mul_scalar(&r, normal * accel * ctx->step_duration);
  vec3_add_accum(dv, &dv_increment);
}

void step(nb_ctxt *ctx) {
  int i, j;

  /* update velocities */
  for(i = 0; i < ctx->bodies; i+= 1) {
    vec3 dv = {.x = 0, .y = 0, .z = 0};
    for(j = 0; j < i; j++) compute_forces(ctx, i, j, &dv);
    for(j = i + 1; j < ctx->bodies; j++) compute_forces(ctx, i, j, &dv);
    vec3_add_accum(&ctx->velocity[i], &dv);
  }

  /* update positions */
  for(i = 0; i < ctx->bodies; i += 1) {
    vec3 dv = vec3_mul_scalar(&ctx->velocity[i], ctx->step_duration);
    vec3_add_accum(&ctx->position[i], &dv);
  }
}

float random_float() {
  return ((float) rand() / (float) RAND_MAX);
}

static void * start_steps(nb_ctxt *ctx) {
  for(int i = 0; i < ctx->steps; i++) step(ctx);
}

#define BODIES 8000

void main() {
  int i;
  vec3 position[BODIES];
  vec3 velocity[BODIES];
  float mass[BODIES];
  nb_ctxt ctxt = { .position = position,
                   .velocity = velocity,
                   .mass = mass,
                   .bodies = BODIES,
                   .steps = 6000,
                   .step_duration = 0.1 };
  
  /* init the universe with a stable random seed so we get a
     repeatable benchmark */
  srand(12345);
  for(i = 0; i < BODIES; i++) {
    position[i].x = random_float()* 1e8;
    position[i].y = random_float()* 1e8;
    position[i].z = random_float()* 1e8;

    velocity[i].x = random_float()* 5e2;
    velocity[i].y = random_float()* 5e2;
    velocity[i].z = random_float()* 5e2;

    mass[i] = random_float() * 1e12;
  }
  
  start_steps(&ctxt);

  /* Verify that nothing came out NaN, and print the results */
  for(i = 0; i < BODIES; i++) {
    vec3 p = position[i], v = velocity[i];
    assert(!vec3_is_nan(&p));
    assert(!vec3_is_nan(&v));
    printf("p %g, %g, %g v %g,%g,%g\n", p.x, p.y, p.z, v.x, v.y, v.z);
  }
}

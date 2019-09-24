/* 
yay faster than julia

1000 bodies for 10 min
real	0m45.394s
user	0m45.346s
sys	0m0.004s

8000 bodies for 10 min
real	52m28.486s
user	52m25.458s
sys	0m0.012s
*/

#include<stdlib.h>
#include<stdio.h>
#include<math.h>
#include<pthread.h>

typedef struct nb_ctxt {
  float *position;
  float *velocity;
  float *mass;
  int th_id;
  pthread_barrier_t *sync;
} nb_ctxt;

#define G 6.673e-11
#define MOON_MASS 7.34e22
#define MOON_RADIUS 1.7371e6
#ifndef NTHREADS
#define NTHREADS 8
#endif
#define STEPS 6000
#define BODIES 8000
#define STEP_DURATION 0.1

void compute_forces(nb_ctxt *ctx, int i, int j, float *dvx, float *dvy, float *dvz) {
  float r1, r2, r3, rsquared, accel, normal;

  /* compute the force of gravity */                          
  r1 = (ctx->position[j*3 + 0] - ctx->position[i*3 + 0]);   
  r2 = (ctx->position[j*3 + 1] - ctx->position[i*3 + 1]);   
  r3 = (ctx->position[j*3 + 2] - ctx->position[i*3 + 2]);   
  rsquared = r1*r1 + r2*r2 + r3*r3;                         
  accel = (G * ctx->mass[j]) / rsquared;                    
                                                                
  /* compute the normal vector pointing from i to j */      
  normal = 1 / sqrtf(rsquared);                             
                                                                
  /* now update the velocity */                             
  *dvx += r1 * normal * accel * STEP_DURATION;                    
  *dvy += r2 * normal * accel * STEP_DURATION;                    
  *dvz += r3 * normal * accel * STEP_DURATION;
}

void step(nb_ctxt *ctx) {
  int i, j;

  /* update velocities */
  for(i = ctx->th_id; i < BODIES; i+= NTHREADS) {
    float dvx = 0, dvy = 0, dvz = 0;

    for(j = 0; j < i; j++) {
      compute_forces(ctx, i, j, &dvx, &dvy, &dvz);
    }
    for(j = i + 1; j < BODIES; j++) {
      compute_forces(ctx, i, j, &dvx, &dvy, &dvz);
    }

    ctx->velocity[i*3 + 0] += dvx;
    ctx->velocity[i*3 + 1] += dvy;
    ctx->velocity[i*3 + 2] += dvz;
  }

  // wait for all threads to be done reading current positions before
  // we update any.
  pthread_barrier_wait(ctx->sync);

  /* update positions */
  for(i = ctx->th_id; i < BODIES; i += NTHREADS) {
    ctx->position[i*3 + 0] += ctx->velocity[i*3 + 0] * STEP_DURATION;
    ctx->position[i*3 + 1] += ctx->velocity[i*3 + 1] * STEP_DURATION;
    ctx->position[i*3 + 2] += ctx->velocity[i*3 + 2] * STEP_DURATION;
  }

  // wait for all threads to be done writing back positions before we
  // move on for another cycle
  pthread_barrier_wait(ctx->sync);
}

/* This simulates a 1000 Kg body orbiting the moon at at distance of about 10 kilometers */
/*
void two_body_test() {
  int i, n = 2;
  float position[6] = 
    { 0     , 0, 0, 
      1.75e6, 0, 0 };
  float velocity[6] = 
    { 0, 0      , 0,
      0, 1.673e3, 0 };
  float mass[2] = {MOON_MASS, 1e3};
  float alt = 0;

  while(1) {
    for(i = 0; i < 6000; i++) {
      step(n, position, velocity, mass, 0.1);
    }  

    alt = sqrt(powf((position[0*3 + 0] - position[1*3 + 0]), 2) +
               powf((position[0*3 + 1] - position[1*3 + 1]), 2) +
               powf((position[0*3 + 2] - position[1*3 + 2]), 2));
    printf("alt %f v %f,%f,%f\n", alt - MOON_RADIUS, 
           velocity[3+0], velocity[3+1], velocity[3+2]);
  }
}
*/

float random_float() {
  float n = (float) rand();
  return (n / (log10f(n) + 1)); /* (0, 1) */
}

static void * start_steps(void *ctx) {
  for(int i = 0; i < STEPS; i++) step((nb_ctxt *) ctx);
}

void many_body_test() {
  int i;
  float position[BODIES*3];
  float velocity[BODIES*3];
  float mass[BODIES];
  float alt;
  nb_ctxt ctxt[NTHREADS];
  pthread_t tids[NTHREADS];
  pthread_barrier_t sync;
  
  /* init the universe */
  srand(1232);
  for(i = 0; i < BODIES; i++) {
    position[i*3 + 0] = random_float() * 1e9;
    position[i*3 + 1] = random_float() * 1e9;
    position[i*3 + 2] = random_float() * 1e9;

    velocity[i*3 + 0] = random_float() * 5e2;
    velocity[i*3 + 1] = random_float() * 5e2;
    velocity[i*3 + 2] = random_float() * 5e2;

    mass[i] = random_float() * 1e22;
  }

  /* start the threads */
  if(pthread_barrier_init(&sync, NULL, NTHREADS)) perror("error init barrier");
  for(i = 0; i < NTHREADS; i++) {
    ctxt[i].position = position;
    ctxt[i].velocity = velocity;
    ctxt[i].mass = mass;
    ctxt[i].th_id = i;
    ctxt[i].sync = &sync;
  }

  for(i = 0; i < NTHREADS; i++)
    if(pthread_create(&tids[i], NULL, &start_steps, &ctxt[i]) != 0) perror("pthread_create");

  /* wait for the calculation to finish */
  for(i = 0; i < NTHREADS; i++)
    if(pthread_join(tids[i], NULL) != 0) perror("pthread_join");

  alt = sqrt(powf((position[0*3 + 0] - position[1*3 + 0]), 2) +
             powf((position[0*3 + 1] - position[1*3 + 1]), 2) +
             powf((position[0*3 + 2] - position[1*3 + 2]), 2));

  printf("alt %f v %f,%f,%f\n", alt, 
         velocity[3+0], velocity[3+1], velocity[3+2]);
}

void main() {
  many_body_test();
}

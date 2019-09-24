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

#define G 6.673e-11
#define MOON_MASS 7.34e22
#define MOON_RADIUS 1.7371e6

void step(int n, float *position, float *velocity, float *mass, float duration) {
  float r1, r2, r3, rsquared, accel, normal, dvx = 0, dvy = 0, dvz = 0;
  int i, j;

  /* update velocities */
  for(i = 0; i < n; i++) {
    /* This is necessary in order to avoid branches inside the loop,
       which will prevent the loop from vectorizing. And it's
       necessary to skip computing an objects force on itself because
       that will always be zero, resulting in NaN. */

    #define LOOP \
        /* compute the force of gravity */                       \
        r1 = (position[j*3 + 0] - position[i*3 + 0]);            \
        r2 = (position[j*3 + 1] - position[i*3 + 1]);            \
        r3 = (position[j*3 + 2] - position[i*3 + 2]);            \
        rsquared = r1*r1 + r2*r2 + r3*r3;                        \
        accel = (G * mass[j]) / rsquared;                        \
                                                                 \
        /* compute the normal vector pointing from i to j */     \
        normal = 1 / sqrtf(rsquared);                            \
                                                                 \
        /* now update the velocity */                            \
        dvx += r1 * normal * accel * duration;                   \
        dvy += r2 * normal * accel * duration;                   \
        dvz += r3 * normal * accel * duration;                   \

    for(j = 0; j < i; j++) {
      LOOP
    }
    for(j = i + 1; j < n; j++) {
      LOOP
    }

    velocity[i*3 + 0] += dvx;
    velocity[i*3 + 1] += dvy;
    velocity[i*3 + 2] += dvz;
  }

  /* update positions */
  for(i = 0; i < n; i++) {
    position[i*3 + 0] += velocity[i*3 + 0] * duration;
    position[i*3 + 1] += velocity[i*3 + 1] * duration;
    position[i*3 + 2] += velocity[i*3 + 2] * duration;
  }
}

/* This simulates a 1000 Kg body orbiting the moon at at distance of about 10 kilometers */
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

float random_float() {
  float n = (float) rand();
  return (n / (log10f(n) + 1)); /* (0, 1) */
}

void many_body_test() {
  int i, n = 1000;
  float position[n*3];
  float velocity[n*3];
  float mass[n];
  float alt;

  srand(1232);
  for(i = 0; i < n; i++) {
    position[i*3 + 0] = random_float() * 1e9;
    position[i*3 + 1] = random_float() * 1e9;
    position[i*3 + 2] = random_float() * 1e9;

    velocity[i*3 + 0] = random_float() * 5e2;
    velocity[i*3 + 1] = random_float() * 5e2;
    velocity[i*3 + 2] = random_float() * 5e2;

    mass[i] = random_float() * 1e22;
  }
  
  for(i = 0; i < 6000; i++) {
    step(n, position, velocity, mass, 0.1);
  }

  alt = sqrt(powf((position[0*3 + 0] - position[1*3 + 0]), 2) +
             powf((position[0*3 + 1] - position[1*3 + 1]), 2) +
             powf((position[0*3 + 2] - position[1*3 + 2]), 2));

  printf("alt %f v %f,%f,%f\n", alt, 
         velocity[3+0], velocity[3+1], velocity[3+2]);
}

void main() {
  many_body_test();
}

/*
This is by far the fastest time of all systems.

1000 bodies for 10 min
real	0m6.662s
user	0m4.099s
sys	0m2.546s


8000 bodies for 10 min
real	2m3.830s
user	1m16.900s
sys	0m46.798s
*/
#include<stdlib.h>
#include<stdio.h>
#include<math.h>

#define G 6.673e-11
#define MOON_MASS 7.34e22
#define MOON_RADIUS 1.7371e6

__global__
void update_velocity(int n, float *position, float *velocity, float *mass, float duration) {
  float r1, r2, r3, rsquared, accel, normal, dvx = 0, dvy = 0, dvz = 0;
  int j, i = blockIdx.x * blockDim.x + threadIdx.x;

  if(i < n) {
#define LOOP                                                        \
        /* compute the force of gravity */                          \
        r1 = (position[j*3 + 0] - position[i*3 + 0]);               \
        r2 = (position[j*3 + 1] - position[i*3 + 1]);               \
        r3 = (position[j*3 + 2] - position[i*3 + 2]);               \
        rsquared = r1*r1 + r2*r2 + r3*r3;                           \
        accel = (G * mass[j]) / rsquared;                           \
                                                                    \
        /* compute the normal vector pointing from i to j */        \
        normal = 1 / sqrtf(rsquared);                               \
                                                                    \
        /* now update the velocity */                               \
        dvx += r1 * normal * accel * duration;                      \
        dvy += r2 * normal * accel * duration;                      \
        dvz += r3 * normal * accel * duration;                      \

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
}

__global__
void update_position(int n, float *position, float *velocity, float duration) {
  int i = blockIdx.x * blockDim.x + threadIdx.x;
  if(i < n) {
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
  float *position_d, *velocity_d, *mass_d;
  float alt = 0;

  cudaMalloc(&position_d, 6*sizeof(float));
  cudaMalloc(&velocity_d, 6*sizeof(float));
  cudaMalloc(&mass_d, 2*sizeof(float));
  cudaMemcpy(position_d, position, 6*sizeof(float), cudaMemcpyHostToDevice);
  cudaMemcpy(velocity_d, velocity, 6*sizeof(float), cudaMemcpyHostToDevice);
  cudaMemcpy(mass_d, mass, 2*sizeof(float), cudaMemcpyHostToDevice);

  while(1) {
    for(i = 0; i < 6000; i++) {
      update_velocity<<<2, 2>>>(n, position_d, velocity_d, mass_d, 0.1);
      update_position<<<2, 2>>>(n, position_d, velocity_d, 0.1);
    }  

    cudaMemcpy(&position, position_d, 6*sizeof(float), cudaMemcpyDeviceToHost);
    cudaMemcpy(&velocity, velocity_d, 6*sizeof(float), cudaMemcpyDeviceToHost);
    alt = sqrt(powf((position[0*3 + 0] - position[1*3 + 0]), 2) +
               powf((position[0*3 + 1] - position[1*3 + 1]), 2) +
               powf((position[0*3 + 2] - position[1*3 + 2]), 2));
    printf("alt %f v %f,%f,%f\n", alt - MOON_RADIUS, 
           velocity[3+0], velocity[3+1], velocity[3+2]);
  }
}

float random_float() {
  float n = (float) rand();
  return (n / (log10f(n) + 1)); /* between 0 and 1 */
}

void many_body_test() {
  int i, n = 8000;
  float position[n*3];
  float velocity[n*3];
  float mass[n];
  float *position_d, *velocity_d, *mass_d;
  float alt;

  cudaMalloc(&position_d, n*3*sizeof(float));
  cudaMalloc(&velocity_d, n*3*sizeof(float));
  cudaMalloc(&mass_d, n*sizeof(float));

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

  cudaMemcpy(position_d, position, n*3*sizeof(float), cudaMemcpyHostToDevice);
  cudaMemcpy(velocity_d, velocity, n*3*sizeof(float), cudaMemcpyHostToDevice);
  cudaMemcpy(mass_d, mass, n*sizeof(float), cudaMemcpyHostToDevice);

  #define B 16
  for(i = 0; i < 6000; i++) {
    update_velocity<<<(n+(B-1))/B, B>>>(n, position_d, velocity_d, mass_d, 0.1);
    update_position<<<(n+(B-1))/B, B>>>(n, position_d, velocity_d, 0.1);
  }

  cudaMemcpy(&position, position_d, n*3*sizeof(float), cudaMemcpyDeviceToHost);
  cudaMemcpy(&velocity, velocity_d, n*3*sizeof(float), cudaMemcpyDeviceToHost);
  alt = sqrt(powf((position[(n-1)*3 + 0] - position[1*3 + 0]), 2) +
             powf((position[(n-1)*3 + 1] - position[1*3 + 1]), 2) +
             powf((position[(n-1)*3 + 2] - position[1*3 + 2]), 2));

  printf("alt %f v %f,%f,%f\n", alt, 
         velocity[3+0], velocity[3+1], velocity[3+2]);
}

int main() {
  many_body_test();
  return 0;
}

/*
8 core power9 @ 3.8Ghz
real    4m4.275s
user    129m54.588s
sys     0m7.761s

*/
#![feature(core_intrinsics)]
use rayon::prelude::*;
use std::{
    sync::{Arc, RwLock},
    intrinsics::{fmul_fast, fdiv_fast, fsub_fast, fadd_fast}
};

const G: f32 = 6.673e-11;

#[derive(Debug)]
struct V3v {
    x: Vec<f32>,
    y: Vec<f32>,
    z: Vec<f32>,
}


#[derive(Debug)]
struct UniverseInner {
    position: V3v,
    velocity: V3v,
    mass: Vec<f32>
}

impl UniverseInner {
    #[inline(always)]
    unsafe fn compute_dv_step(
        &self, p0x: f32, p0y: f32, p0z: f32, m0: f32, j: usize, duration: f32
    ) -> (f32, f32, f32) {
        let (p1x, p1y, p1z, m1) = (
            self.position.x[j], self.position.y[j], self.position.z[j], self.mass[j]
        );
        // compute gravity
        let (rx, ry, rz) = (
            fsub_fast(p0x, p1x), fsub_fast(p0y, p1y), fsub_fast(p0z, p1z)
        );
        let rsquared = fadd_fast(
            fmul_fast(rx, rx),
            fadd_fast(fmul_fast(ry, ry), fmul_fast(rz, rz))
        );
        let fg = fdiv_fast(fmul_fast(fmul_fast(G, m0), m1), rsquared);

        // compute the normal vector pointing from i to j
        let normal = fdiv_fast(1., f32::sqrt(rsquared));
        
        // update the velocity for this step
        let nfd = normal * fg * duration;
        (rx * nfd, ry * nfd, rz * nfd)
    }

    unsafe fn compute_dv(&self, i: usize, duration: f32) -> (f32, f32, f32) {
        let (mut dvx, mut dvy, mut dvz) = (0., 0., 0.);
        let (p0x, p0y, p0z, m0) = (
            self.position.x[i], self.position.y[i], self.position.z[i], self.mass[i]
        );
        for j in 0..i {
            let (dx, dy, dz) = self.compute_dv_step(p0x, p0y, p0z, m0, j, duration);
            dvx += dx;
            dvy += dy;
            dvz += dz
        }
        for j in i+1..self.position.x.len() {
            let (dx, dy, dz) = self.compute_dv_step(p0x, p0y, p0z, m0, j, duration);
            dvx += dx;
            dvy += dy;
            dvz += dz
        }
        (dvx, dvy, dvz)
    }
}

#[derive(Debug, Clone)]
struct Universe(Arc<RwLock<UniverseInner>>);

impl std::ops::Deref for Universe {
    type Target = Arc<RwLock<UniverseInner>>;

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

impl Universe {
    fn len(&self) -> usize {
        self.read().unwrap().position.x.len()
    }

    fn update_velocities(&self, dvs: &mut Vec<(f32, f32, f32)>, duration: f32) {
        let len = self.len();
        (0..len).into_par_iter()
            .map(|i| unsafe { self.read().unwrap().compute_dv(i, duration) })
            .collect_into_vec(dvs);
        let mut v = self.write().unwrap();
        for i in 0..len {
            unsafe {
                v.velocity.x[i] = fadd_fast(v.velocity.x[i], dvs[i].0);
                v.velocity.y[i] = fadd_fast(v.velocity.y[i], dvs[i].1);
                v.velocity.z[i] = fadd_fast(v.velocity.z[i], dvs[i].2);
            }
        }
    }

    fn update_positions(&self, duration: f32) {
        let mut v = self.write().unwrap();
        for i in 0..v.position.x.len() {
            unsafe {
                v.position.x[i] =
                    fadd_fast(v.position.x[i], fmul_fast(v.velocity.x[i], duration));
                v.position.y[i] =
                    fadd_fast(v.position.y[i], fmul_fast(v.velocity.y[i], duration));
                v.position.z[i] =
                    fadd_fast(v.position.z[i], fmul_fast(v.velocity.z[i], duration));
            }
        }
    }

    fn step(&self, dvs: &mut Vec<(f32, f32, f32)>, duration: f32) {
        self.update_velocities(dvs, duration);
        self.update_positions(duration);
    }
}

// 8000 bodies for 10 minutes
const BODIES: usize = 8000;
const STEP: f32 = 0.1;
const STEPS: usize = 6000;

fn main() {
    use rand::prelude::*;
    let mut dvs = Vec::with_capacity(BODIES);
    let mut r = {
        let mut rng = StdRng::from_seed([0; 32]);
        move || -> f32 { rng.gen() }
    };
    let universe = Universe(Arc::new(RwLock::new(UniverseInner {
        position: V3v {
            x: (0..BODIES).map(|_| r() * 1e9).collect(),
            y: (0..BODIES).map(|_| r() * 1e9).collect(),
            z: (0..BODIES).map(|_| r() * 1e9).collect(),
        },
        velocity: V3v {
            x: (0..BODIES).map(|_| r() * 5e2).collect(),
            y: (0..BODIES).map(|_| r() * 5e2).collect(),
            z: (0..BODIES).map(|_| r() * 5e2).collect(),
        },
        mass: (0..BODIES).map(|_| r() * 1e22).collect()
    })));
    for _ in 0..STEPS {
        universe.step(&mut dvs, STEP)
    }
}

#[test]
fn two_body_test() {
    let mut dvs = Vec::with_capacity(2);
    let step = 0.1;
    let universe = Universe(Arc::new(RwLock::new(UniverseInner {
        position: V3v {
            x: vec![0., 1_750_000.],
            y: vec![0., 0.,],
            z: vec![0., 0.]
        },
        velocity: V3v {
            x: vec![0., 0.],
            y: vec![0., 1673.],
            z: vec![0., 0.],
        },
        mass: vec![7.34e22, 1000.]
    })));
    for _ in 0..1_000_000_000 {
        universe.step(&mut dvs, step);
        let v = universe.read().unwrap();
        let d = f32::sqrt(
            f32::powi(v.position.x[0] - v.position.x[1], 2) +
            f32::powi(v.position.y[0] - v.position.y[1], 2) +
            f32::powi(v.position.z[0] - v.position.z[1], 2)
        );
        assert!(d >=         1_737_100.);
        assert!(d <= 1_000_000_000_000.);
    }
}

/*
8 core power9 @ 3.8Ghz
real    0m8.067s
user    4m13.146s
sys     0m2.722s


*/
#![feature(core_intrinsics)]
mod vec3;
use vec3::Vector3;
use rayon::prelude::*;
use std::{
    sync::{Arc, RwLock},
    intrinsics::{fmul_fast, fdiv_fast}
};

const G: f32 = 6.673e-11;

#[derive(Debug, Clone, Copy)]
struct Body {
    position: Vector3,
    velocity: Vector3,
    mass: f32,
}

impl Body {
    fn update_position(&mut self, duration: f32) {
        self.position += self.velocity * duration
    }
}

fn update_one_dv_step(b0: &Body, b1: &Body, dv: &mut Vector3, duration: f32) {
    unsafe {
        // compute gravity
        let r = b0.position - b1.position;
        let rsquared = Vector3::dotp(&r, &r);
        let fg = fdiv_fast(fmul_fast(fmul_fast(G, b0.mass), b1.mass), rsquared);

        // compute the normal vector pointing from i to j
        let normal = fdiv_fast(1., f32::sqrt(rsquared));
        
        // update the velocity for this step
        *dv += r * normal * fg * duration;
    }
}

#[derive(Debug, Clone)]
struct Universe(Arc<RwLock<Vec<Body>>>);

impl std::ops::Deref for Universe {
    type Target = Arc<RwLock<Vec<Body>>>;

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

impl Universe {
    fn len(&self) -> usize {
        self.read().unwrap().len()
    }

    fn update_velocities(&self, duration: f32) {
        let len = self.len();
        let dvs = (0..len).into_par_iter().map(|i| {
            let v = self.read().unwrap();
            let mut dv = Vector3::new(0., 0., 0.);
            for j in 0..i {
                update_one_dv_step(&v[i], &v[j], &mut dv, duration);
            }
            for j in i+1..len {
                update_one_dv_step(&v[i], &v[j], &mut dv, duration);
            }
            dv
        }).collect::<Vec<Vector3>>();
        let mut v = self.write().unwrap();
        for i in 0..len {
            v[i].velocity += dvs[i];
        }
    }

    fn update_positions(&self, duration: f32) {
        let mut v = self.write().unwrap();
        for b in v.iter_mut() {
            b.update_position(duration);
        }
    }

    fn step(&self, duration: f32) {
        self.update_velocities(duration);
        self.update_positions(duration);
    }
}

fn main() {
    use rand::prelude::*;
    let step = 0.1;
    let mut r = {
        let mut rng = StdRng::from_seed([0; 32]);
        move || -> f32 { rng.gen() }
    };
    let universe = Universe(Arc::new(RwLock::new((0..1000).map(|_| {
        Body {
            position: Vector3::new(r() * 1e9, r() * 1e9, r() * 1e9),
            velocity: Vector3::new(r() * 5e2, r() * 5e2, r() * 5e2),
            mass: r() * 1e22
        }
    }).collect::<Vec<Body>>())));

    for _ in 0..6000 {
        universe.step(step)
    }
}

#[test]
fn two_body_test() {
    let step = 0.1;
    let universe = Universe(Arc::new(RwLock::new(vec![
        // the moon
        Body {
            position: Vector3::new(0., 0., 0.),
            velocity: Vector3::new(0., 0., 0.),
            mass: 7.34e22
        },
        // 1000kg meteor
        Body {
            position: Vector3::new(1_750_000., 0., 0.),
            velocity: Vector3::new(0., 1673., 0.),
            mass: 1000.
        }
    ])));
    for _ in 0..1_000_000_000 {
        universe.step(step);
        let v = universe.read().unwrap();
        let d = Vector3::distance(&v[0].position, &v[1].position);
        assert!(d >=         1_737_100.);
        assert!(d <= 1_000_000_000_000.);
    }
}

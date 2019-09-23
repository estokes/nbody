use std::{
    ops,
    intrinsics::{fadd_fast, fsub_fast, fmul_fast, fdiv_fast}
};

#[derive(Debug, Clone, Copy)]
pub struct Vector3 {
    x: f32,
    y: f32,
    z: f32
}

impl ops::Add for Vector3 {
    type Output = Self;

    fn add(self, rhs: Self) -> Self::Output {
        unsafe {
            Vector3 {
                x: fadd_fast(self.x, rhs.x),
                y: fadd_fast(self.y, rhs.y),
                z: fadd_fast(self.z, rhs.z)
            }
        }
    }
}

impl ops::Sub for Vector3 {
    type Output = Self;

    fn sub(self, rhs: Self) -> Self::Output {
        unsafe {
            Vector3 {
                x: fsub_fast(self.x, rhs.x),
                y: fsub_fast(self.y, rhs.y),
                z: fsub_fast(self.z, rhs.z)
            }
        }
    }
}

impl ops::Mul for Vector3 {
    type Output = Self;

    fn mul(self, rhs: Self) -> Self::Output {
        unsafe {
            Vector3 {
                x: fmul_fast(self.x, rhs.x),
                y: fmul_fast(self.y, rhs.y),
                z: fmul_fast(self.z, rhs.z)
            }
        }
    }
}

impl ops::Mul<f32> for Vector3 {
    type Output = Self;

    fn mul(self, rhs: f32) -> Self::Output {
        unsafe {
            Vector3 {
                x: fmul_fast(self.x, rhs),
                y: fmul_fast(self.y, rhs),
                z: fmul_fast(self.z, rhs)
            }
        }
    }
}

impl ops::Div for Vector3 {
    type Output = Self;

    fn div(self, rhs: Self) -> Self::Output {
        unsafe {
            Vector3 {
                x: fdiv_fast(self.x, rhs.x),
                y: fdiv_fast(self.y, rhs.y),
                z: fdiv_fast(self.z, rhs.z)
            }
        }
    }
}

impl ops::AddAssign for Vector3 {
    fn add_assign(&mut self, rhs: Self) {
        unsafe {
            self.x = fadd_fast(self.x, rhs.x);
            self.y = fadd_fast(self.y, rhs.y);
            self.z = fadd_fast(self.z, rhs.z);
        }
    }
}

impl ops::SubAssign for Vector3 {
    fn sub_assign(&mut self, rhs: Self) {
        unsafe {
            self.x = fsub_fast(self.x, rhs.x);
            self.y = fsub_fast(self.y, rhs.y);
            self.z = fsub_fast(self.z, rhs.z);
        }
    }
}

impl ops::MulAssign for Vector3 {
    fn mul_assign(&mut self, rhs: Self) {
        unsafe {
            self.x = fmul_fast(self.x, rhs.x);
            self.y = fmul_fast(self.y, rhs.y);
            self.z = fmul_fast(self.z, rhs.z);
        }
    }
}

impl ops::MulAssign<f32> for Vector3 {
    fn mul_assign(&mut self, rhs: f32) {
        unsafe {
            self.x = fmul_fast(self.x, rhs);
            self.y = fmul_fast(self.y, rhs);
            self.z = fmul_fast(self.z, rhs);
        }
    }
}

impl ops::DivAssign for Vector3 {
    fn div_assign(&mut self, rhs: Self) {
        unsafe {
            self.x = fdiv_fast(self.x, rhs.x);
            self.y = fdiv_fast(self.y, rhs.y);
            self.z = fdiv_fast(self.z, rhs.z);
        }
    }
}

impl Vector3 {
    pub fn new(x: f32, y: f32, z: f32) -> Self {
        Vector3 { x, y, z }
    }

    pub fn dotp(a: &Vector3, b: &Vector3) -> f32 {
        unsafe {
            fadd_fast(
                fadd_fast(
                    fmul_fast(a.x, b.x),
                    fmul_fast(a.y, b.y)
                ),
                fmul_fast(a.z, b.z)
            )
        }
    }

    #[allow(dead_code)]
    pub fn distance_squared(a: &Vector3, b: &Vector3) -> f32 {
        unsafe {
            fadd_fast(
                fadd_fast(
                    { let x = fsub_fast(a.x, b.x); fmul_fast(x, x) },
                    { let x = fsub_fast(a.y, b.y); fmul_fast(x, x) }
                ),
                { let x = fsub_fast(a.z, b.z); fmul_fast(x, x) }
            )
        }
    }

    #[allow(dead_code)]
    pub fn distance(a: &Vector3, b: &Vector3) -> f32 {
        f32::sqrt(Vector3::distance_squared(a, b))
    }

    #[allow(dead_code)]
    pub fn normalized(self) -> Self {
        let d = f32::sqrt(
            f32::powi(self.x, 2) + f32::powi(self.y, 2) + f32::powi(self.z, 2)
        );
        self * (1. / d)
    }

    #[allow(dead_code)]
    pub fn normalize(&mut self) {
        let d = f32::sqrt(
            f32::powi(self.x, 2) + f32::powi(self.y, 2) + f32::powi(self.z, 2)
        );
        *self *= 1. / d;
    }

    #[allow(dead_code)]
    pub fn direction(a: Self, b: Self) -> Self {
        (a - b).normalized()
    }
}

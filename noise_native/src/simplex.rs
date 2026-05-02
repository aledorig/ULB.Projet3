use godot::prelude::*;

const GRAD_X: [f32; 12] = [1.0, -1.0, 1.0, -1.0, 1.0, -1.0, 1.0, -1.0, 0.0, 0.0, 0.0, 0.0];
const GRAD_Z: [f32; 12] = [1.0, 1.0, -1.0, -1.0, 0.0, 0.0, 0.0, 0.0, 1.0, -1.0, 1.0, -1.0];

const F2: f32 = 0.366_025_4; // 0.5 * (sqrt(3) - 1)
const G2: f32 = 0.211_324_87; // (3 - sqrt(3)) / 6

#[derive(GodotClass)]
#[class(base = RefCounted, rename = SimplexNoise)]
pub(crate) struct SimplexNoise {
    base: Base<RefCounted>,
    x_offset: f32,
    z_offset: f32,
    perm: [u8; 512],
}

#[godot_api]
impl IRefCounted for SimplexNoise {
    fn init(base: Base<RefCounted>) -> Self {
        Self {
            base,
            x_offset: 0.0,
            z_offset: 0.0,
            perm: [0u8; 512],
        }
    }
}

#[godot_api]
#[allow(unreachable_pub)]
impl SimplexNoise {
    #[func]
    #[allow(clippy::needless_pass_by_value)] // gdext #[func] requires owned Packed* types
    pub fn setup(&mut self, x_offset: f32, z_offset: f32, perm_array: PackedInt32Array) {
        self.x_offset = x_offset;
        self.z_offset = z_offset;
        for i in 0..512 {
            self.perm[i] = (perm_array.get(i).unwrap_or(0) & 0xFF) as u8;
        }
    }

    #[func]
    pub fn get_value(&self, x: f32, z: f32) -> f32 {
        simplex_2d(&self.perm, x + self.x_offset, z + self.z_offset)
    }

    #[allow(clippy::too_many_arguments)]
    #[func]
    pub fn add(
        &self,
        mut out: PackedFloat32Array,
        x_off: f32,
        z_off: f32,
        x_size: i32,
        z_size: i32,
        x_scale: f32,
        z_scale: f32,
        amplitude: f32,
    ) -> PackedFloat32Array {
        let slice = out.as_mut_slice();
        let mut idx = 0usize;

        for gz in 0..z_size as usize {
            let d0 = (z_off + gz as f32) * z_scale + self.z_offset;

            for gx in 0..x_size as usize {
                let d1 = (x_off + gx as f32) * x_scale + self.x_offset;
                slice[idx] += simplex_2d(&self.perm, d1, d0) * amplitude;
                idx += 1;
            }
        }
        out
    }
}

pub(crate) fn simplex_2d(perm: &[u8; 512], x: f32, z: f32) -> f32 {
    let s = (x + z) * F2;
    let i = fast_floor(x + s);
    let j = fast_floor(z + s);

    let t = (i + j) as f32 * G2;
    let x0 = x - (i as f32 - t);
    let z0 = z - (j as f32 - t);

    let (i1, j1) = if x0 > z0 { (1i32, 0i32) } else { (0i32, 1i32) };

    let x1 = x0 - i1 as f32 + G2;
    let z1 = z0 - j1 as f32 + G2;
    let x2 = x0 - 1.0 + 2.0 * G2;
    let z2 = z0 - 1.0 + 2.0 * G2;

    let ii = (i & 255) as usize;
    let jj = (j & 255) as usize;
    let gi0 = (perm[ii + perm[jj] as usize] % 12) as usize;
    let gi1 = (perm[ii + i1 as usize + perm[jj + j1 as usize] as usize] % 12) as usize;
    let gi2 = (perm[ii + 1 + perm[jj + 1] as usize] % 12) as usize;

    let n0 = corner(x0, z0, gi0);
    let n1 = corner(x1, z1, gi1);
    let n2 = corner(x2, z2, gi2);

    70.0 * (n0 + n1 + n2)
}

fn fast_floor(v: f32) -> i32 {
    let i = v as i32;
    if v < i as f32 { i - 1 } else { i }
}

fn corner(x: f32, z: f32, gi: usize) -> f32 {
    let t = 0.5 - x * x - z * z;
    if t < 0.0 {
        0.0
    } else {
        let t2 = t * t;
        t2 * t2 * (GRAD_X[gi] * x + GRAD_Z[gi] * z)
    }
}

use godot::prelude::*;

use crate::common::GRAD_X;
use crate::common::GRAD_Z;

#[derive(GodotClass)]
#[class(base = RefCounted, rename = PerlinNoise)]
pub(crate) struct PerlinNoise {
    base: Base<RefCounted>,
    x_offset: f32,
    z_offset: f32,
    perm: [u8; 512],
}

#[godot_api]
impl IRefCounted for PerlinNoise {
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
impl PerlinNoise {
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
        perlin_2d(&self.perm, x + self.x_offset, z + self.z_offset)
    }

    #[allow(clippy::too_many_arguments)]
    #[func]
    /// Populates a noise array with Perlin noise values over a given grid.
    ///
    /// # Arguments
    ///
    /// - `out`: The output array to store the noise values.
    /// - `x_offset_param`: The x offset of the grid.
    /// - `z_offset_param`: The z offset of the grid.
    /// - `x_size`: The width of the grid.
    /// - `z_size`: The height of the grid.
    /// - `x_scale`: The x scale of the grid.
    /// - `z_scale`: The z scale of the grid.
    /// - `noise_scale`: The noise scale factor.
    ///
    /// # Returns
    ///
    /// The output array with the populated noise values.
    pub fn populate_noise_array(
        &self,
        mut out: PackedFloat32Array,
        x_offset_param: f32,
        z_offset_param: f32,
        x_size: i32,
        z_size: i32,
        x_scale: f32,
        z_scale: f32,
        noise_scale: f32,
    ) -> PackedFloat32Array {
        let inv_scale = 1.0 / noise_scale;
        let perm = &self.perm;

        let slice = out.as_mut_slice();
        let mut idx = 0usize;

        for gz in 0..z_size as usize {
            let mut real_z = z_offset_param + gz as f32 * z_scale + self.z_offset;
            let mut zi = real_z as i32;
            if real_z < zi as f32 {
                zi -= 1;
            }

            let z0 = (zi & 255) as usize;

            real_z -= zi as f32;
            let fz = real_z * real_z * real_z * (real_z * (real_z * 6.0 - 15.0) + 10.0);

            for gx in 0..x_size as usize {
                let mut real_x = x_offset_param + gx as f32 * x_scale + self.x_offset;
                let mut xi = real_x as i32;
                if real_x < xi as f32 {
                    xi -= 1;
                }

                let x0 = (xi & 255) as usize;

                real_x -= xi as f32;
                let fx = real_x * real_x * real_x * (real_x * (real_x * 6.0 - 15.0) + 10.0);

                let a_hash = perm[x0] as usize;
                let aa = perm[a_hash] as usize + z0;
                let b_hash = perm[x0 + 1] as usize;
                let ba = perm[b_hash] as usize + z0;

                let g = (perm[aa] & 15) as usize;
                let d00 = GRAD_X[g] * real_x + GRAD_Z[g] * real_z;
                let g = (perm[ba] & 15) as usize;
                let d10 = GRAD_X[g] * (real_x - 1.0) + GRAD_Z[g] * real_z;
                let g = (perm[aa + 1] & 15) as usize;
                let d01 = GRAD_X[g] * real_x + GRAD_Z[g] * (real_z - 1.0);
                let g = (perm[ba + 1] & 15) as usize;
                let d11 = GRAD_X[g] * (real_x - 1.0) + GRAD_Z[g] * (real_z - 1.0);

                let lx0 = d00 + (d10 - d00) * fx;
                let lx1 = d01 + (d11 - d01) * fx;
                slice[idx] += (lx0 + (lx1 - lx0) * fz) * inv_scale;
                idx += 1;
            }
        }

        out
    }
}

/// Computes a 2D Perlin noise value at a given point.
///
/// # Arguments
///
/// - `perm`: The permutation array used for noise generation.
/// - `x`: The x coordinate of the point.
/// - `z`: The z coordinate of the point.
///
/// # Returns
///
/// The computed Perlin noise value at the given point.
pub(crate) fn perlin_2d(perm: &[u8; 512], x: f32, z: f32) -> f32 {
    let mut xi = x as i32;
    if x < xi as f32 {
        xi -= 1;
    }

    let mut zi = z as i32;
    if z < zi as f32 {
        zi -= 1;
    }

    let x0 = (xi & 255) as usize;
    let z0 = (zi & 255) as usize;

    let lx = x - xi as f32;
    let lz = z - zi as f32;

    let a_hash = perm[x0] as usize;
    let aa = perm[a_hash] as usize + z0;
    let b_hash = perm[x0 + 1] as usize;
    let ba = perm[b_hash] as usize + z0;

    let g = (perm[aa] & 15) as usize;
    let d00 = GRAD_X[g] * lx + GRAD_Z[g] * lz;
    let g = (perm[ba] & 15) as usize;
    let d10 = GRAD_X[g] * (lx - 1.0) + GRAD_Z[g] * lz;
    let g = (perm[aa + 1] & 15) as usize;
    let d01 = GRAD_X[g] * lx + GRAD_Z[g] * (lz - 1.0);
    let g = (perm[ba + 1] & 15) as usize;
    let d11 = GRAD_X[g] * (lx - 1.0) + GRAD_Z[g] * (lz - 1.0);

    let fx = lx * lx * lx * (lx * (lx * 6.0 - 15.0) + 10.0);
    let fz = lz * lz * lz * (lz * (lz * 6.0 - 15.0) + 10.0);

    let ix0 = d00 + (d10 - d00) * fx;
    let ix1 = d01 + (d11 - d01) * fx;
    ix0 + (ix1 - ix0) * fz
}

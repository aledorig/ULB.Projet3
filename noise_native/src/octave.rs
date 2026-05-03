use godot::prelude::*;

use crate::common::GRAD_X;
use crate::common::GRAD_Z;
use crate::perlin::perlin_2d;

const MAX_OCTAVES: usize = 16;

struct OctaveLayer {
    x_offset: f32,
    z_offset: f32,
    perm: [u8; 512],
}

#[derive(GodotClass)]
#[class(base = RefCounted, rename = OctaveNoise)]
pub(crate) struct OctaveNoise {
    base: Base<RefCounted>,
    layers: Vec<OctaveLayer>,
    octave_count: usize,
}

#[godot_api]
impl IRefCounted for OctaveNoise {
    fn init(base: Base<RefCounted>) -> Self {
        Self {
            base,
            layers: Vec::new(),
            octave_count: 0,
        }
    }
}

#[godot_api]
#[allow(unreachable_pub)]
impl OctaveNoise {
    #[func]
    #[allow(clippy::needless_pass_by_value)]
    pub fn setup(
        &mut self,
        offsets_x: PackedFloat32Array,
        offsets_z: PackedFloat32Array,
        perms: PackedInt32Array,
        octave_count: i32,
    ) {
        self.octave_count = (octave_count as usize).min(MAX_OCTAVES);
        self.layers.clear();

        for i in 0..self.octave_count {
            let mut perm = [0u8; 512];

            for (j, item) in perm.iter_mut().enumerate() {
                *item = (perms.get(i * 512 + j).unwrap_or(0) & 0xFF) as u8;
            }

            self.layers.push(OctaveLayer {
                x_offset: offsets_x.get(i).unwrap_or(0.0),
                z_offset: offsets_z.get(i).unwrap_or(0.0),
                perm,
            });
        }
    }

    #[func]
    pub fn get_value(&self, x: f32, z: f32, x_scale: f32, z_scale: f32) -> f32 {
        let mut result = 0.0f32;
        let mut frequency = 1.0f32;
        let mut amplitude = 1.0f32;

        for layer in &self.layers {
            result += perlin_2d(
                &layer.perm,
                x * x_scale * frequency + layer.x_offset,
                z * z_scale * frequency + layer.z_offset,
            ) * amplitude;

            frequency *= 2.0;
            amplitude *= 0.5;
        }

        result
    }

    #[allow(clippy::too_many_arguments)]
    #[func]
    /// Generates octave noise over a given grid.
    ///
    /// # Arguments
    ///
    /// - `out`: The output array to store the noise values.
    /// - `x_off`: The x offset of the grid.
    /// - `z_off`: The z offset of the grid.
    /// - `x_size`: The width of the grid.
    /// - `z_size`: The height of the grid.
    /// - `x_scale`: The x scale of the grid.
    /// - `z_scale`: The z scale of the grid.
    /// - `max_octaves`: The maximum number of octaves to generate.
    ///
    /// # Returns
    ///
    /// The output array with the generated noise values.
    pub fn generate_octaves(
        &self,
        mut out: PackedFloat32Array,
        x_off: f32,
        z_off: f32,
        x_size: i32,
        z_size: i32,
        x_scale: f32,
        z_scale: f32,
        max_octaves: i32,
    ) -> PackedFloat32Array {
        let n = if max_octaves < 0 {
            self.octave_count
        } else {
            (max_octaves as usize).min(self.octave_count)
        };

        let slice = out.as_mut_slice();
        for v in slice.iter_mut() {
            *v = 0.0;
        }

        let mut frequency = 1.0f32;
        let mut amplitude = 1.0f32;

        for layer in self.layers.iter().take(n) {
            let inv_scale = amplitude; // noise_scale = 1/amplitude in GDScript
            let mut idx = 0usize;

            for gz in 0..z_size as usize {
                let mut real_z =
                    z_off * z_scale * frequency + gz as f32 * z_scale * frequency + layer.z_offset;
                let mut zi = real_z as i32;
                if real_z < zi as f32 {
                    zi -= 1;
                }

                let z0 = (zi & 255) as usize;

                real_z -= zi as f32;
                let fz = real_z * real_z * real_z * (real_z * (real_z * 6.0 - 15.0) + 10.0);

                for gx in 0..x_size as usize {
                    let mut real_x = x_off * x_scale * frequency
                        + gx as f32 * x_scale * frequency
                        + layer.x_offset;
                    let mut xi = real_x as i32;
                    if real_x < xi as f32 {
                        xi -= 1;
                    }

                    let x0 = (xi & 255) as usize;

                    real_x -= xi as f32;
                    let fx = real_x * real_x * real_x * (real_x * (real_x * 6.0 - 15.0) + 10.0);

                    let a_hash = layer.perm[x0] as usize;
                    let aa = layer.perm[a_hash] as usize + z0;
                    let b_hash = layer.perm[x0 + 1] as usize;
                    let ba = layer.perm[b_hash] as usize + z0;

                    let g = (layer.perm[aa] & 15) as usize;
                    let d00 = GRAD_X[g] * real_x + GRAD_Z[g] * real_z;
                    let g = (layer.perm[ba] & 15) as usize;
                    let d10 = GRAD_X[g] * (real_x - 1.0) + GRAD_Z[g] * real_z;
                    let g = (layer.perm[aa + 1] & 15) as usize;
                    let d01 = GRAD_X[g] * real_x + GRAD_Z[g] * (real_z - 1.0);
                    let g = (layer.perm[ba + 1] & 15) as usize;
                    let d11 = GRAD_X[g] * (real_x - 1.0) + GRAD_Z[g] * (real_z - 1.0);

                    let lx0 = d00 + (d10 - d00) * fx;
                    let lx1 = d01 + (d11 - d01) * fx;
                    slice[idx] += (lx0 + (lx1 - lx0) * fz) * inv_scale;
                    idx += 1;
                }
            }

            frequency *= 2.0;
            amplitude *= 0.5;
        }

        out
    }
}

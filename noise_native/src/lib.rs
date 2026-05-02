#![allow(unsafe_code)] // gdext requires unsafe impl ExtensionLibrary

use godot::prelude::*;

mod octave;
mod perlin;
mod simplex;

struct NoiseNative;

#[gdextension]
unsafe impl ExtensionLibrary for NoiseNative {}

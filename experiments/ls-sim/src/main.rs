// Copyright (c) 2024 Zachary Catlin
// SPDX-License-Identifier: Apache-2.0

//! A simulator of the `logistic_snd` module.

fn main() -> std::process::ExitCode {
    use rubato::{SincFixedIn, SincInterpolationParameters};

    let mut args = std::env::args().skip(1).fuse();

    let numeric_args: Vec<Option<u64>> = (&mut args).take(6).map(|s| s.parse().ok()).collect();

    if numeric_args.len() < 6 {
        return usage(true).into();
    }
    let [Some(n_osc), Some(r_inc), Some(frac), Some(phase_bits), Some(freq_res), Some(duration), ..] =
        &numeric_args[..]
    else {
        eprintln!("ls-sim: an argument that should be numeric isn\'t");
        return usage(false).into();
    };

    let Some(out_fname) = args.next() else {
        return usage(true).into();
    };

    let None = args.next() else {
        eprintln!("ls-sim: too many arguments\n");
        return usage(false).into();
    };

    const WAV_SPEC: hound::WavSpec = hound::WavSpec {
        channels: 1,
        sample_rate: 48_000,
        bits_per_sample: 16,
        sample_format: hound::SampleFormat::Int,
    };
    let mut writer = hound::WavWriter::create(out_fname, WAV_SPEC).unwrap();

    const INTERP_PARAMS: SincInterpolationParameters = SincInterpolationParameters {
        sinc_len: 4096,
        f_cutoff: 0.95,
        oversampling_factor: 128,
        interpolation: rubato::SincInterpolationType::Linear,
        window: rubato::WindowFunction::BlackmanHarris2,
    };
    let mut interpolator: SincFixedIn<f32> =
        SincFixedIn::new(48_000f64 / 25_200_000f64, 500.0, INTERP_PARAMS, 32768, 1).unwrap();

    const CLK_FREQUENCY: u64 = 25_200_000;
    let duration_in_clocks: u64 = duration.checked_mul(CLK_FREQUENCY).unwrap();

    let mut hi_rate_samples: Box<AudioBuffer> = Box::default();
    let mut lo_rate_samples: Box<AudioBuffer> = Box::default();
    let buf_len = hi_rate_samples.buf[0].len();
    let mut i = 0; // current index in hi_rate_samples

    let module_params = Parameters {
        n_osc,
        r_inc,
        frac,
        phase_bits,
        freq_res,
    };

    let (snd_a, snd_b) = (
        LogisticSnd::new(&module_params),
        LogisticSnd::new(&module_params),
    );

    for _ in 0..(duration_in_clocks / 2) {
        if i >= buf_len - 1 {
            let (in_used, out_written) = interpolator
                .process_into_buffer(&hi_rate_samples.buf, &mut lo_rate_samples.buf, None)
                .unwrap();

            for sample in lo_rate_samples.buf[0][0..out_written] {
                writer.write_sample(sample);
            }
            if in_used < buf_len {
                hi_rate_samples.buf[0].copy_within(in_used.., 0);
            }
            i = buf_len - in_used;
        }
    }

    // explicitly wrap up writing the output file
    std::mem::drop(writer);
}

fn usage(not_enough: bool) -> u8 {
    eprintln!(
        "{}Usage: ls-sim N_OSC R_INC FRAC PHASE_BITS FREQ_RES duration filename",
        if not_enough {
            "ls-sim: not enough arguments\n"
        } else {
            ""
        }
    );
    1
}

/// Returns a mask where the lower `n` bits are `1`.
const fn low_bits(n: u64) -> u64 {
    (1u64 << n) - 1
}

#[repr(align(4096))]
#[derive(Default)]
struct AudioBuffer {
    pub buf: [[f32; 32768]; 1],
}

struct Parameters {
    n_osc: u64,
    r_inc: u64,
    frac: u64,
    phase_bits: u64,
    freq_res: u64,
}

struct LogisticSnd {}

impl LogisticSnd {
    pub fn new(params: &Parameters) -> Self {}

    pub fn step_into(&self, next: &Self) {}

    pub fn snd(&self) -> f32 {}
}

struct LogsIterateMap {
    frac: u64,

    pub x: u64,
    pub next_ready: bool,

    counter: u32,
    mult1_shift: u64,
    mult2_shift: u64,
    mult_accum: u64,
}

impl LogsIterateMap {
    fn new(frac: u64) -> Self {}

    fn step_into(&self, next: &Self, r: u64) {}
}

struct LogsMixer {
    n: u64,
    counter_mask: u32,

    pub audio_out: bool,

    counter: u32,
}

impl LogsMixer {
    fn new(n: u64, k: u64) -> Self {}

    fn step_into(&self, next: &Self, audio_in: &[LogsNCO]) {}
}

struct LogsNCO {
    n: u64,

    pub snd: u8,

    phase: u64,
}

impl LogsNCO {
    fn new(n: u64) -> Self {}

    fn step_into(&self, next: &Self, step: bool, freq_in: u64) {}
}

struct LogsDivider {
    n: u64,

    pub mod_n: bool,

    counter: u64,
}

impl LogsDivider {
    fn new(n: u64) -> Self {}

    fn step_into(&self, next: &Self) {}
}

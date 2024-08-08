// Copyright (c) 2024 Zachary Catlin
// SPDX-License-Identifier: Apache-2.0

static PROG_NAME: &'static str = "fst2wav";

fn main() -> std::process::ExitCode {
    main_fallible().err().unwrap_or(0).into()
}

fn main_fallible() -> Result<(), u8> {
    use hound::{WavSpec, WavWriter};
    use vcd::Value;

    let args: Vec<String> = std::env::args().collect();

    let [_, ref wav_fname] = args[..] else {
        eprintln!("{}: Wrong number of arguments", PROG_NAME);
        eprintln!("Usage: {} output-wav", PROG_NAME);
        return Err(1);
    };

    let stdin = std::io::stdin();
    let mut vcd_p = vcd::Parser::new(stdin.lock());

    const WAV_SPEC: WavSpec = WavSpec {
        channels: 1,
        sample_rate: 48_000,
        bits_per_sample: 16,
        sample_format: hound::SampleFormat::Int,
    };
    let mut wav = WavWriter::create(wav_fname, WAV_SPEC).map_err(|e| {
        eprintln!("{}: error opening {}: {}", PROG_NAME, wav_fname, e);
        3
    })?;

    let header = vcd_p.parse_header().map_err(|e| {
        eprintln!("{}: error parsing VCD header: {}", PROG_NAME, e);
        4
    })?;

    let clk = header.find_var(&["TOP", "tb", "clk"]).ok_or_else(|| {
        eprintln!("{}: could not find variable clk", PROG_NAME);
        5
    })?.code;

    let snd_out = header.find_var(&["TOP", "tb", "snd_out"]).ok_or_else(|| {
        eprintln!("{}: could not find variable snd_out", PROG_NAME);
        5
    })?.code;

    let mut clk_val = Value::X;
    let mut snd_val = Value::X;
    let mut k: u64 = 0;

    for command_result in vcd_p {
        use vcd::Command::*;

        let command = command_result.map_err(|e| {
            eprintln!("{}: error reading VCD command: {}", PROG_NAME, e);
            6
        })?;
        match command {
            ChangeScalar(i, v) if i == clk => {
                // sample snd_out on the falling edge of the clock
                if clk_val == Value::V1 && v == Value::V0 {
                    let sample = match snd_val { Value::V1 => i16::MAX, _ => i16::MIN };
                    wav.write_sample(sample).unwrap();
                }
                clk_val = v;

                if (k % (1024*1024)) == 0 { eprint!("."); }
                k = k.wrapping_add(1);
            }
            ChangeScalar(i, v) if i == snd_out => {
                snd_val = v;
            }
            _ => {}
        }
    }

    Ok(())
}

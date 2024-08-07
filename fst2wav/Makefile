all: logistic_snd.flac

logistic_snd.flac: logistic_snd.wav
	sox $< $@ -e signed -b 16 -r 48k

logistic_snd.wav: target/release/fst2wav logistic_snd.fst
	fst2vcd logistic_snd.fst | target/release/fst2wav $@

target/release/fst2wav: Cargo.toml Cargo.lock src/main.rs
	cargo build --release

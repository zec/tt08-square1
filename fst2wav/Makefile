all: logistic_snd.flac

.PHONY: all clean

logistic_snd.flac: logistic_snd.wav
	sox $< -b 16 -r 48000 $@

logistic_snd.wav: target/release/fst2wav logistic_snd.fst
	fst2vcd logistic_snd.fst | sed -e 's/^[$$]var logic/$$var wire/' | target/release/fst2wav $@

target/release/fst2wav: Cargo.toml Cargo.lock src/main.rs
	cargo build --release

clean:
	rm -rf logistic_snd.flac logistic_snd.wav target/

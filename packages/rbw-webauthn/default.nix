{ rustPlatform, pkg-config, openssl, systemd, libusb1, hidapi }:

let
  # fetchGit runs at eval time, so cargoLock.lockFile can read Cargo.lock straight from the fetched
  # tree — nothing to commit, no cargoHash to maintain, and a PR bump is just `rev`.
  src = builtins.fetchGit {
    url = "https://github.com/doy/rbw";
    ref = "refs/pull/334/head";
    rev = "02471b8a798e8021a10ff6799f7e997a71a4070a";
  };
in
rustPlatform.buildRustPackage {
  pname = "rbw";
  version = "pr334-webauthn";
  inherit src;

  cargoLock.lockFile = "${src}/Cargo.lock";

  buildFeatures = [ "webauthn" ];

  # fido-hid-rs builds a bindgen wrapper -> needs libclang, provided by bindgenHook.
  nativeBuildInputs = [ pkg-config rustPlatform.bindgenHook ];
  buildInputs = [ openssl systemd libusb1 hidapi ];

  doCheck = false;
}

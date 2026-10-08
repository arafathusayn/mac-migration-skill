#!/bin/bash
# Run ON THE NEW MAC when ~/.cargo/bin was copied from a Mac whose Homebrew rustup used a single
# `rustup-init` binary. Newer Homebrew rustup ships one launcher per proxy (cargo, rustc, …) and no
# rustup-init, so the copied proxies dangle or report rustup's version. This points each proxy at its own
# launcher through the version-independent opt/ path.
set -eu
[[ "${1:-}" == "-h" ]] && { sed -n '2,6p' "$0"; exit 0; }
SRC=/opt/homebrew/opt/rustup/bin
[ -d "$SRC" ] || { echo "Homebrew rustup not installed ($SRC missing)"; exit 1; }
for f in "$SRC"/*; do
  name=$(basename "$f")
  [ -e "$HOME/.cargo/bin/$name" ] || [ -L "$HOME/.cargo/bin/$name" ] || continue
  ln -sfn "$SRC/$name" "$HOME/.cargo/bin/$name"
done
export PATH="$HOME/.cargo/bin:/opt/homebrew/bin:$PATH"
cargo --version; rustc --version
rustup toolchain list
find "$HOME/.cargo/bin" -maxdepth 1 -type l ! -exec test -e {} \; -print | sed 's|^|still broken: |'

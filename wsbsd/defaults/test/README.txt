compare.sh DEFAULTS-COMMAND DOMAIN-PATH: runs one sequence of writes and reads (every type, nested containers, rename, delete, error messages) and prints everything. Run it once with the real macOS `defaults` and once with ours on a path domain
and diff the two outputs (replace the two paths by a placeholder): on 2026-10-29 they are identical (macOS 27 / this build).

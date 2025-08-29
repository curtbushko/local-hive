# LOCAL-HIVE(ish)

An attempt to replicate a local setup of Hive from Vercel. Uses nomad, CNI and firecracker to spin up cells.


# DEVELOPMENT

- Only runs on linux because of firecracker
- Uses nix for setup
- 'make setup' to download all the pieces (all saved locally, errors are ignored if run twice)
- In terminal 1: 'make run-nomad' to run nomad
- In ternminal 2: 'make run' to submit the firecracker task

# TODO

- [ ] cleanup Makefile

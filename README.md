# nanobind P2996 Reflection Test Harness

Test harness for [nanobind26](https://github.com/matthewkolbe/nanobind26), a C++26 reflection extension for [nanobind](https://github.com/wjakob/nanobind). Also tests the [nanobind fork](https://github.com/matthewkolbe/nanobind/tree/reflect) with reflection built in.

## Prerequisites

Docker is required for GCC/Bloomberg tests. Make sure your user is in the `docker` group:

```bash
sudo usermod -aG docker $USER
newgrp docker
```

For `local` tests, only CMake, Ninja, and Python 3 are needed (no Docker).

## Running tests

```bash
# --- nanobind26 (standalone library) ---

./run_nb_tests.sh gcc reflect --nb26        # GCC trunk (Docker)
./run_nb_tests.sh bloomberg reflect --nb26  # Bloomberg clang-p2996 (Docker)
./run_nb_tests.sh local reflect --nb26      # System compiler (no Docker, tests will skip)

# --- nanobind fork (reflection built into nanobind) ---

./run_nb_tests.sh gcc reflect --fork        # GCC trunk (Docker)
./run_nb_tests.sh bloomberg reflect --fork  # Bloomberg clang-p2996 (Docker)
./run_nb_tests.sh gcc --fork                # All nanobind tests, not just reflection
./run_nb_tests.sh local --fork              # System compiler, all tests
```

Docker builds compile GCC/Clang from source and take a long time on first run (~3 GB image). Subsequent runs use the cached image. Pass `--rebuild` to pull a fresh compiler.

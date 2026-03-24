# nanobind P2996 Reflection

Automatic nanobind binding generation via C++26 static reflection. The implementation lives in the [nanobind fork](https://github.com/matthewkolbe/nanobind/tree/reflect) under `include/nanobind/nb_reflect.h`.

## Running tests

```bash
# GCC trunk (Docker)
./run_nb_tests.sh gcc reflect

# Bloomberg clang-p2996 (Docker)
./run_nb_tests.sh bloomberg reflect

# Local compiler (no Docker, reflection tests will skip)
./run_nb_tests.sh local reflect

# All nanobind tests, not just reflection
./run_nb_tests.sh gcc
```

Docker builds compile GCC/Clang from source and take a long time on first run (~3 GB image). Subsequent runs use the cached image. Pass `--rebuild` to pull a fresh compiler.

The `local` option uses your system compiler and creates a venv automatically — no Docker needed. Useful for verifying that all non-reflection tests still pass.

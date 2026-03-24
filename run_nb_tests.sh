#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
NANOBIND_DIR="$PROJECT_DIR/extern/nanobind"

REBUILD=""
COMPILER=""
TEST_NAME=""

VALID_TESTS="reflect enum classes functions stl stl_bind_map stl_bind_vector chrono eval exception callbacks accessor holders intrusive make_iterator ndarray jax tensorflow typing issue thread inter_module specialization stubs"

for arg in "$@"; do
    case "$arg" in
        --rebuild) REBUILD="--no-cache" ;;
        gcc|bloomberg|local) COMPILER="$arg" ;;
        *)
            if echo "$VALID_TESTS" | grep -qw "$arg"; then
                TEST_NAME="$arg"
            else
                echo "Error: unknown argument '$arg'"
                echo "Usage: $0 [gcc|bloomberg|local] [test_name] [--rebuild]"
                echo "Valid test names: $VALID_TESTS"
                exit 1
            fi
            ;;
    esac
done

COMPILER="${COMPILER:-gcc}"

case "$COMPILER" in
    gcc)
        IMAGE="nanobind-reflect-gcc"
        DOCKERFILE="Dockerfile.gcc"
        ;;
    bloomberg)
        IMAGE="nanobind-reflect-bloomberg"
        DOCKERFILE="Dockerfile.bloomberg"
        ;;
esac

TEST_TARGET="${TEST_NAME:+test_$TEST_NAME.py}"

# Clone the nanobind fork if not present
if [ ! -d "$NANOBIND_DIR" ]; then
    echo "Cloning nanobind fork..."
    mkdir -p "$PROJECT_DIR/extern"
    git clone --recursive --branch reflect \
        https://github.com/matthewkolbe/nanobind.git "$NANOBIND_DIR"
fi

if [ "$COMPILER" = "local" ]; then
    VENV_DIR="$PROJECT_DIR/build-local/.venv"
    if [ ! -d "$VENV_DIR" ]; then
        python3 -m venv "$VENV_DIR"
        "$VENV_DIR/bin/pip" install pytest
    fi
    cd "$NANOBIND_DIR"
    cmake -S . -B "$PROJECT_DIR/build-local" -G Ninja -DNB_TEST=ON \
        -DPython_EXECUTABLE="$VENV_DIR/bin/python3"
    cmake --build "$PROJECT_DIR/build-local"
    cd "$PROJECT_DIR/build-local/tests"
    "$VENV_DIR/bin/python3" -m pytest ${TEST_TARGET:-.} -v
else
    docker build $REBUILD -t "$IMAGE" -f "$PROJECT_DIR/$DOCKERFILE" "$PROJECT_DIR"

    docker run --rm \
        -v "$PROJECT_DIR":/workspace \
        -e COMPILER="$COMPILER" \
        -e TEST_TARGET="$TEST_TARGET" \
        "$IMAGE" bash -c "
        cd /workspace/extern/nanobind &&
        cmake -S . -B /workspace/build-\${COMPILER} -G Ninja -DNB_TEST=ON &&
        cmake --build /workspace/build-\${COMPILER} &&
        cd /workspace/build-\${COMPILER}/tests &&
        python3 -m pytest \${TEST_TARGET:-.} -v &&
        chown -R $(id -u):$(id -g) /workspace/build-\${COMPILER}
    "
fi

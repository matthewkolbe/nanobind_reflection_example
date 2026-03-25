#!/bin/bash
set -e

# Check Docker access early (unless running locally)
if [[ ! " $* " =~ " local " ]] && ! docker info &>/dev/null; then
    echo "Error: cannot connect to Docker. Make sure Docker is installed and your user is in the docker group:"
    echo "  sudo usermod -aG docker \$USER"
    echo "  newgrp docker"
    echo ""
    echo "Or use './run_nb_tests.sh local ...' to skip Docker entirely."
    exit 1
fi

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"

REBUILD=""
COMPILER=""
TEST_NAME=""
TARGET=""

VALID_TESTS="reflect enum classes functions stl stl_bind_map stl_bind_vector chrono eval exception callbacks accessor holders intrusive make_iterator ndarray jax tensorflow typing issue thread inter_module specialization stubs"

for arg in "$@"; do
    case "$arg" in
        --rebuild) REBUILD="--no-cache" ;;
        --fork) TARGET="fork" ;;
        --nb26) TARGET="nb26" ;;
        gcc|bloomberg|local) COMPILER="$arg" ;;
        *)
            if echo "$VALID_TESTS" | grep -qw "$arg"; then
                TEST_NAME="$arg"
            else
                echo "Error: unknown argument '$arg'"
                echo "Usage: $0 [gcc|bloomberg|local] [test_name] [--fork|--nb26] [--rebuild]"
                exit 1
            fi
            ;;
    esac
done

COMPILER="${COMPILER:-gcc}"

if [ -z "$TARGET" ]; then
    echo "Error: must specify --fork or --nb26"
    echo "  --fork  Test the nanobind fork (extern/nanobind with nb_reflect.h)"
    echo "  --nb26  Test the nanobind26 standalone library (extern/nanobind26)"
    exit 1
fi

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

# --- Resolve source directory and clone if needed ---

if [ "$TARGET" = "fork" ]; then
    SRC_DIR="$PROJECT_DIR/extern/nanobind"
    if [ ! -d "$SRC_DIR" ]; then
        echo "Cloning nanobind fork..."
        mkdir -p "$PROJECT_DIR/extern"
        git clone --recursive --branch reflect \
            https://github.com/matthewkolbe/nanobind.git "$SRC_DIR"
    fi
    CMAKE_ARGS="-DNB_TEST=ON"
    # For nb26 test name, map to the fork's test name
    if [ "$TEST_NAME" = "reflect" ]; then
        TEST_TARGET="test_reflect.py"
    fi
else
    SRC_DIR="$PROJECT_DIR/extern/nanobind26"
    if [ ! -d "$SRC_DIR" ]; then
        echo "Cloning nanobind26..."
        mkdir -p "$PROJECT_DIR/extern"
        git clone --recursive \
            https://github.com/matthewkolbe/nanobind26.git "$SRC_DIR"
    fi
    CMAKE_ARGS=""
    if [ "$TEST_NAME" = "reflect" ]; then
        TEST_TARGET="test_reflect.py"
    fi
fi

BUILD_SUFFIX="${COMPILER}-${TARGET}"

# --- Run ---

if [ "$COMPILER" = "local" ]; then
    VENV_DIR="$PROJECT_DIR/build-${BUILD_SUFFIX}/.venv"
    if [ ! -d "$VENV_DIR" ]; then
        mkdir -p "$PROJECT_DIR/build-${BUILD_SUFFIX}"
        python3 -m venv "$VENV_DIR"
        "$VENV_DIR/bin/pip" install pytest
    fi
    cd "$SRC_DIR"
    cmake -S . -B "$PROJECT_DIR/build-${BUILD_SUFFIX}" -G Ninja $CMAKE_ARGS \
        -DPython_EXECUTABLE="$VENV_DIR/bin/python3"
    cmake --build "$PROJECT_DIR/build-${BUILD_SUFFIX}"
    cd "$PROJECT_DIR/build-${BUILD_SUFFIX}/tests"
    "$VENV_DIR/bin/python3" -m pytest ${TEST_TARGET:-.} -v
else
    docker build $REBUILD -t "$IMAGE" -f "$PROJECT_DIR/$DOCKERFILE" "$PROJECT_DIR"

    docker run --rm \
        -v "$PROJECT_DIR":/workspace \
        -e BUILD_SUFFIX="$BUILD_SUFFIX" \
        -e TEST_TARGET="$TEST_TARGET" \
        -e CMAKE_ARGS="$CMAKE_ARGS" \
        -e SRC_REL="extern/$(basename $SRC_DIR)" \
        "$IMAGE" bash -c "
        cd /workspace/\${SRC_REL} &&
        cmake -S . -B /workspace/build-\${BUILD_SUFFIX} -G Ninja \${CMAKE_ARGS} &&
        cmake --build /workspace/build-\${BUILD_SUFFIX} &&
        cd /workspace/build-\${BUILD_SUFFIX}/tests &&
        python3 -m pytest \${TEST_TARGET:-.} -v &&
        chown -R $(id -u):$(id -g) /workspace/build-\${BUILD_SUFFIX}
    "
fi

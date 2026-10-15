#!/usr/bin/env bash
set -euxo pipefail

cmake_options=(
  ${CMAKE_ARGS}
  -G Ninja
  -S .
  -B build
  -DCMAKE_BUILD_TYPE=Release
  -DCMAKE_CXX_STANDARD=20
  -DCMAKE_CXX_STANDARD_REQUIRED=ON
  -DCMAKE_INSTALL_PREFIX="${PREFIX}"
  -DDIST_DIR=.
  -DFILAMENT_BUILD_TESTING=OFF
  -DFILAMENT_ENABLE_LTO=OFF
  -DFILAMENT_IMGUI_SOURCE_DIR="${SRC_DIR}/imgui-docking"
  -DFILAMENT_USE_EXTERNAL_ABSL=ON
  -DFILAMENT_SKIP_SAMPLES=ON
  -DFILAMENT_SKIP_SDL2=ON
  -DFILAMENT_SUPPORTS_WEBGPU=OFF
  -DFILAMENT_SUPPORTS_WEBP_TEXTURES=OFF
  -DUSE_STATIC_LIBCXX=OFF
)

if [[ "${CONDA_BUILD_CROSS_COMPILATION:-0}" == "1" ]]; then
  # Filament assumes cross builds need prebuilt host tools, but conda-forge can run target tools via QEMU.
  touch ImportExecutables-Release.cmake
  cmake_options+=("-DCMAKE_CROSSCOMPILING_EMULATOR=${CROSSCOMPILING_EMULATOR:?}")
fi

build_targets=(
  backend
  bluevk
  cmgen
  diffimg
  filabridge
  filaflat
  filagui
  filament
  filamesh
  geometry
  gltfio_core
  glslminifier
  image
  ktxreader
  matc
  matinfo
  matedit
  mipgen
  normal-blending
  resgen
  roughness-prefilter
  shaders
  smol-v
  specgen
  specular-color
  uberarchive
  uberz
  utils
)

if [[ "${target_platform}" == linux-* ]]; then
  cmake_options+=(
    -DFILAMENT_ENABLE_EXPERIMENTAL_GCC_SUPPORT=ON
    -DFILAMENT_SUPPORTS_EGL_ON_LINUX=OFF
    "-DCMAKE_BUILD_RPATH=\$ORIGIN;\$ORIGIN/../lib"
    "-DCMAKE_INSTALL_RPATH=\$ORIGIN;\$ORIGIN/../lib"
  )
  if [[ "${filament_window_system}" == "wayland" ]]; then
    cmake_options+=(
      -DFILAMENT_SUPPORTS_OPENGL=OFF
      -DFILAMENT_SUPPORTS_WAYLAND=ON
      -DFILAMENT_SUPPORTS_XCB=OFF
      -DFILAMENT_SUPPORTS_XLIB=OFF
    )
  elif [[ "${filament_window_system}" == "headless" ]]; then
    # BlueGL has assembly implementations for x86_64 and AArch64 only.
    cmake_options+=(
      -DFILAMENT_SUPPORTS_OPENGL=OFF
      -DFILAMENT_SUPPORTS_EGL_ON_LINUX=OFF
      -DFILAMENT_SUPPORTS_WAYLAND=OFF
      -DFILAMENT_SUPPORTS_XCB=OFF
      -DFILAMENT_SUPPORTS_XLIB=OFF
      -DFILAMENT_USE_SYSTEM_MESHOPTIMIZER=OFF
    )
  elif [[ "${filament_window_system}" == "x11" ]]; then
    cmake_options+=(
      -DFILAMENT_SUPPORTS_OPENGL=ON
      -DFILAMENT_SUPPORTS_WAYLAND=OFF
      -DFILAMENT_SUPPORTS_XCB=ON
      -DFILAMENT_SUPPORTS_XLIB=ON
    )
    build_targets+=(bluegl)
  else
    echo "unsupported Linux window system: ${filament_window_system}" >&2
    exit 1
  fi
elif [[ "${target_platform}" == osx-* ]]; then
  cmake_options+=(
    "-DCMAKE_BUILD_RPATH=@loader_path;@loader_path/../lib"
    "-DCMAKE_INSTALL_RPATH=@loader_path;@loader_path/../lib"
  )
  build_targets+=(bluegl)
fi

if [[ "${target_platform}" == "linux-aarch64" || "${target_platform}" == "osx-arm64" ]]; then
  cmake_options+=(-DFILAMENT_USE_SYSTEM_MESHOPTIMIZER=OFF)
fi

cmake "${cmake_options[@]}"
cmake --build build --parallel "${CPU_COUNT}" --target "${build_targets[@]}"

install -d "${PREFIX}/bin" "${PREFIX}/docs" "${PREFIX}/include" "${PREFIX}/lib"

for tool in \
  cmgen \
  diffimg \
  filamesh \
  glslminifier \
  matc \
  matinfo \
  matedit \
  mipgen \
  normal-blending \
  resgen \
  roughness-prefilter \
  specgen \
  specular-color \
  uberz; do
  install -m 755 "build/tools/${tool}/${tool}" "${PREFIX}/bin/${tool}"
done

for header_dir in \
  filament/include/filament \
  filament/backend/include/backend \
  libs/bluevk/include/bluevk \
  libs/filabridge/include/filament \
  libs/filaflat/include/filaflat \
  libs/filameshio/include/filameshio \
  libs/filagui/include/filagui \
  libs/geometry/include/geometry \
  libs/gltfio/include/gltfio \
  libs/image/include/image \
  libs/ktxreader/include/ktxreader \
  libs/math/include/math \
  libs/utils/include/utils; do
  cp -R "${header_dir}" "${PREFIX}/include/"
done

filament_shared_libraries=(
  filament/libfilament
  filament/backend/libbackend
  libs/bluevk/libbluevk
  libs/filabridge/libfilabridge
  libs/filaflat/libfilaflat
  libs/filameshio/libfilameshio
  libs/geometry/libgeometry
  libs/gltfio/libgltfio_core
  libs/image/libimage
  libs/ktxreader/libktxreader
  libs/utils/libutils
)

if [[ "${target_platform}" == osx-* || "${filament_window_system}" == "x11" ]]; then
  filament_shared_libraries+=(libs/bluegl/libbluegl)
fi

if [[ "${target_platform}" == linux-* ]]; then
  shared_library_suffix=so
elif [[ "${target_platform}" == osx-* ]]; then
  shared_library_suffix=dylib
fi

for shared_library in "${filament_shared_libraries[@]}"; do
  source_path="build/${shared_library}.${shared_library_suffix}"
  test -f "${source_path}"
  install -m 755 "${source_path}" "${PREFIX}/lib/$(basename "${source_path}")"
done

test -f build/libs/filagui/libfilagui.a
install -m 644 build/libs/filagui/libfilagui.a "${PREFIX}/lib/libfilagui.a"

# Data-only archive with the default glTF ubershader materials; see patch 0008.
test -f build/libs/gltfio/libuberarchive.a
install -m 644 build/libs/gltfio/libuberarchive.a "${PREFIX}/lib/libuberarchive.a"
# BSD install on macOS has no -D, so create the directory first.
mkdir -p "${PREFIX}/include/gltfio/materials"
install -m 644 build/libs/gltfio/materials/uberarchive.h "${PREFIX}/include/gltfio/materials/"

if [[ "${target_platform}" == osx-* ]]; then
  for dylib in "${PREFIX}"/lib/lib*.dylib; do
    install_name_tool -id "@rpath/$(basename "${dylib}")" "${dylib}"
  done
fi

install -d "${PREFIX}/lib/cmake/Filament"
install -m 644 "${RECIPE_DIR}/FilamentConfig.cmake" "${PREFIX}/lib/cmake/Filament/FilamentConfig.cmake"

install -m 644 LICENSE README.md "${PREFIX}/"
install -m 644 tools/filamesh/README.md "${PREFIX}/docs/filamesh.md"
install -m 644 tools/matinfo/README.md "${PREFIX}/docs/matinfo.md"
install -m 644 tools/mipgen/README.md "${PREFIX}/docs/mipgen.md"
install -m 644 tools/normal-blending/README.md "${PREFIX}/docs/normal-blending.md"
install -m 644 tools/roughness-prefilter/README.md "${PREFIX}/docs/roughness-prefilter.md"
install -m 644 tools/specular-color/README.md "${PREFIX}/docs/specular-color.md"

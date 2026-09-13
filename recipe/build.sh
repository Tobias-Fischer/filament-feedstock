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
  -DFILAMENT_USE_EXTERNAL_ABSL=ON
  -DFILAMENT_SKIP_SAMPLES=ON
  -DFILAMENT_SKIP_SDL2=ON
  -DFILAMENT_SUPPORTS_WEBGPU=OFF
  -DFILAMENT_SUPPORTS_WEBP_TEXTURES=OFF
  -DUSE_STATIC_LIBCXX=OFF
)

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
  glslminifier
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
  if [[ "${target_platform}" == "linux-ppc64le" ]]; then
    # BlueGL has assembly implementations for x86_64 and AArch64 only.
    cmake_options+=(
      -DFILAMENT_SUPPORTS_OPENGL=OFF
      -DFILAMENT_SUPPORTS_EGL_ON_LINUX=OFF
      -DFILAMENT_SUPPORTS_XCB=OFF
      -DFILAMENT_SUPPORTS_XLIB=OFF
      -DFILAMENT_USE_SYSTEM_MESHOPTIMIZER=OFF
    )
  else
    build_targets+=(bluegl)
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
  libs/filabridge/include/filament \
  libs/filaflat/include/filaflat \
  libs/filagui/include/filagui \
  libs/geometry/include/geometry \
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
  libs/filagui/libfilagui
  libs/geometry/libgeometry
  libs/utils/libutils
)

if [[ "${target_platform}" != "linux-ppc64le" ]]; then
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

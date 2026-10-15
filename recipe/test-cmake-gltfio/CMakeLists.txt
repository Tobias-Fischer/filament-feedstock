cmake_minimum_required(VERSION 3.19)
project(filament_gltfio_test LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

find_package(Filament CONFIG REQUIRED)

foreach(expected_target gltfio_core uberarchive)
  if(NOT TARGET Filament::${expected_target})
    message(FATAL_ERROR "Filament::${expected_target} is missing")
  endif()
endforeach()

add_executable(gltfio_consumer main.cpp)
target_link_libraries(gltfio_consumer PRIVATE Filament::gltfio_core Filament::uberarchive)

enable_testing()
add_test(NAME gltfio_consumer COMMAND gltfio_consumer)

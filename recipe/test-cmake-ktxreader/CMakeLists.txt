cmake_minimum_required(VERSION 3.19)
project(filament_ktx1_roundtrip LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

find_package(Filament CONFIG REQUIRED)

add_executable(ktx1_roundtrip ktx1_roundtrip.cpp)
target_link_libraries(ktx1_roundtrip PRIVATE Filament::ktxreader)

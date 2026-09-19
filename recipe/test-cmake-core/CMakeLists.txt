cmake_minimum_required(VERSION 3.19)
project(filament_config_test LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

find_package(Filament CONFIG REQUIRED)

foreach(expected_target filament filamesh filameshio image ktxreader matc)
  if(NOT TARGET Filament::${expected_target})
    message(FATAL_ERROR "Filament::${expected_target} is missing")
  endif()
endforeach()
if(TARGET Filament::filagui)
  message(FATAL_ERROR "Filament::filagui must come from filament-filagui-static")
endif()

set(test_mesh "${CMAKE_CURRENT_BINARY_DIR}/triangle.filamesh")
add_custom_command(
  OUTPUT "${test_mesh}"
  COMMAND Filament::filamesh "${CMAKE_CURRENT_LIST_DIR}/triangle.obj" "${test_mesh}"
  DEPENDS "${CMAKE_CURRENT_LIST_DIR}/triangle.obj"
  VERBATIM
)
add_custom_target(generate_test_mesh ALL DEPENDS "${test_mesh}")

add_executable(filament_core_consumer main.cpp)
target_link_libraries(filament_core_consumer PRIVATE Filament::filameshio Filament::ktxreader)
add_dependencies(filament_core_consumer generate_test_mesh)

enable_testing()
add_test(NAME filament_core_consumer COMMAND filament_core_consumer "${test_mesh}")

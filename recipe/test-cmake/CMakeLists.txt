cmake_minimum_required(VERSION 3.19)
project(filament_hello_world LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

find_package(Filament CONFIG REQUIRED)

set(imgui_source_dir "${CMAKE_CURRENT_LIST_DIR}/../imgui-docking")
add_library(consumer_imgui STATIC
  "${imgui_source_dir}/imgui.cpp"
  "${imgui_source_dir}/imgui_draw.cpp"
  "${imgui_source_dir}/imgui_tables.cpp"
  "${imgui_source_dir}/imgui_widgets.cpp"
)
target_include_directories(consumer_imgui PUBLIC "${imgui_source_dir}")

add_executable(hello_world hello_world.cpp)
target_link_libraries(hello_world PRIVATE Filament::filagui consumer_imgui)

if(CMAKE_SYSTEM_NAME STREQUAL "Linux" AND CMAKE_SYSTEM_PROCESSOR MATCHES "^(x86_64|AMD64)$")
  find_package(X11 REQUIRED)
  target_compile_definitions(hello_world PRIVATE FILAMENT_TEST_X11=1)
  target_link_libraries(hello_world PRIVATE X11::X11)
endif()

set(material_output "${CMAKE_CURRENT_BINARY_DIR}/bakedColor.filamat")
add_custom_command(
  OUTPUT "${material_output}"
  COMMAND Filament::matc -a opengl -p desktop -o "${material_output}" "${CMAKE_CURRENT_LIST_DIR}/../bakedColor.mat"
  DEPENDS "${CMAKE_CURRENT_LIST_DIR}/../bakedColor.mat"
  VERBATIM
)
add_custom_target(compile_material ALL DEPENDS "${material_output}")
add_dependencies(hello_world compile_material)

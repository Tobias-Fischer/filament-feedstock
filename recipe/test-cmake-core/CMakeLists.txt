cmake_minimum_required(VERSION 3.19)
project(filament_config_test NONE)

find_package(Filament CONFIG REQUIRED)

if(NOT TARGET Filament::filament)
  message(FATAL_ERROR "Filament::filament is missing")
endif()
if(TARGET Filament::filagui)
  message(FATAL_ERROR "Filament::filagui must come from filament-filagui-static")
endif()

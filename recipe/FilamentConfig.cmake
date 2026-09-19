get_filename_component(PACKAGE_PREFIX_DIR "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)

include(CMakeFindDependencyMacro)
find_dependency(tsl-robin-map CONFIG REQUIRED)

if(WIN32)
  set(_filament_library_prefix "")
  set(_filament_shared_suffix ".dll")
  set(_filament_runtime_dir "${PACKAGE_PREFIX_DIR}/bin")
elseif(APPLE)
  set(_filament_library_prefix "lib")
  set(_filament_shared_suffix ".dylib")
  set(_filament_runtime_dir "${PACKAGE_PREFIX_DIR}/lib")
else()
  set(_filament_library_prefix "lib")
  set(_filament_shared_suffix ".so")
  set(_filament_runtime_dir "${PACKAGE_PREFIX_DIR}/lib")
endif()

set(Filament_FOUND TRUE)

function(_filament_import_library target_name library_name)
  set(_filament_library "${_filament_runtime_dir}/${_filament_library_prefix}${library_name}${_filament_shared_suffix}")

  if(NOT EXISTS "${_filament_library}")
    set(Filament_FOUND FALSE PARENT_SCOPE)
    set(Filament_NOT_FOUND_MESSAGE "Missing Filament shared library: ${_filament_library}" PARENT_SCOPE)
    return()
  endif()

  if(NOT TARGET Filament::${target_name})
    add_library(Filament::${target_name} SHARED IMPORTED)
    set_target_properties(Filament::${target_name} PROPERTIES
      IMPORTED_LOCATION "${_filament_library}"
      INTERFACE_COMPILE_FEATURES cxx_std_20
      INTERFACE_INCLUDE_DIRECTORIES "${PACKAGE_PREFIX_DIR}/include"
    )
    if(WIN32)
      set(_filament_implib "${PACKAGE_PREFIX_DIR}/lib/${library_name}.lib")
      if(NOT EXISTS "${_filament_implib}")
        set(Filament_FOUND FALSE PARENT_SCOPE)
        set(Filament_NOT_FOUND_MESSAGE "Missing Filament import library: ${_filament_implib}" PARENT_SCOPE)
        return()
      endif()
      set_target_properties(Filament::${target_name} PROPERTIES
        IMPORTED_IMPLIB "${_filament_implib}"
      )
    endif()
  endif()
endfunction()

function(_filament_import_static_library target_name library_name)
  if(WIN32)
    set(_filament_library "${PACKAGE_PREFIX_DIR}/lib/${library_name}.lib")
  else()
    set(_filament_library "${PACKAGE_PREFIX_DIR}/lib/lib${library_name}.a")
  endif()

  if(NOT EXISTS "${_filament_library}")
    set(Filament_FOUND FALSE PARENT_SCOPE)
    set(Filament_NOT_FOUND_MESSAGE "Missing Filament static library: ${_filament_library}" PARENT_SCOPE)
    return()
  endif()

  if(NOT TARGET Filament::${target_name})
    add_library(Filament::${target_name} STATIC IMPORTED)
    set_target_properties(Filament::${target_name} PROPERTIES
      IMPORTED_LOCATION "${_filament_library}"
      INTERFACE_COMPILE_FEATURES cxx_std_20
      INTERFACE_INCLUDE_DIRECTORIES "${PACKAGE_PREFIX_DIR}/include"
    )
  endif()
endfunction()

if(WIN32)
  # The generated GL/Vulkan loaders are linked statically into backend.dll.
  set(_filament_backend_dependencies "Filament::utils")
  # BlueGL stays static on Windows, so it is not part of backend's link
  # interface. filament-bluegl-static ships it for consumers that call into
  # BlueGL directly; its opengl32/gdi32 dependencies are PRIVATE in the
  # upstream target and so do not survive the archive.
  if(EXISTS "${PACKAGE_PREFIX_DIR}/lib/bluegl.lib")
    _filament_import_static_library(bluegl bluegl)
    if(TARGET Filament::bluegl)
      set_target_properties(Filament::bluegl PROPERTIES
        INTERFACE_LINK_LIBRARIES "opengl32;gdi32"
      )
    endif()
  endif()
else()
  set(_filament_bluegl_library "${_filament_runtime_dir}/${_filament_library_prefix}bluegl${_filament_shared_suffix}")
  if(EXISTS "${_filament_bluegl_library}")
    _filament_import_library(bluegl bluegl)
    set(_filament_backend_dependencies "Filament::bluegl;Filament::bluevk;Filament::utils")
  else()
    set(_filament_backend_dependencies "Filament::bluevk;Filament::utils")
  endif()
  _filament_import_library(bluevk bluevk)
endif()
_filament_import_library(utils utils)
_filament_import_library(filabridge filabridge)
_filament_import_library(filaflat filaflat)
_filament_import_library(backend backend)
_filament_import_library(filameshio filameshio)
_filament_import_library(geometry geometry)
_filament_import_library(image image)
_filament_import_library(ktxreader ktxreader)
_filament_import_library(filament filament)

if(WIN32)
  set(_filament_filagui_library "${PACKAGE_PREFIX_DIR}/lib/filagui.lib")
else()
  set(_filament_filagui_library "${PACKAGE_PREFIX_DIR}/lib/libfilagui.a")
endif()
if(EXISTS "${_filament_filagui_library}")
  _filament_import_static_library(filagui filagui)
endif()

if(Filament_FOUND)
  set_target_properties(Filament::utils PROPERTIES
    INTERFACE_LINK_LIBRARIES "tsl::robin_map"
  )
  if(TARGET Filament::bluevk)
    set_target_properties(Filament::bluevk PROPERTIES
      INTERFACE_LINK_LIBRARIES "Filament::utils"
    )
  endif()
  set_target_properties(Filament::filabridge PROPERTIES
    INTERFACE_LINK_LIBRARIES "Filament::utils"
  )
  set_target_properties(Filament::filaflat PROPERTIES
    INTERFACE_LINK_LIBRARIES "Filament::filabridge;Filament::utils"
  )
  set_target_properties(Filament::filameshio PROPERTIES
    INTERFACE_LINK_LIBRARIES "Filament::filament"
  )
  if(TARGET Filament::filagui)
    # Filagui leaves Dear ImGui unresolved so consumers can link one compatible
    # mainline or docking implementation themselves.
    set_target_properties(Filament::filagui PROPERTIES
      INTERFACE_LINK_LIBRARIES "Filament::filament"
    )
  endif()
  set_target_properties(Filament::image PROPERTIES
    INTERFACE_LINK_LIBRARIES "Filament::utils"
  )
  # Filament's vendored Basis Universal transcoder is linked into ktxreader.
  set_target_properties(Filament::ktxreader PROPERTIES
    INTERFACE_LINK_LIBRARIES "Filament::image;Filament::filament;Filament::utils"
  )
  set_target_properties(Filament::backend PROPERTIES
    INTERFACE_LINK_LIBRARIES "${_filament_backend_dependencies}"
  )
  set_target_properties(Filament::geometry PROPERTIES
    INTERFACE_LINK_LIBRARIES "Filament::utils"
  )
  set_target_properties(Filament::filament PROPERTIES
    INTERFACE_LINK_LIBRARIES "Filament::backend;Filament::filaflat;Filament::filabridge;Filament::geometry;Filament::utils"
  )
endif()

if(NOT TARGET Filament::matc)
  add_executable(Filament::matc IMPORTED)
  set_target_properties(Filament::matc PROPERTIES
    IMPORTED_LOCATION "${PACKAGE_PREFIX_DIR}/bin/matc${CMAKE_EXECUTABLE_SUFFIX}"
  )
endif()

if(NOT TARGET Filament::filamesh)
  add_executable(Filament::filamesh IMPORTED)
  set_target_properties(Filament::filamesh PROPERTIES
    IMPORTED_LOCATION "${PACKAGE_PREFIX_DIR}/bin/filamesh${CMAKE_EXECUTABLE_SUFFIX}"
  )
endif()

@echo on
setlocal EnableExtensions

set "PATH=%CD%\build\filament;%CD%\build\filament\backend;%CD%\build\libs\filabridge;%CD%\build\libs\filaflat;%CD%\build\libs\geometry;%CD%\build\libs\image;%CD%\build\libs\ktxreader;%CD%\build\libs\utils;%PATH%"

cmake %CMAKE_ARGS% -G Ninja -S . -B build ^
  -DCMAKE_BUILD_TYPE=Release ^
  -DCMAKE_CXX_STANDARD=20 ^
  -DCMAKE_CXX_STANDARD_REQUIRED=ON ^
  -DCMAKE_INSTALL_PREFIX="%LIBRARY_PREFIX%" ^
  -DDIST_DIR=. ^
  -DFILAMENT_BUILD_TESTING=OFF ^
  -DFILAMENT_ENABLE_LTO=OFF ^
  -DFILAMENT_IMGUI_SOURCE_DIR="%SRC_DIR%/imgui-docking" ^
  -DFILAMENT_USE_EXTERNAL_ABSL=ON ^
  -DFILAMENT_SKIP_SAMPLES=ON ^
  -DFILAMENT_SKIP_SDL2=ON ^
  -DFILAMENT_SUPPORTS_VULKAN=ON ^
  -DFILAMENT_SUPPORTS_WEBGPU=OFF ^
  -DFILAMENT_SUPPORTS_WEBP_TEXTURES=OFF ^
  -DFILAMENT_USE_SYSTEM_MESHOPTIMIZER=OFF ^
  -DUSE_STATIC_CRT=OFF
if errorlevel 1 exit /b 1

cmake --build build --parallel %CPU_COUNT% --target ^
  backend bluegl bluevk cmgen diffimg filabridge filaflat filagui filament filamesh ^
  geometry glslminifier image ktxreader matc matinfo mipgen normal-blending resgen ^
  roughness-prefilter shaders smol-v specgen specular-color uberz utils
if errorlevel 1 exit /b 1

if not exist "%LIBRARY_BIN%" mkdir "%LIBRARY_BIN%"
if not exist "%LIBRARY_INC%" mkdir "%LIBRARY_INC%"
if not exist "%LIBRARY_LIB%" mkdir "%LIBRARY_LIB%"
if not exist "%PREFIX%\docs" mkdir "%PREFIX%\docs"

for %%T in (cmgen diffimg filamesh glslminifier matc matinfo mipgen normal-blending resgen roughness-prefilter specgen specular-color uberz) do (
  if not exist "build\tools\%%T\%%T.exe" exit /b 1
  copy /Y "build\tools\%%T\%%T.exe" "%LIBRARY_BIN%\%%T.exe" || exit /b 1
)

call :install_library "build\filament" filament || exit /b 1
call :install_library "build\filament\backend" backend || exit /b 1
call :install_library "build\libs\filabridge" filabridge || exit /b 1
call :install_library "build\libs\filaflat" filaflat || exit /b 1
call :install_library "build\libs\filameshio" filameshio || exit /b 1
call :install_library "build\libs\geometry" geometry || exit /b 1
call :install_library "build\libs\image" image || exit /b 1
call :install_library "build\libs\ktxreader" ktxreader || exit /b 1
call :install_library "build\libs\utils" utils || exit /b 1
if not exist "build\libs\filagui\filagui.lib" exit /b 1
copy /Y "build\libs\filagui\filagui.lib" "%LIBRARY_LIB%\filagui.lib" || exit /b 1
rem BlueGL stays static on Windows; ship it for consumers that call into it.
if not exist "build\libs\bluegl\bluegl.lib" exit /b 1
copy /Y "build\libs\bluegl\bluegl.lib" "%LIBRARY_LIB%\bluegl.lib" || exit /b 1

xcopy /E /I /Y "filament\include\filament" "%LIBRARY_INC%\filament" || exit /b 1
xcopy /E /I /Y "filament\backend\include\backend" "%LIBRARY_INC%\backend" || exit /b 1
xcopy /E /I /Y "libs\bluevk\include\bluevk" "%LIBRARY_INC%\bluevk" || exit /b 1
xcopy /E /I /Y "libs\filabridge\include\filament" "%LIBRARY_INC%\filament" || exit /b 1
xcopy /E /I /Y "libs\filaflat\include\filaflat" "%LIBRARY_INC%\filaflat" || exit /b 1
xcopy /E /I /Y "libs\filameshio\include\filameshio" "%LIBRARY_INC%\filameshio" || exit /b 1
xcopy /E /I /Y "libs\filagui\include\filagui" "%LIBRARY_INC%\filagui" || exit /b 1
xcopy /E /I /Y "libs\geometry\include\geometry" "%LIBRARY_INC%\geometry" || exit /b 1
xcopy /E /I /Y "libs\image\include\image" "%LIBRARY_INC%\image" || exit /b 1
xcopy /E /I /Y "libs\ktxreader\include\ktxreader" "%LIBRARY_INC%\ktxreader" || exit /b 1
xcopy /E /I /Y "libs\math\include\math" "%LIBRARY_INC%\math" || exit /b 1
xcopy /E /I /Y "libs\utils\include\utils" "%LIBRARY_INC%\utils" || exit /b 1

if not exist "%LIBRARY_LIB%\cmake\Filament" mkdir "%LIBRARY_LIB%\cmake\Filament"
copy /Y "%RECIPE_DIR%\FilamentConfig.cmake" "%LIBRARY_LIB%\cmake\Filament\FilamentConfig.cmake" || exit /b 1

copy /Y LICENSE "%PREFIX%\LICENSE" || exit /b 1
copy /Y README.md "%PREFIX%\README.md" || exit /b 1
copy /Y tools\filamesh\README.md "%PREFIX%\docs\filamesh.md" || exit /b 1
copy /Y tools\matinfo\README.md "%PREFIX%\docs\matinfo.md" || exit /b 1
copy /Y tools\mipgen\README.md "%PREFIX%\docs\mipgen.md" || exit /b 1
copy /Y tools\normal-blending\README.md "%PREFIX%\docs\normal-blending.md" || exit /b 1
copy /Y tools\roughness-prefilter\README.md "%PREFIX%\docs\roughness-prefilter.md" || exit /b 1
copy /Y tools\specular-color\README.md "%PREFIX%\docs\specular-color.md" || exit /b 1

exit /b 0

:install_library
if not exist "%~1\%~2.dll" exit /b 1
if not exist "%~1\%~2.lib" exit /b 1
copy /Y "%~1\%~2.dll" "%LIBRARY_BIN%\%~2.dll" || exit /b 1
copy /Y "%~1\%~2.lib" "%LIBRARY_LIB%\%~2.lib" || exit /b 1
exit /b 0

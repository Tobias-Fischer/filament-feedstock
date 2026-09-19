import glob
import json
import os
import platform
import sys


def fail(message):
    raise SystemExit(message)


prefix = os.environ["PREFIX"]
metadata_paths = glob.glob(os.path.join(prefix, "conda-meta", "filament-*.json"))

if len(metadata_paths) != 1:
    fail(f"expected exactly one filament package metadata file, found {metadata_paths!r}")

with open(metadata_paths[0], encoding="utf-8") as metadata_file:
    metadata = json.load(metadata_file)

package_files = metadata["files"]

for dependency_name in ("imgui", "libvulkan-headers"):
    if any(dependency.split()[0] == dependency_name for dependency in metadata["depends"]):
        fail(f"filament package must leave {dependency_name} to the consumer")

static_archives = sorted(path for path in package_files if path.endswith(".a"))
if static_archives:
    fail("filament package ships static archives: " + ", ".join(static_archives))

required_shared_libraries = (
    "libbackend",
    "libfilabridge",
    "libfilaflat",
    "libfilament",
    "libfilameshio",
    "libgeometry",
    "libimage",
    "libktxreader",
    "libutils",
)

if sys.platform != "win32":
    required_shared_libraries += ("libbluevk",)
    if platform.machine().lower() not in ("ppc64", "ppc64le"):
        required_shared_libraries += ("libbluegl",)

if sys.platform == "win32":
    for library in required_shared_libraries:
        base_name = library.removeprefix("lib")
        for required_path in (
            f"Library/bin/{base_name}.dll",
            f"Library/lib/{base_name}.lib",
        ):
            if required_path not in package_files:
                fail(f"filament package does not ship {required_path}")
    package_root = "Library/"
    executable_suffix = ".exe"
else:
    for library in required_shared_libraries:
        matches = sorted(
            path
            for path in package_files
            if path.startswith(f"lib/{library}")
            and (".so" in os.path.basename(path) or path.endswith(".dylib"))
        )
        if not matches:
            fail(f"filament package does not ship shared {library}")
    package_root = ""
    executable_suffix = ""

for required_path in (
    f"{package_root}include/bluevk/BlueVK.h",
    f"{package_root}include/filament/Engine.h",
    f"{package_root}include/filameshio/MeshReader.h",
    f"{package_root}include/image/Ktx1Bundle.h",
    f"{package_root}include/ktxreader/Ktx1Reader.h",
    f"{package_root}include/backend/DriverEnums.h",
    f"{package_root}lib/cmake/Filament/FilamentConfig.cmake",
    f"{package_root}bin/matc{executable_suffix}",
    f"{package_root}bin/filamesh{executable_suffix}",
):
    if required_path not in package_files:
        fail(f"filament package does not ship {required_path}")

for forbidden_path in (x for x in (
    f"{package_root}include/filagui/ImGuiHelper.h",
    f"{package_root}lib/filagui.lib" if sys.platform == "win32" else "lib/libfilagui.a",
    f"{package_root}lib/bluegl.lib" if sys.platform == "win32" else None,
    f"{package_root}bin/basisu{executable_suffix}",
    "lib/libabseil.a",
    "lib/libbasis_transcoder.a",
    "lib/libcivetweb.a",
    "lib/libdracodec.a",
    "lib/libmeshoptimizer.a",
    "lib/libmikktspace.a",
    "lib/libperfetto.a",
    "lib/libsmol-v.a",
    "lib/libstb.a",
) if x is not None):
    if forbidden_path in package_files:
        fail(f"filament package ships vendored payload: {forbidden_path}")

for forbidden_prefix in (
    f"{package_root}include/mikktspace/",
    f"{package_root}include/tsl/",
):
    matches = sorted(path for path in package_files if path.startswith(forbidden_prefix))
    if matches:
        fail("filament package ships vendored headers: " + ", ".join(matches[:10]))

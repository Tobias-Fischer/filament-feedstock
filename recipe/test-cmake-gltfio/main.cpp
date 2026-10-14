#include <filament/Camera.h>
#include <filament/Engine.h>
#include <filament/Renderer.h>
#include <filament/Scene.h>
#include <filament/SwapChain.h>
#include <filament/View.h>
#include <filament/Viewport.h>

#include <gltfio/AssetLoader.h>
#include <gltfio/FilamentAsset.h>
#include <gltfio/MaterialProvider.h>
#include <gltfio/ResourceLoader.h>
#include <gltfio/materials/uberarchive.h>

#include <utils/EntityManager.h>
#include <utils/NameComponentManager.h>

#include <cstdint>
#include <cstring>

// One lit triangle; the buffer holds positions, normals, and indices.
static const char kTriangleGltf[] = R"({
  "asset": {"version": "2.0"},
  "scene": 0,
  "scenes": [{"nodes": [0]}],
  "nodes": [{"mesh": 0}],
  "meshes": [{"primitives": [{"attributes": {"POSITION": 0, "NORMAL": 1}, "indices": 2, "material": 0}]}],
  "materials": [{"pbrMetallicRoughness": {"baseColorFactor": [1.0, 0.5, 0.0, 1.0]}}],
  "buffers": [{"byteLength": 78, "uri": "data:application/octet-stream;base64,AAAAAAAAAAAAAAAAAACAPwAAAAAAAAAAAAAAAAAAgD8AAAAAAAAAAAAAAAAAAIA/AAAAAAAAAAAAAIA/AAAAAAAAAAAAAIA/AAABAAIA"}],
  "bufferViews": [
    {"buffer": 0, "byteOffset": 0, "byteLength": 36, "target": 34962},
    {"buffer": 0, "byteOffset": 36, "byteLength": 36, "target": 34962},
    {"buffer": 0, "byteOffset": 72, "byteLength": 6, "target": 34963}
  ],
  "accessors": [
    {"bufferView": 0, "componentType": 5126, "count": 3, "type": "VEC3", "min": [0, 0, 0], "max": [1, 1, 0]},
    {"bufferView": 1, "componentType": 5126, "count": 3, "type": "VEC3"},
    {"bufferView": 2, "componentType": 5123, "count": 3, "type": "SCALAR"}
  ]
})";

// Loads the triangle with the default ubershader archive and renders one frame.
int main() {
    using namespace filament;
    using namespace filament::gltfio;

    Engine* engine = Engine::create(Engine::Backend::NOOP);
    if (engine == nullptr) {
        return 1;
    }

    int result = 0;
    MaterialProvider* materials =
            createUbershaderProvider(engine, UBERARCHIVE_DEFAULT_DATA, UBERARCHIVE_DEFAULT_SIZE);
    utils::NameComponentManager names(utils::EntityManager::get());
    AssetLoader* loader = AssetLoader::create({engine, materials, &names});
    FilamentAsset* asset = loader->createAsset(
            reinterpret_cast<const uint8_t*>(kTriangleGltf), uint32_t(strlen(kTriangleGltf)));
    if (asset == nullptr) {
        result = 2;
    } else {
        ResourceLoader resourceLoader({.engine = engine, .normalizeSkinningWeights = true});
        if (!resourceLoader.loadResources(asset)) {
            result = 3;
        } else if (asset->getRenderableEntityCount() != 1 ||
                asset->getInstance()->getMaterialInstanceCount() != 1 ||
                materials->getMaterialsCount() == 0) {
            result = 4;
        } else {
            SwapChain* swapChain = engine->createSwapChain(64, 64);
            Renderer* renderer = engine->createRenderer();
            Scene* scene = engine->createScene();
            scene->addEntities(asset->getRenderableEntities(), asset->getRenderableEntityCount());
            utils::Entity cameraEntity = utils::EntityManager::get().create();
            Camera* camera = engine->createCamera(cameraEntity);
            View* view = engine->createView();
            view->setViewport({0, 0, 64, 64});
            view->setScene(scene);
            view->setCamera(camera);
            if (renderer->beginFrame(swapChain)) {
                renderer->render(view);
                renderer->endFrame();
            } else {
                result = 5;
            }
            engine->flushAndWait();
            engine->destroy(view);
            engine->destroyCameraComponent(cameraEntity);
            utils::EntityManager::get().destroy(cameraEntity);
            engine->destroy(scene);
            engine->destroy(renderer);
            engine->destroy(swapChain);
        }
        loader->destroyAsset(asset);
    }
    materials->destroyMaterials();
    delete materials;
    AssetLoader::destroy(&loader);
    Engine::destroy(&engine);
    return result;
}

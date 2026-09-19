#include <filament/Camera.h>
#include <filament/Engine.h>
#include <filament/IndexBuffer.h>
#include <filament/Material.h>
#include <filament/RenderableManager.h>
#include <filament/Renderer.h>
#include <filament/Scene.h>
#include <filament/SwapChain.h>
#include <filament/VertexBuffer.h>
#include <filament/View.h>
#include <filament/Viewport.h>

#include <filameshio/MeshReader.h>
#include <image/Ktx1Bundle.h>
#include <ktxreader/Ktx1Reader.h>
#include <utils/EntityManager.h>
#include <utils/Path.h>

#include <cstdint>
#include <vector>

// Round-trips a KTX1 bundle on the CPU. This needs no Engine, and linking it
// is what proves the shared image/ktxreader libraries actually export their
// symbols -- a file-presence check cannot catch a visibility regression.
static bool checkKtx1RoundTrip() {
    image::Ktx1Bundle bundle(1, 1, false);
    bundle.info() = {
            .endianness = 0x04030201,
            .glType = 0x1401,          // GL_UNSIGNED_BYTE
            .glTypeSize = 1,
            .glFormat = 0x1907,        // GL_RGB
            .glInternalFormat = 0x1907,
            .glBaseInternalFormat = 0x1907,
            .pixelWidth = 1,
            .pixelHeight = 1,
            .pixelDepth = 0,
    };

    const uint8_t texel[3] = {0xff, 0x80, 0x00};
    if (!bundle.setBlob({0, 0, 0}, texel, sizeof(texel))) {
        return false;
    }

    std::vector<uint8_t> serialized(bundle.getSerializedLength());
    if (!bundle.serialize(serialized.data(), (uint32_t) serialized.size())) {
        return false;
    }

    image::Ktx1Bundle restored(serialized.data(), (uint32_t) serialized.size());
    uint8_t* data = nullptr;
    uint32_t size = 0;
    return restored.getNumMipLevels() == 1 && restored.getArrayLength() == 1 &&
            restored.getBlob({0, 0, 0}, &data, &size) && size == sizeof(texel) &&
            !ktxreader::Ktx1Reader::isCompressed(restored.getInfo());
}

int main(int argc, char** argv) {
    using namespace filament;

    if (argc != 2) {
        return 1;
    }

    if (!checkKtx1RoundTrip()) {
        return 5;
    }

    Engine* engine = Engine::create(Engine::Backend::NOOP);
    if (engine == nullptr) {
        return 2;
    }

    MaterialInstance* material = engine->getDefaultMaterial()->createInstance();
    filamesh::MeshReader::MaterialRegistry materials;
    materials.registerMaterialInstance("default", material);
    materials.registerMaterialInstance("DefaultMaterial", material);
    auto mesh = filamesh::MeshReader::loadMeshFromFile(
            engine, utils::Path(argv[1]), materials);
    auto& renderableManager = engine->getRenderableManager();
    auto renderable = renderableManager.getInstance(mesh.renderable);
    if (!mesh.renderable || mesh.vertexBuffer == nullptr || mesh.indexBuffer == nullptr ||
            !renderable || renderableManager.getPrimitiveCount(renderable) != 1) {
        materials.unregisterAll();
        engine->destroy(material);
        Engine::destroy(&engine);
        return 3;
    }

    constexpr uint32_t width = 64;
    constexpr uint32_t height = 64;
    SwapChain* swapChain = engine->createSwapChain(width, height);
    Renderer* renderer = engine->createRenderer();
    Scene* scene = engine->createScene();
    scene->addEntity(mesh.renderable);

    utils::Entity cameraEntity = utils::EntityManager::get().create();
    Camera* camera = engine->createCamera(cameraEntity);
    View* view = engine->createView();
    view->setViewport(Viewport{0, 0, width, height});
    view->setScene(scene);
    view->setCamera(camera);
    view->setPostProcessingEnabled(false);

    bool renderedFrame = false;
    if (renderer->beginFrame(swapChain)) {
        renderer->render(view);
        renderer->endFrame();
        renderedFrame = true;
    }
    engine->flushAndWait();

    scene->remove(mesh.renderable);
    engine->destroy(view);
    engine->destroyCameraComponent(cameraEntity);
    utils::EntityManager::get().destroy(cameraEntity);
    engine->destroy(scene);
    engine->destroy(renderer);
    engine->destroy(swapChain);
    engine->destroy(mesh.renderable);
    utils::EntityManager::get().destroy(mesh.renderable);
    engine->destroy(mesh.vertexBuffer);
    engine->destroy(mesh.indexBuffer);
    materials.unregisterAll();
    engine->destroy(material);
    Engine::destroy(&engine);

    return renderedFrame ? 0 : 4;
}

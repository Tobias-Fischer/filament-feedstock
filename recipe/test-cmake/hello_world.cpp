#include <filament/Engine.h>
#include <filament/Renderer.h>
#include <filament/Scene.h>
#include <filament/Skybox.h>
#include <filament/View.h>
#include <filament/Viewport.h>

#include <backend/PixelBufferDescriptor.h>
#include <filagui/ImGuiHelper.h>
#include <imgui.h>

#include <geometry/SurfaceOrientation.h>
#include <utils/EntityManager.h>
#include <utils/LruCache.h>
#include <utils/Path.h>

#include <array>
#include <cstdint>
#include <memory>

#if defined(FILAGUI_TEST_DOCKING) && !defined(IMGUI_HAS_DOCK)
#error "The consumer-provided ImGui must be the docking branch for this test"
#endif

#ifdef FILAMENT_TEST_X11
#include <X11/Xlib.h>
#endif

int main() {
    using namespace filament;
    constexpr uint32_t width = 64;
    constexpr uint32_t height = 64;

    utils::LruCache<int, int> cache("filament-conda-test-cache", 1);
    cache.put(1, 1, [](int&&) {});
    if (cache.get(1) == nullptr) {
        return 1;
    }

    std::array<filament::math::float3, 3> positions = {
            filament::math::float3{0.0f, 0.0f, 0.0f},
            filament::math::float3{1.0f, 0.0f, 0.0f},
            filament::math::float3{0.0f, 1.0f, 0.0f},
    };
    std::array<filament::math::uint3, 1> triangles = {
            filament::math::uint3{0u, 1u, 2u},
    };
    std::unique_ptr<filament::geometry::SurfaceOrientation> orientation(
            filament::geometry::SurfaceOrientation::Builder()
                    .vertexCount(positions.size())
                    .positions(positions.data())
                    .triangleCount(triangles.size())
                    .triangles(triangles.data())
                    .build());
    if (orientation == nullptr || orientation->getVertexCount() != positions.size()) {
        return 1;
    }
    std::array<filament::math::short4, 3> tangents;
    orientation->getQuats(tangents.data(), tangents.size());

#ifdef FILAMENT_TEST_X11
    Display* display = XOpenDisplay(nullptr);
    if (display == nullptr) {
        return 1;
    }
    Window window = XCreateSimpleWindow(
            display, DefaultRootWindow(display), 0, 0, width, height, 0, 0, 0);
    if (window == 0) {
        XCloseDisplay(display);
        return 1;
    }
    XMapWindow(display, window);
    XSync(display, False);
    constexpr Engine::Backend backend = Engine::Backend::VULKAN;
#else
    constexpr Engine::Backend backend = Engine::Backend::NOOP;
#endif

    Engine* engine = Engine::create(backend);
    if (engine == nullptr) {
#ifdef FILAMENT_TEST_X11
        XDestroyWindow(display, window);
        XCloseDisplay(display);
#endif
        return 1;
    }

#ifdef FILAMENT_TEST_X11
    SwapChain* swapChain = engine->createSwapChain(
            reinterpret_cast<void*>(static_cast<std::uintptr_t>(window)));
#else
    SwapChain* swapChain = engine->createSwapChain(width, height);
#endif
    Renderer* renderer = engine->createRenderer();
    Scene* scene = engine->createScene();
    Skybox* skybox = Skybox::Builder()
            .color({0.1f, 0.125f, 0.25f, 1.0f})
            .build(*engine);
    scene->setSkybox(skybox);

    utils::Entity cameraEntity = utils::EntityManager::get().create();
    Camera* camera = engine->createCamera(cameraEntity);

    View* view = engine->createView();
    view->setViewport({0, 0, width, height});
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

    View* guiView = engine->createView();
    guiView->setViewport({0, 0, width, height});
    bool renderedGuiFrame = false;
#ifdef FILAMENT_TEST_X11
    std::array<uint8_t, width * height * 4> guiPixels{};
#endif
    {
        IMGUI_CHECKVERSION();
        filagui::ImGuiHelper gui(engine, guiView, utils::Path());
#ifdef FILAGUI_TEST_DOCKING
        ImGui::GetIO().ConfigFlags |= ImGuiConfigFlags_DockingEnable;
#endif
        gui.setDisplaySize(width, height);
        gui.render(1.0f / 60.0f, [](Engine*, View*) {
#ifdef FILAGUI_TEST_DOCKING
            ImGui::DockSpaceOverViewport();
#endif
            ImGui::SetNextWindowPos({0.0f, 0.0f});
            ImGui::SetNextWindowSize({64.0f, 64.0f});
            ImGui::PushStyleColor(ImGuiCol_WindowBg, {1.0f, 0.0f, 0.0f, 1.0f});
            ImGui::Begin("filagui package test");
            ImGui::TextUnformatted("filagui rendered a frame");
            ImGui::End();
            ImGui::PopStyleColor();
        });
        if (renderer->beginFrame(swapChain)) {
            renderer->render(guiView);
#ifdef FILAMENT_TEST_X11
            renderer->readPixels(0, 0, width, height,
                    backend::PixelBufferDescriptor(guiPixels.data(), guiPixels.size(),
                            backend::PixelDataFormat::RGBA, backend::PixelDataType::UBYTE));
#endif
            renderer->endFrame();
            renderedGuiFrame = true;
        }
        engine->flushAndWait();
    }

#ifdef FILAMENT_TEST_X11
    bool renderedGuiOutput = false;
    for (size_t pixel = 0; pixel < guiPixels.size(); pixel += 4) {
        if (guiPixels[pixel] > guiPixels[pixel + 1] + 16 &&
                guiPixels[pixel] > guiPixels[pixel + 2] + 16) {
            renderedGuiOutput = true;
            break;
        }
    }
#else
    constexpr bool renderedGuiOutput = true;
#endif

    engine->destroy(guiView);
    engine->destroyCameraComponent(cameraEntity);
    utils::EntityManager::get().destroy(cameraEntity);
    engine->destroy(view);
    engine->destroy(skybox);
    engine->destroy(scene);
    engine->destroy(renderer);
    engine->destroy(swapChain);
    Engine::destroy(&engine);

#ifdef FILAMENT_TEST_X11
    XDestroyWindow(display, window);
    XCloseDisplay(display);
#endif

    return renderedFrame && renderedGuiFrame && renderedGuiOutput ? 0 : 2;
}

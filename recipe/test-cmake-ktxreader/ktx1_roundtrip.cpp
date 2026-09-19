// Exercises the packaged image/ktxreader static libraries on the CPU only: no
// Engine, window or GPU driver is required. Linking this also asserts that
// Ktx1Reader does not drag in Filament's unpackaged Basis Universal
// transcoder -- only Ktx2Reader does.
#include <image/Ktx1Bundle.h>
#include <ktxreader/Ktx1Reader.h>

#include <cstdint>
#include <cstdio>
#include <vector>

int main() {
    // Build a small uncompressed RGB bundle and round-trip it through the
    // serialized KTX1 representation.
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
        std::puts("setBlob failed");
        return 1;
    }

    std::vector<uint8_t> serialized(bundle.getSerializedLength());
    if (!bundle.serialize(serialized.data(), (uint32_t) serialized.size())) {
        std::puts("serialize failed");
        return 1;
    }

    image::Ktx1Bundle restored(serialized.data(), (uint32_t) serialized.size());
    if (restored.getNumMipLevels() != 1 || restored.getArrayLength() != 1) {
        std::puts("unexpected bundle geometry after round-trip");
        return 1;
    }

    uint8_t* data = nullptr;
    uint32_t size = 0;
    if (!restored.getBlob({0, 0, 0}, &data, &size) || size != sizeof(texel)) {
        std::puts("getBlob failed after round-trip");
        return 1;
    }

    // Pull in symbols from Ktx1Reader.cpp itself.
    if (ktxreader::Ktx1Reader::isCompressed(restored.getInfo())) {
        std::puts("uncompressed bundle reported as compressed");
        return 1;
    }

    std::puts("ktx1 round-trip ok");
    return 0;
}

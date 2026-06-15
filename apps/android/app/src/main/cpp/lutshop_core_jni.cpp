#include <jni.h>
#include "lutshop/bridge_c.h"

extern "C" {

JNIEXPORT jstring JNICALL
Java_com_lutshop_core_NativeLutShopCore_nativeVersion(JNIEnv* env, jobject /* this */) {
    return env->NewStringUTF(lutshop_core_version());
}

JNIEXPORT jint JNICALL
Java_com_lutshop_core_NativeLutShopCore_nativeApplyLut(
    JNIEnv* env,
    jobject /* this */,
    jstring jCubeText,
    jintArray jPixels,
    jint width,
    jint height,
    jint stride,
    jfloat intensity) {

    if (jCubeText == nullptr || jPixels == nullptr) {
        return -1;
    }

    const char* cubeText = env->GetStringUTFChars(jCubeText, nullptr);
    if (cubeText == nullptr) {
        return -1;
    }

    jint* pixels = env->GetIntArrayElements(jPixels, nullptr);
    if (pixels == nullptr) {
        env->ReleaseStringUTFChars(jCubeText, cubeText);
        return -1;
    }

    // Android Bitmap pixels are ARGB_8888 stored as int (0xAARRGGBB).
    // We need to convert to RGBA byte order for the core function.
    const int pixelCount = width * height;
    auto* rgba = new unsigned char[pixelCount * 4];
    for (int i = 0; i < pixelCount; ++i) {
        jint p = pixels[i];
        rgba[i * 4 + 0] = static_cast<unsigned char>((p >> 16) & 0xFF); // R
        rgba[i * 4 + 1] = static_cast<unsigned char>((p >> 8) & 0xFF);  // G
        rgba[i * 4 + 2] = static_cast<unsigned char>(p & 0xFF);         // B
        rgba[i * 4 + 3] = static_cast<unsigned char>((p >> 24) & 0xFF); // A
    }

    int result = lutshop_apply_cube_to_rgba(cubeText, rgba, width, height, stride, intensity);

    if (result == 0) {
        // Convert back to ARGB_8888 int format
        for (int i = 0; i < pixelCount; ++i) {
            pixels[i] = (static_cast<jint>(rgba[i * 4 + 3]) << 24) |
                        (static_cast<jint>(rgba[i * 4 + 0]) << 16) |
                        (static_cast<jint>(rgba[i * 4 + 1]) << 8) |
                         static_cast<jint>(rgba[i * 4 + 2]);
        }
    }

    delete[] rgba;
    env->ReleaseIntArrayElements(jPixels, pixels, 0);
    env->ReleaseStringUTFChars(jCubeText, cubeText);

    return result;
}

JNIEXPORT jstring JNICALL
Java_com_lutshop_core_NativeLutShopCore_nativeParseCubeTitle(
    JNIEnv* env,
    jobject /* this */,
    jstring jCubeText) {

    if (jCubeText == nullptr) {
        return env->NewStringUTF("");
    }

    const char* cubeText = env->GetStringUTFChars(jCubeText, nullptr);
    if (cubeText == nullptr) {
        return env->NewStringUTF("");
    }

    lutshop_cube_metadata metadata = lutshop_parse_cube_metadata(cubeText, "");
    env->ReleaseStringUTFChars(jCubeText, cubeText);

    return env->NewStringUTF(metadata.title);
}

JNIEXPORT jintArray JNICALL
Java_com_lutshop_core_NativeLutShopCore_nativeParseCubeMetadata(
    JNIEnv* env,
    jobject /* this */,
    jstring jCubeText) {

    jintArray result = env->NewIntArray(3);
    if (result == nullptr) return nullptr;

    jint defaultData[] = {0, 0, 0};
    env->SetIntArrayRegion(result, 0, 3, defaultData);

    if (jCubeText == nullptr) return result;

    const char* cubeText = env->GetStringUTFChars(jCubeText, nullptr);
    if (cubeText == nullptr) return result;

    lutshop_cube_metadata metadata = lutshop_parse_cube_metadata(cubeText, "");
    jint data[] = {metadata.success, metadata.size, static_cast<jint>(metadata.entry_count)};
    env->SetIntArrayRegion(result, 0, 3, data);

    env->ReleaseStringUTFChars(jCubeText, cubeText);
    return result;
}

} // extern "C"

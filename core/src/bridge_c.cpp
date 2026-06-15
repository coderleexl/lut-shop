#include "lutshop/bridge_c.h"

#include "lutshop/cube.hpp"
#include "lutshop/import.hpp"

#include <cstring>
#include <string>

namespace {

void copyCString(char* destination, size_t capacity, const std::string& value) {
  if (capacity == 0) {
    return;
  }
  const auto copyLength = std::min(value.size(), capacity - 1);
  std::memcpy(destination, value.data(), copyLength);
  destination[copyLength] = '\0';
}

}  // namespace

const char* lutshop_core_version(void) {
  return "lutshop-core/0.1";
}

size_t lutshop_import_photo_count(const char* session_id,
                                  const char* session_name,
                                  const lutshop_import_item* items,
                                  size_t item_count) {
  if (session_id == nullptr || session_name == nullptr || items == nullptr) {
    return 0;
  }

  lutshop::ImportRequest request;
  request.sessionId = session_id;
  request.sessionName = session_name;
  request.items.reserve(item_count);

  for (size_t index = 0; index < item_count; ++index) {
    if (items[index].uri == nullptr || items[index].file_name == nullptr ||
        items[index].imported_at == nullptr) {
      return 0;
    }
    request.items.push_back({items[index].uri, items[index].file_name, items[index].imported_at});
  }

  const auto result = lutshop::importPhotos(request);
  return result.success ? result.photos.size() : 0;
}

size_t lutshop_parse_cube_entry_count(const char* cube_text) {
  if (cube_text == nullptr) {
    return 0;
  }

  const auto result = lutshop::parseCube(cube_text);
  return result.success ? result.cube.entries.size() : 0;
}

lutshop_cube_metadata lutshop_parse_cube_metadata(const char* cube_text,
                                                  const char* fallback_title) {
  lutshop_cube_metadata metadata{};
  if (cube_text == nullptr) {
    copyCString(metadata.message, sizeof(metadata.message), "cube text is required");
    return metadata;
  }

  const auto result = lutshop::parseCube(cube_text);
  metadata.success = result.success ? 1 : 0;
  metadata.size = result.cube.size;
  metadata.entry_count = result.cube.entries.size();

  std::string title = result.cube.title;
  if (title.empty() && fallback_title != nullptr) {
    title = fallback_title;
  }
  copyCString(metadata.title, sizeof(metadata.title), title);
  copyCString(metadata.message, sizeof(metadata.message), result.message);
  return metadata;
}

lutshop_rgb lutshop_apply_cube_to_rgb(const char* cube_text,
                                      lutshop_rgb input,
                                      float intensity) {
  if (cube_text == nullptr) {
    return input;
  }

  const auto result = lutshop::parseCube(cube_text);
  if (!result.success) {
    return input;
  }

  const auto output = lutshop::applyCubeTrilinear(result.cube, {input.r, input.g, input.b}, intensity);
  return {output.r, output.g, output.b};
}

int lutshop_apply_cube_to_rgba(const char* cube_text,
                               unsigned char* pixels,
                               int width,
                               int height,
                               int stride,
                               float intensity) {
  if (cube_text == nullptr || pixels == nullptr) {
    return -1;
  }

  const auto result = lutshop::parseCube(cube_text);
  if (!result.success) {
    return -1;
  }

  return lutshop::applyCubeToRgbaBuffer(result.cube, pixels, width, height, stride, intensity)
             ? 0
             : -1;
}

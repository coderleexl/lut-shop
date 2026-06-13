#include "lutshop/cube.hpp"

#include <cmath>
#include <algorithm>
#include <sstream>
#include <string>

namespace lutshop {
namespace {

std::string trimQuote(const std::string& value) {
  if (value.size() >= 2 && value.front() == '"' && value.back() == '"') {
    return value.substr(1, value.size() - 2);
  }
  return value;
}

bool startsWith(const std::string& value, const std::string& prefix) {
  return value.rfind(prefix, 0) == 0;
}

float clamp01(float value) {
  return std::clamp(value, 0.0F, 1.0F);
}

}  // namespace

CubeParseResult parseCube(const std::string& cubeText) {
  CubeParseResult result;
  std::istringstream stream(cubeText);
  std::string line;

  while (std::getline(stream, line)) {
    if (line.empty() || startsWith(line, "#")) {
      continue;
    }

    std::istringstream lineStream(line);
    std::string first;
    lineStream >> first;

    if (first == "TITLE") {
      std::string title;
      std::getline(lineStream >> std::ws, title);
      result.cube.title = trimQuote(title);
      continue;
    }

    if (first == "LUT_3D_SIZE") {
      lineStream >> result.cube.size;
      continue;
    }

    float r = 0.0F;
    float g = 0.0F;
    float b = 0.0F;
    std::istringstream values(line);
    if (values >> r >> g >> b) {
      result.cube.entries.push_back({r, g, b});
    }
  }

  if (result.cube.size <= 0) {
    return {false, "LUT_3D_SIZE is required", {}};
  }

  const auto expected =
      static_cast<std::size_t>(result.cube.size * result.cube.size * result.cube.size);
  if (result.cube.entries.size() != expected) {
    result.message = "cube entry count does not match LUT_3D_SIZE";
    return result;
  }

  result.success = true;
  return result;
}

CubeEntry applyCubeNearest(const CubeLut& cube, CubeEntry input, float intensity) {
  if (cube.size <= 0 || cube.entries.empty()) {
    return input;
  }

  const auto maxIndex = cube.size - 1;
  const auto redIndex = static_cast<int>(std::round(clamp01(input.r) * maxIndex));
  const auto greenIndex = static_cast<int>(std::round(clamp01(input.g) * maxIndex));
  const auto blueIndex = static_cast<int>(std::round(clamp01(input.b) * maxIndex));
  const auto entryIndex = static_cast<std::size_t>(
      redIndex * cube.size * cube.size + greenIndex * cube.size + blueIndex);

  if (entryIndex >= cube.entries.size()) {
    return input;
  }

  const auto blend = clamp01(intensity);
  const auto mapped = cube.entries[entryIndex];
  return {
      input.r + (mapped.r - input.r) * blend,
      input.g + (mapped.g - input.g) * blend,
      input.b + (mapped.b - input.b) * blend,
  };
}

}  // namespace lutshop

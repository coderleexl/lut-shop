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

std::size_t cubeIndex(int size, int redIndex, int greenIndex, int blueIndex) {
  return static_cast<std::size_t>(
      blueIndex * size * size + greenIndex * size + redIndex);
}

CubeEntry mixEntry(const CubeEntry& left, const CubeEntry& right, float amount) {
  return {
      left.r + (right.r - left.r) * amount,
      left.g + (right.g - left.g) * amount,
      left.b + (right.b - left.b) * amount,
  };
}

CubeEntry sampleEntry(const CubeLut& cube, int redIndex, int greenIndex, int blueIndex) {
  const auto entryIndex = cubeIndex(cube.size, redIndex, greenIndex, blueIndex);
  if (entryIndex >= cube.entries.size()) {
    return {};
  }
  return cube.entries[entryIndex];
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

CubeEntry applyCubeTrilinear(const CubeLut& cube, CubeEntry input, float intensity) {
  if (cube.size <= 0 || cube.entries.empty()) {
    return input;
  }

  const auto maxIndex = static_cast<float>(cube.size - 1);
  const auto redPosition = clamp01(input.r) * maxIndex;
  const auto greenPosition = clamp01(input.g) * maxIndex;
  const auto bluePosition = clamp01(input.b) * maxIndex;

  const auto redLow = static_cast<int>(std::floor(redPosition));
  const auto greenLow = static_cast<int>(std::floor(greenPosition));
  const auto blueLow = static_cast<int>(std::floor(bluePosition));
  const auto redHigh = std::min(redLow + 1, cube.size - 1);
  const auto greenHigh = std::min(greenLow + 1, cube.size - 1);
  const auto blueHigh = std::min(blueLow + 1, cube.size - 1);

  const auto redAmount = redPosition - static_cast<float>(redLow);
  const auto greenAmount = greenPosition - static_cast<float>(greenLow);
  const auto blueAmount = bluePosition - static_cast<float>(blueLow);

  const auto c000 = sampleEntry(cube, redLow, greenLow, blueLow);
  const auto c100 = sampleEntry(cube, redHigh, greenLow, blueLow);
  const auto c010 = sampleEntry(cube, redLow, greenHigh, blueLow);
  const auto c110 = sampleEntry(cube, redHigh, greenHigh, blueLow);
  const auto c001 = sampleEntry(cube, redLow, greenLow, blueHigh);
  const auto c101 = sampleEntry(cube, redHigh, greenLow, blueHigh);
  const auto c011 = sampleEntry(cube, redLow, greenHigh, blueHigh);
  const auto c111 = sampleEntry(cube, redHigh, greenHigh, blueHigh);

  const auto c00 = mixEntry(c000, c100, redAmount);
  const auto c10 = mixEntry(c010, c110, redAmount);
  const auto c01 = mixEntry(c001, c101, redAmount);
  const auto c11 = mixEntry(c011, c111, redAmount);
  const auto c0 = mixEntry(c00, c10, greenAmount);
  const auto c1 = mixEntry(c01, c11, greenAmount);

  const auto blend = clamp01(intensity);
  const auto mapped = mixEntry(c0, c1, blueAmount);
  return {
      input.r + (mapped.r - input.r) * blend,
      input.g + (mapped.g - input.g) * blend,
      input.b + (mapped.b - input.b) * blend,
  };
}

bool applyCubeToRgbaBuffer(const CubeLut& cube,
                           unsigned char* pixels,
                           int width,
                           int height,
                           int stride,
                           float intensity) {
  if (cube.size <= 0 || cube.entries.empty() || pixels == nullptr ||
      width <= 0 || height <= 0) {
    return false;
  }

  for (int y = 0; y < height; ++y) {
    auto* row = pixels + static_cast<std::ptrdiff_t>(y) * stride;
    for (int x = 0; x < width; ++x) {
      auto* px = row + x * 4;
      CubeEntry input{
          static_cast<float>(px[0]) / 255.0F,
          static_cast<float>(px[1]) / 255.0F,
          static_cast<float>(px[2]) / 255.0F,
      };
      const auto output = applyCubeTrilinear(cube, input, intensity);
      px[0] = static_cast<unsigned char>(std::round(clamp01(output.r) * 255.0F));
      px[1] = static_cast<unsigned char>(std::round(clamp01(output.g) * 255.0F));
      px[2] = static_cast<unsigned char>(std::round(clamp01(output.b) * 255.0F));
      // alpha channel (px[3]) is preserved
    }
  }
  return true;
}

}  // namespace lutshop

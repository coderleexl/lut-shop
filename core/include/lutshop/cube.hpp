#pragma once

#include <string>
#include <vector>

namespace lutshop {

struct CubeEntry {
  float r = 0.0F;
  float g = 0.0F;
  float b = 0.0F;
};

struct CubeLut {
  std::string title;
  int size = 0;
  std::vector<CubeEntry> entries;
};

struct CubeParseResult {
  bool success = false;
  std::string message;
  CubeLut cube;
};

CubeParseResult parseCube(const std::string& cubeText);
CubeEntry applyCubeTrilinear(const CubeLut& cube, CubeEntry input, float intensity);

// Apply LUT to an RGBA8 pixel buffer in-place. Returns true on success.
bool applyCubeToRgbaBuffer(const CubeLut& cube,
                           unsigned char* pixels,
                           int width,
                           int height,
                           int stride,
                           float intensity);

}  // namespace lutshop

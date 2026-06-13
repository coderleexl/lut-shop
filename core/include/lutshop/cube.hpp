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
CubeEntry applyCubeNearest(const CubeLut& cube, CubeEntry input, float intensity);

}  // namespace lutshop

#pragma once

#include <string>
#include <vector>

#include "lutshop/types.hpp"

namespace lutshop {

OperationResult importLutMetadata(std::vector<Lut>& luts,
                                  const std::string& lutId,
                                  const std::string& name,
                                  LutCategory category,
                                  std::vector<std::string> tags);

OperationResult renameLut(std::vector<Lut>& luts,
                          const std::string& lutId,
                          const std::string& name);

OperationResult deleteLut(std::vector<Lut>& luts,
                          const std::string& lutId);

OperationResult toggleLutFavorite(std::vector<Lut>& luts,
                                  const std::string& lutId);

}  // namespace lutshop

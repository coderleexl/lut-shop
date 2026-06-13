#include "lutshop/lut_catalog.hpp"

#include <algorithm>
#include <utility>

namespace lutshop {
namespace {

auto findLut(std::vector<Lut>& luts, const std::string& lutId) {
  return std::find_if(luts.begin(), luts.end(), [&](const Lut& lut) {
    return lut.id == lutId;
  });
}

bool exists(const std::vector<Lut>& luts, const std::string& lutId) {
  return std::any_of(luts.begin(), luts.end(), [&](const Lut& lut) {
    return lut.id == lutId;
  });
}

}  // namespace

OperationResult importLutMetadata(std::vector<Lut>& luts,
                                  const std::string& lutId,
                                  const std::string& name,
                                  LutCategory category,
                                  std::vector<std::string> tags) {
  if (lutId.empty() || name.empty()) {
    return {false, "lut id and name are required"};
  }
  if (exists(luts, lutId)) {
    return {false, "lut already exists"};
  }

  Lut lut;
  lut.id = lutId;
  lut.name = name;
  lut.category = category;
  lut.tags = std::move(tags);
  luts.insert(luts.begin(), std::move(lut));
  return {true, ""};
}

OperationResult renameLut(std::vector<Lut>& luts,
                          const std::string& lutId,
                          const std::string& name) {
  if (name.empty()) {
    return {false, "lut name is required"};
  }
  const auto lut = findLut(luts, lutId);
  if (lut == luts.end()) {
    return {false, "lut not found"};
  }
  lut->name = name;
  return {true, ""};
}

OperationResult deleteLut(std::vector<Lut>& luts,
                          const std::string& lutId) {
  const auto before = luts.size();
  luts.erase(std::remove_if(luts.begin(), luts.end(), [&](const Lut& lut) {
               return lut.id == lutId;
             }),
             luts.end());
  return {luts.size() != before, luts.size() != before ? "" : "lut not found"};
}

OperationResult toggleLutFavorite(std::vector<Lut>& luts,
                                  const std::string& lutId) {
  const auto lut = findLut(luts, lutId);
  if (lut == luts.end()) {
    return {false, "lut not found"};
  }
  lut->isFavorite = !lut->isFavorite;
  return {true, ""};
}

}  // namespace lutshop

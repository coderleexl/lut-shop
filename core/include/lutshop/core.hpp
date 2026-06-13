#pragma once

#include <cstddef>
#include <string>
#include <vector>

#include "lutshop/import.hpp"
#include "lutshop/lut_catalog.hpp"
#include "lutshop/recommendation.hpp"
#include "lutshop/session.hpp"
#include "lutshop/types.hpp"
#include "lutshop/workflow.hpp"

namespace lutshop {

class LutShopCore {
 public:
  OperationResult createSession(std::vector<Session>& sessions,
                                const std::string& sessionId,
                                const std::string& name) const;

  OperationResult renameSession(std::vector<Session>& sessions,
                                const std::string& sessionId,
                                const std::string& name) const;

  OperationResult deleteEmptySession(std::vector<Session>& sessions,
                                     const std::vector<Photo>& photos,
                                     const std::string& sessionId) const;

  ImportResult importPhotos(const ImportRequest& request) const;

  std::vector<Photo> filterPhotos(const std::vector<Photo>& photos,
                                  PhotoFilter filter,
                                  const std::string& searchText) const;

  std::vector<Photo> sortPhotos(const std::vector<Photo>& photos,
                                PhotoSort sort) const;

  OperationResult importLutMetadata(std::vector<Lut>& luts,
                                    const std::string& lutId,
                                    const std::string& name,
                                    LutCategory category,
                                    std::vector<std::string> tags) const;

  std::vector<LutRecommendation> recommendLuts(const Photo& photo,
                                               const std::vector<Lut>& luts,
                                               std::size_t limit) const;
};

}  // namespace lutshop

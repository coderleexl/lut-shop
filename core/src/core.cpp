#include "lutshop/core.hpp"

#include <utility>

namespace lutshop {

OperationResult LutShopCore::createSession(std::vector<Session>& sessions,
                                           const std::string& sessionId,
                                           const std::string& name) const {
  return lutshop::createSession(sessions, sessionId, name);
}

OperationResult LutShopCore::renameSession(std::vector<Session>& sessions,
                                           const std::string& sessionId,
                                           const std::string& name) const {
  return lutshop::renameSession(sessions, sessionId, name);
}

OperationResult LutShopCore::deleteEmptySession(std::vector<Session>& sessions,
                                                const std::vector<Photo>& photos,
                                                const std::string& sessionId) const {
  return lutshop::deleteEmptySession(sessions, photos, sessionId);
}

ImportResult LutShopCore::importPhotos(const ImportRequest& request) const {
  return lutshop::importPhotos(request);
}

std::vector<Photo> LutShopCore::filterPhotos(const std::vector<Photo>& photos,
                                             PhotoFilter filter,
                                             const std::string& searchText) const {
  return lutshop::filterPhotos(photos, filter, searchText);
}

std::vector<Photo> LutShopCore::sortPhotos(const std::vector<Photo>& photos,
                                           PhotoSort sort) const {
  return lutshop::sortPhotos(photos, sort);
}

OperationResult LutShopCore::importLutMetadata(std::vector<Lut>& luts,
                                               const std::string& lutId,
                                               const std::string& name,
                                               LutCategory category,
                                               std::vector<std::string> tags) const {
  return lutshop::importLutMetadata(luts, lutId, name, category, std::move(tags));
}

std::vector<LutRecommendation> LutShopCore::recommendLuts(
    const Photo& photo,
    const std::vector<Lut>& luts,
    std::size_t limit) const {
  const MockLutRecommender recommender(luts);
  return recommender.recommend(photo, limit);
}

}  // namespace lutshop

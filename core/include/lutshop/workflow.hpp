#pragma once

#include <cstdint>
#include <string>
#include <vector>

#include "lutshop/types.hpp"

namespace lutshop {

enum class PhotoFilter {
  All,
  Raw,
  Edited,
  Exported,
  Favorites,
};

std::vector<Photo> filterPhotos(const std::vector<Photo>& photos,
                                PhotoFilter filter,
                                const std::string& searchText);

void togglePhotoSelection(std::vector<Photo>& photos, const std::string& photoId);

void toggleFavorite(std::vector<Photo>& photos, const std::string& photoId);

void applyLutToPhotos(std::vector<Photo>& photos,
                      const std::vector<std::string>& photoIds,
                      const std::string& lutId,
                      std::uint8_t intensity);

void ratePhotos(std::vector<Photo>& photos,
                const std::vector<std::string>& photoIds,
                std::uint8_t rating);

void markPhotosExported(std::vector<Photo>& photos,
                        const std::vector<std::string>& photoIds);

}  // namespace lutshop

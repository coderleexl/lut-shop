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

enum class PhotoSort {
  FileName,
  Newest,
  Rating,
  Status,
};

std::vector<Photo> filterPhotos(const std::vector<Photo>& photos,
                                PhotoFilter filter,
                                const std::string& searchText);

std::vector<Photo> sortPhotos(const std::vector<Photo>& photos,
                              PhotoSort sort);

void togglePhotoSelection(std::vector<Photo>& photos, const std::string& photoId);

void toggleFavorite(std::vector<Photo>& photos, const std::string& photoId);

void applyLutToPhotos(std::vector<Photo>& photos,
                      const std::vector<std::string>& photoIds,
                      const std::string& lutId,
                      float intensity);

void ratePhotos(std::vector<Photo>& photos,
                const std::vector<std::string>& photoIds,
                std::uint8_t rating);

void markPhotosExported(std::vector<Photo>& photos,
                        const std::vector<std::string>& photoIds);

}  // namespace lutshop

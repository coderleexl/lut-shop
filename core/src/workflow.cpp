#include "lutshop/workflow.hpp"

#include <algorithm>
#include <cctype>
#include <string>

namespace lutshop {
namespace {

std::string lowerCopy(const std::string& value) {
  std::string result = value;
  std::transform(result.begin(), result.end(), result.begin(), [](unsigned char ch) {
    return static_cast<char>(std::tolower(ch));
  });
  return result;
}

bool containsId(const std::vector<std::string>& ids, const std::string& id) {
  return std::find(ids.begin(), ids.end(), id) != ids.end();
}

bool matchesFilter(const Photo& photo, PhotoFilter filter) {
  switch (filter) {
    case PhotoFilter::All:
      return true;
    case PhotoFilter::Raw:
      return photo.status == PhotoStatus::Raw;
    case PhotoFilter::Edited:
      return photo.status == PhotoStatus::Edited;
    case PhotoFilter::Exported:
      return photo.status == PhotoStatus::Exported;
    case PhotoFilter::Favorites:
      return photo.isFavorite;
  }
  return true;
}

bool matchesSearch(const Photo& photo, const std::string& searchText) {
  if (searchText.empty()) {
    return true;
  }
  const auto query = lowerCopy(searchText);
  return lowerCopy(photo.fileName).find(query) != std::string::npos ||
         lowerCopy(photo.sessionId).find(query) != std::string::npos;
}

}  // namespace

std::vector<Photo> filterPhotos(const std::vector<Photo>& photos,
                                PhotoFilter filter,
                                const std::string& searchText) {
  std::vector<Photo> result;
  for (const auto& photo : photos) {
    if (matchesFilter(photo, filter) && matchesSearch(photo, searchText)) {
      result.push_back(photo);
    }
  }
  return result;
}

void togglePhotoSelection(std::vector<Photo>& photos, const std::string& photoId) {
  for (auto& photo : photos) {
    if (photo.id == photoId) {
      photo.isSelected = !photo.isSelected;
      return;
    }
  }
}

void toggleFavorite(std::vector<Photo>& photos, const std::string& photoId) {
  for (auto& photo : photos) {
    if (photo.id == photoId) {
      photo.isFavorite = !photo.isFavorite;
      return;
    }
  }
}

void applyLutToPhotos(std::vector<Photo>& photos,
                      const std::vector<std::string>& photoIds,
                      const std::string& lutId,
                      std::uint8_t intensity) {
  const auto clampedIntensity = std::min<std::uint8_t>(intensity, 100);
  for (auto& photo : photos) {
    if (containsId(photoIds, photo.id)) {
      photo.appliedLutId = lutId;
      photo.lutIntensity = clampedIntensity;
      photo.status = PhotoStatus::Edited;
    }
  }
}

void ratePhotos(std::vector<Photo>& photos,
                const std::vector<std::string>& photoIds,
                std::uint8_t rating) {
  const auto clampedRating = std::min<std::uint8_t>(rating, 5);
  for (auto& photo : photos) {
    if (containsId(photoIds, photo.id)) {
      photo.rating = clampedRating;
    }
  }
}

void markPhotosExported(std::vector<Photo>& photos,
                        const std::vector<std::string>& photoIds) {
  for (auto& photo : photos) {
    if (containsId(photoIds, photo.id)) {
      photo.status = PhotoStatus::Exported;
    }
  }
}

}  // namespace lutshop

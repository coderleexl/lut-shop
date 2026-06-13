#include "lutshop/import.hpp"

#include <string>

namespace lutshop {

ImportResult importPhotos(const ImportRequest& request) {
  if (request.sessionId.empty() || request.sessionName.empty()) {
    return {false, "target session is required", {}};
  }

  ImportResult result;
  result.success = true;
  result.photos.reserve(request.items.size());

  std::size_t index = 0;
  for (const auto& item : request.items) {
    ++index;
    if (item.uri.empty() || item.fileName.empty()) {
      result.success = false;
      result.message = "import item uri and file name are required";
      result.photos.clear();
      return result;
    }

    Photo photo;
    photo.id = "import-" + std::to_string(index);
    photo.fileName = item.fileName;
    photo.uri = item.uri;
    photo.importedAt = item.importedAt;
    photo.sessionId = request.sessionId;
    photo.sessionName = request.sessionName;
    photo.status = PhotoStatus::Raw;
    result.photos.push_back(photo);
  }

  return result;
}

}  // namespace lutshop

#pragma once

#include <string>
#include <vector>

#include "lutshop/types.hpp"

namespace lutshop {

struct ImportItem {
  std::string uri;
  std::string fileName;
  std::string importedAt;
};

struct ImportRequest {
  std::string sessionId;
  std::string sessionName;
  std::vector<ImportItem> items;
};

struct ImportResult {
  bool success = false;
  std::string message;
  std::vector<Photo> photos;
};

ImportResult importPhotos(const ImportRequest& request);

}  // namespace lutshop

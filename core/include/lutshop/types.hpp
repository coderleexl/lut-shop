#pragma once

#include <cstdint>
#include <string>
#include <vector>

namespace lutshop {

enum class PhotoStatus {
  Raw,
  Edited,
  Exported,
};

enum class LutCategory {
  Portrait,
  Landscape,
  Film,
  BlackWhite,
  Commercial,
  Custom,
};

enum class ExportFormat {
  Jpg,
  Png,
};

enum class ExportSize {
  Original,
  Px2048,
  Px1080,
};

enum class ExportQuality {
  High,
  Medium,
  Low,
};

struct Photo {
  std::string id;
  std::string fileName;
  std::string uri;
  std::string importedAt;
  std::string sessionId;
  std::string sessionName;
  bool isFavorite = false;
  bool isSelected = false;
  std::uint8_t rating = 0;
  std::string appliedLutId;
  float lutIntensity = 0.0F;
  PhotoStatus status = PhotoStatus::Raw;
  std::vector<std::string> analysisTags;
  std::vector<std::string> recommendedLutIds;
};

struct Session {
  std::string id;
  std::string name;
  std::string createdAt;
};

struct Lut {
  std::string id;
  std::string name;
  LutCategory category = LutCategory::Custom;
  std::vector<std::string> tags;
  std::vector<std::string> previewColors;
  bool isFavorite = false;
  std::uint32_t usageCount = 0;
};

struct LutRecommendation {
  std::string photoId;
  std::string lutId;
  std::uint8_t confidence = 0;
  std::vector<std::string> reasons;
};

struct ExportSettings {
  ExportFormat format = ExportFormat::Jpg;
  ExportSize size = ExportSize::Original;
  ExportQuality quality = ExportQuality::High;
  bool preserveExif = true;
};

struct OperationResult {
  bool success = false;
  std::string message;
};

}  // namespace lutshop

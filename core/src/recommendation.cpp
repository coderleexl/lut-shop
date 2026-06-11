#include "lutshop/recommendation.hpp"

#include <algorithm>
#include <cstdint>
#include <string>
#include <vector>

namespace lutshop {
namespace {

bool contains(const std::vector<std::string>& values, const std::string& needle) {
  return std::find(values.begin(), values.end(), needle) != values.end();
}

std::uint8_t confidenceForScore(std::size_t score, std::uint32_t usageCount) {
  if (score >= 2) {
    return 92;
  }
  if (score == 1) {
    return 84;
  }
  return static_cast<std::uint8_t>(std::min<std::uint32_t>(72, 55 + usageCount));
}

std::vector<std::string> matchingReasons(const Photo& photo, const Lut& lut) {
  std::vector<std::string> reasons;
  for (const auto& tag : photo.analysisTags) {
    if (contains(lut.tags, tag)) {
      reasons.push_back(tag);
    }
  }
  if (reasons.empty()) {
    reasons.push_back("popular");
  }
  return reasons;
}

}  // namespace

MockLutRecommender::MockLutRecommender(std::vector<Lut> luts)
    : luts_(std::move(luts)) {}

std::vector<LutRecommendation> MockLutRecommender::recommend(const Photo& photo,
                                                             std::size_t limit) const {
  struct ScoredLut {
    const Lut* lut;
    std::size_t tagScore;
  };

  std::vector<ScoredLut> scored;
  for (const auto& lut : luts_) {
    std::size_t tagScore = 0;
    for (const auto& tag : photo.analysisTags) {
      if (contains(lut.tags, tag)) {
        ++tagScore;
      }
    }
    scored.push_back({&lut, tagScore});
  }

  std::sort(scored.begin(), scored.end(), [](const ScoredLut& lhs, const ScoredLut& rhs) {
    if (lhs.tagScore != rhs.tagScore) {
      return lhs.tagScore > rhs.tagScore;
    }
    return lhs.lut->usageCount > rhs.lut->usageCount;
  });

  std::vector<LutRecommendation> results;
  for (const auto& item : scored) {
    if (results.size() >= limit) {
      break;
    }
    results.push_back({photo.id,
                       item.lut->id,
                       confidenceForScore(item.tagScore, item.lut->usageCount),
                       matchingReasons(photo, *item.lut)});
  }

  return results;
}

}  // namespace lutshop

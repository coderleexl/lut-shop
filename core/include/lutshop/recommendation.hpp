#pragma once

#include <cstddef>
#include <vector>

#include "lutshop/types.hpp"

namespace lutshop {

class LutRecommender {
 public:
  virtual ~LutRecommender() = default;

  virtual std::vector<LutRecommendation> recommend(const Photo& photo,
                                                   std::size_t limit) const = 0;
};

class MockLutRecommender final : public LutRecommender {
 public:
  explicit MockLutRecommender(std::vector<Lut> luts);

  std::vector<LutRecommendation> recommend(const Photo& photo,
                                           std::size_t limit) const override;

 private:
  std::vector<Lut> luts_;
};

}  // namespace lutshop

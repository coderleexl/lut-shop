#include <cstdlib>
#include <iostream>
#include <string>
#include <vector>

#include "lutshop/types.hpp"
#include "lutshop/recommendation.hpp"
#include "lutshop/workflow.hpp"

namespace {

void require(bool condition, const std::string& message) {
  if (!condition) {
    std::cerr << "FAIL: " << message << '\n';
    std::exit(1);
  }
}

void test_photo_model_defaults() {
  lutshop::Photo photo{
      "p1",
      "IMG_0123.CR3",
      "asset://img-0123",
      "2026-06-08T14:32:00Z",
      "session-1",
      false,
      false,
      0,
      "",
      0,
      lutshop::PhotoStatus::Raw,
      {"portrait"},
      {}};

  require(photo.fileName == "IMG_0123.CR3", "photo file name is stored");
  require(photo.status == lutshop::PhotoStatus::Raw, "photo status is raw");
  require(photo.analysisTags.size() == 1, "analysis tag is stored");
}

std::vector<lutshop::Photo> samplePhotos() {
  return {
      {"p1", "IMG_0123.CR3", "asset://1", "2026-06-08T14:32:00Z", "s1", false,
       false, 0, "", 0, lutshop::PhotoStatus::Raw, {"portrait"}, {}},
      {"p2", "IMG_0124.CR3", "asset://2", "2026-06-08T14:33:00Z", "s1", true,
       false, 4, "cine-teal", 68, lutshop::PhotoStatus::Edited, {"landscape"}, {}},
      {"p3", "IMG_0125.CR3", "asset://3", "2026-06-08T14:34:00Z", "s1", false,
       true, 5, "gold-200", 80, lutshop::PhotoStatus::Exported, {"film"}, {}}};
}

void test_filter_photos_by_search_status_and_favorite() {
  const auto photos = samplePhotos();

  const auto raw = lutshop::filterPhotos(photos, lutshop::PhotoFilter::Raw, "");
  require(raw.size() == 1 && raw.front().id == "p1", "raw filter returns raw photo");

  const auto favorites =
      lutshop::filterPhotos(photos, lutshop::PhotoFilter::Favorites, "");
  require(favorites.size() == 1 && favorites.front().id == "p2",
          "favorites filter returns favorite photo");

  const auto search = lutshop::filterPhotos(photos, lutshop::PhotoFilter::All, "0125");
  require(search.size() == 1 && search.front().id == "p3",
          "search filters by file name");
}

void test_selection_favorite_rating_lut_and_export_mutations() {
  auto photos = samplePhotos();

  lutshop::togglePhotoSelection(photos, "p1");
  require(photos[0].isSelected, "selection toggles on");

  lutshop::toggleFavorite(photos, "p1");
  require(photos[0].isFavorite, "favorite toggles on");

  lutshop::ratePhotos(photos, {"p1", "p2"}, 3);
  require(photos[0].rating == 3 && photos[1].rating == 3, "rating applies");

  lutshop::applyLutToPhotos(photos, {"p1"}, "mono-soft", 55);
  require(photos[0].appliedLutId == "mono-soft", "lut id applies");
  require(photos[0].lutIntensity == 55, "lut intensity applies");
  require(photos[0].status == lutshop::PhotoStatus::Edited,
          "lut application marks edited");

  lutshop::markPhotosExported(photos, {"p1", "p2"});
  require(photos[0].status == lutshop::PhotoStatus::Exported,
          "export marks first photo");
  require(photos[1].status == lutshop::PhotoStatus::Exported,
          "export marks second photo");
}

std::vector<lutshop::Lut> sampleLuts() {
  return {
      {"portrait-soft", "Portrait Soft", lutshop::LutCategory::Portrait,
       {"portrait", "skin"}, {"#3d241d", "#c8906d", "#f0d2bd"}, false, 12},
      {"alpine-clean", "Alpine Clean", lutshop::LutCategory::Landscape,
       {"landscape", "clean"}, {"#17283a", "#a8c7d8", "#f2f3ef"}, true, 23},
      {"cine-teal", "CineTeal 02", lutshop::LutCategory::Film,
       {"film", "travel"}, {"#2a1209", "#d3a065", "#1b7f8d"}, false, 31}};
}

void test_mock_recommender_uses_analysis_tags() {
  const auto luts = sampleLuts();
  const lutshop::MockLutRecommender recommender(luts);

  lutshop::Photo portrait = samplePhotos()[0];
  portrait.analysisTags = {"portrait", "skin"};
  const auto portraitResults = recommender.recommend(portrait, 2);
  require(!portraitResults.empty(), "portrait recommendation returns results");
  require(portraitResults.front().lutId == "portrait-soft",
          "portrait tag recommends portrait LUT first");
  require(portraitResults.front().confidence >= 80,
          "matching recommendation has high confidence");

  lutshop::Photo fallback = samplePhotos()[2];
  fallback.analysisTags = {"unknown"};
  const auto fallbackResults = recommender.recommend(fallback, 2);
  require(!fallbackResults.empty(), "fallback recommendation returns results");
  require(fallbackResults.front().lutId == "cine-teal",
          "fallback uses popular LUT when tags do not match");
}

}  // namespace

int main() {
  test_photo_model_defaults();
  test_filter_photos_by_search_status_and_favorite();
  test_selection_favorite_rating_lut_and_export_mutations();
  test_mock_recommender_uses_analysis_tags();
  std::cout << "lutshop_core_tests passed\n";
  return 0;
}

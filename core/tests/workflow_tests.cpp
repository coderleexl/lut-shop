#include <cstdlib>
#include <iostream>
#include <string>
#include <vector>

#include "lutshop/bridge_c.h"
#include "lutshop/types.hpp"
#include "lutshop/core.hpp"
#include "lutshop/cube.hpp"
#include "lutshop/import.hpp"
#include "lutshop/lut_catalog.hpp"
#include "lutshop/recommendation.hpp"
#include "lutshop/session.hpp"
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
      "Studio",
      false,
      false,
      0,
      "",
      0.0F,
      lutshop::PhotoStatus::Raw,
      {"portrait"},
      {}};

  require(photo.fileName == "IMG_0123.CR3", "photo file name is stored");
  require(photo.status == lutshop::PhotoStatus::Raw, "photo status is raw");
  require(photo.analysisTags.size() == 1, "analysis tag is stored");
}

std::vector<lutshop::Photo> samplePhotos() {
  return {
      {"p1", "IMG_0123.CR3", "asset://1", "2026-06-08T14:32:00Z", "s1",
       "Studio", false, false, 0, "", 0.0F, lutshop::PhotoStatus::Raw,
       {"portrait"}, {}},
      {"p2", "IMG_0124.CR3", "asset://2", "2026-06-08T14:33:00Z", "s1",
       "Studio", true, false, 4, "cine-teal", 0.68F, lutshop::PhotoStatus::Edited,
       {"landscape"}, {}},
      {"p3", "IMG_0125.CR3", "asset://3", "2026-06-08T14:34:00Z", "s1",
       "Studio", false, true, 5, "gold-200", 0.80F,
       lutshop::PhotoStatus::Exported, {"film"}, {}}};
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

  lutshop::applyLutToPhotos(photos, {"p1"}, "mono-soft", 0.55F);
  require(photos[0].appliedLutId == "mono-soft", "lut id applies");
  require(photos[0].lutIntensity == 0.55F, "lut intensity applies");
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

void test_session_management_creates_renames_assigns_and_deletes_empty_sessions() {
  std::vector<lutshop::Session> sessions;
  auto photos = samplePhotos();

  const auto created = lutshop::createSession(sessions, "s2", "2026-06 Travel");
  require(created.success, "session creation succeeds");
  require(sessions.size() == 1 && sessions.front().name == "2026-06 Travel",
          "session is stored");

  const auto renamed = lutshop::renameSession(sessions, "s2", "2026-06 Client");
  require(renamed.success && sessions.front().name == "2026-06 Client",
          "session renames by id");

  lutshop::assignPhotosToSession(photos, {"p1", "p3"}, "s2", "2026-06 Client");
  require(photos[0].sessionId == "s2" && photos[0].sessionName == "2026-06 Client",
          "assign updates photo session id and name");
  require(lutshop::countPhotosInSession(photos, "s2") == 2,
          "session photo count uses session id");

  const auto deleteNonEmpty = lutshop::deleteEmptySession(sessions, photos, "s2");
  require(!deleteNonEmpty.success, "non-empty session cannot be deleted");

  const auto createdEmpty = lutshop::createSession(sessions, "empty", "Empty");
  require(createdEmpty.success, "empty session creation succeeds");
  const auto deleteEmpty = lutshop::deleteEmptySession(sessions, photos, "empty");
  require(deleteEmpty.success && sessions.size() == 1,
          "empty session can be deleted");
}

void test_import_requests_normalize_photos_for_target_session() {
  lutshop::ImportRequest request;
  request.sessionId = "s-import";
  request.sessionName = "Quick Imports";
  request.items = {
      {"asset://a", "IMG_2001.CR3", "2026-06-12T08:00:00Z"},
      {"file:///tmp/b.jpg", "b.jpg", "2026-06-12T08:01:00Z"}};

  const auto result = lutshop::importPhotos(request);
  require(result.success, "import result succeeds");
  require(result.photos.size() == 2, "import creates two photos");
  require(result.photos[0].id == "import-1", "import assigns stable generated id");
  require(result.photos[0].sessionId == "s-import", "import sets session id");
  require(result.photos[0].sessionName == "Quick Imports", "import sets session name");
  require(result.photos[0].status == lutshop::PhotoStatus::Raw,
          "imported photos start raw");
}

void test_sort_photos_matches_gallery_options() {
  const auto photos = samplePhotos();

  const auto newest = lutshop::sortPhotos(photos, lutshop::PhotoSort::Newest);
  require(newest.front().id == "p3", "newest sort uses importedAt descending");

  const auto rating = lutshop::sortPhotos(photos, lutshop::PhotoSort::Rating);
  require(rating.front().id == "p3", "rating sort puts highest rating first");

  const auto status = lutshop::sortPhotos(photos, lutshop::PhotoSort::Status);
  require(status.front().status == lutshop::PhotoStatus::Raw,
          "status sort keeps raw before edited/exported");
}

void test_lut_catalog_metadata_operations() {
  auto luts = sampleLuts();

  auto imported = lutshop::importLutMetadata(luts, "custom-1", "Sony s709",
                                            lutshop::LutCategory::Custom,
                                            {"sony", "slog3"});
  require(imported.success, "lut metadata import succeeds");
  require(luts.front().id == "custom-1", "imported LUT is inserted first");

  const auto renamed = lutshop::renameLut(luts, "custom-1", "Sony s709 Base");
  require(renamed.success && luts.front().name == "Sony s709 Base",
          "lut rename succeeds");

  const auto favorite = lutshop::toggleLutFavorite(luts, "custom-1");
  require(favorite.success && luts.front().isFavorite,
          "lut favorite toggles");

  const auto deleted = lutshop::deleteLut(luts, "custom-1");
  require(deleted.success && luts.front().id != "custom-1",
          "lut deletion succeeds");
}

void test_core_facade_groups_mobile_facing_operations() {
  lutshop::LutShopCore core;
  auto photos = samplePhotos();
  auto luts = sampleLuts();
  std::vector<lutshop::Session> sessions;

  const auto session = core.createSession(sessions, "mobile", "Mobile Import");
  require(session.success, "facade creates session");

  lutshop::ImportRequest request;
  request.sessionId = "mobile";
  request.sessionName = "Mobile Import";
  request.items = {{"asset://new", "IMG_3001.CR3", "2026-06-12T10:00:00Z"}};
  const auto imported = core.importPhotos(request);
  require(imported.success && imported.photos.size() == 1, "facade imports photos");
  photos.insert(photos.begin(), imported.photos.begin(), imported.photos.end());

  const auto sorted = core.sortPhotos(photos, lutshop::PhotoSort::Newest);
  require(sorted.front().fileName == "IMG_3001.CR3", "facade sorts photos");

  const auto importedLut = core.importLutMetadata(luts, "mobile-lut", "Mobile LUT",
                                                 lutshop::LutCategory::Custom,
                                                 {"portrait"});
  require(importedLut.success && luts.front().id == "mobile-lut",
          "facade imports LUT metadata");

  auto recommendations = core.recommendLuts(photos[1], luts, 1);
  require(recommendations.size() == 1, "facade returns recommendations");
}

void test_cube_parser_reads_title_size_and_entry_count() {
  const std::string cubeText =
      "TITLE \"Sony s709\"\n"
      "LUT_3D_SIZE 2\n"
      "0.0 0.0 0.0\n"
      "0.0 0.0 1.0\n"
      "0.0 1.0 0.0\n"
      "0.0 1.0 1.0\n"
      "1.0 0.0 0.0\n"
      "1.0 0.0 1.0\n"
      "1.0 1.0 0.0\n"
      "1.0 1.0 1.0\n";

  const auto parsed = lutshop::parseCube(cubeText);
  require(parsed.success, "cube parser succeeds");
  require(parsed.cube.title == "Sony s709", "cube parser reads title");
  require(parsed.cube.size == 2, "cube parser reads 3D size");
  require(parsed.cube.entries.size() == 8, "cube parser reads 2^3 entries");
}

void test_c_bridge_exposes_version_and_import_count_for_objcxx_and_jni() {
  require(lutshop_core_version() != nullptr, "c bridge exposes version string");

  const lutshop_import_item items[] = {
      {"asset://1", "IMG_4001.CR3", "2026-06-12T12:00:00Z"},
      {"asset://2", "IMG_4002.CR3", "2026-06-12T12:01:00Z"}};

  const auto count = lutshop_import_photo_count("mobile", "Mobile", items, 2);
  require(count == 2, "c bridge imports and reports photo count");

  const char* cube =
      "TITLE \"Bridge LUT\"\n"
      "LUT_3D_SIZE 2\n"
      "0 0 0\n"
      "0 0 1\n"
      "0 1 0\n"
      "0 1 1\n"
      "1 0 0\n"
      "1 0 1\n"
      "1 1 0\n"
      "1 1 1\n";
  require(lutshop_parse_cube_entry_count(cube) == 8,
          "c bridge parses cube and reports entry count");
}

void test_c_bridge_exposes_cube_metadata_and_preview_pixel_apply() {
  const char* cube =
      "TITLE \"Bridge Metadata LUT\"\n"
      "LUT_3D_SIZE 2\n"
      "0 0 0\n"
      "0 0 1\n"
      "0 1 0\n"
      "0 1 1\n"
      "1 0 0\n"
      "1 0 1\n"
      "1 1 0\n"
      "0.25 0.5 0.75\n";

  const auto metadata = lutshop_parse_cube_metadata(cube, "fallback.cube");
  require(metadata.success == 1, "c bridge metadata parse succeeds");
  require(std::string(metadata.title) == "Bridge Metadata LUT",
          "c bridge metadata includes title");
  require(metadata.size == 2, "c bridge metadata includes cube size");
  require(metadata.entry_count == 8, "c bridge metadata includes entry count");

  const lutshop_rgb input{1.0F, 1.0F, 1.0F};
  const auto output = lutshop_apply_cube_to_rgb(cube, input, 1.0F);
  require(output.r == 0.25F && output.g == 0.5F && output.b == 0.75F,
          "c bridge applies nearest cube color for preview pixel");

  const auto mixed = lutshop_apply_cube_to_rgb(cube, input, 0.5F);
  require(mixed.r == 0.625F && mixed.g == 0.75F && mixed.b == 0.875F,
          "c bridge blends cube color by intensity");
}

}  // namespace

int main() {
  test_photo_model_defaults();
  test_filter_photos_by_search_status_and_favorite();
  test_selection_favorite_rating_lut_and_export_mutations();
  test_mock_recommender_uses_analysis_tags();
  test_session_management_creates_renames_assigns_and_deletes_empty_sessions();
  test_import_requests_normalize_photos_for_target_session();
  test_sort_photos_matches_gallery_options();
  test_lut_catalog_metadata_operations();
  test_core_facade_groups_mobile_facing_operations();
  test_cube_parser_reads_title_size_and_entry_count();
  test_c_bridge_exposes_version_and_import_count_for_objcxx_and_jni();
  test_c_bridge_exposes_cube_metadata_and_preview_pixel_apply();
  std::cout << "lutshop_core_tests passed\n";
  return 0;
}

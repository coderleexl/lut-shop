#pragma once

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct lutshop_import_item {
  const char* uri;
  const char* file_name;
  const char* imported_at;
} lutshop_import_item;

typedef struct lutshop_cube_metadata {
  int success;
  char title[128];
  int size;
  size_t entry_count;
  char message[160];
} lutshop_cube_metadata;

typedef struct lutshop_rgb {
  float r;
  float g;
  float b;
} lutshop_rgb;

const char* lutshop_core_version(void);

size_t lutshop_import_photo_count(const char* session_id,
                                  const char* session_name,
                                  const lutshop_import_item* items,
                                  size_t item_count);

size_t lutshop_parse_cube_entry_count(const char* cube_text);

lutshop_cube_metadata lutshop_parse_cube_metadata(const char* cube_text,
                                                  const char* fallback_title);

lutshop_rgb lutshop_apply_cube_to_rgb(const char* cube_text,
                                      lutshop_rgb input,
                                      float intensity);

#ifdef __cplusplus
}
#endif

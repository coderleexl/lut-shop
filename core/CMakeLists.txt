cmake_minimum_required(VERSION 3.22)
project(lutshop_core LANGUAGES CXX)

add_library(lutshop_core STATIC
  src/bridge_c.cpp
  src/core.cpp
  src/cube.cpp
  src/import.cpp
  src/lut_catalog.cpp
  src/session.cpp
  src/workflow.cpp
  src/recommendation.cpp
)

target_include_directories(lutshop_core
  PUBLIC
    ${CMAKE_CURRENT_SOURCE_DIR}/include
)

target_compile_features(lutshop_core PUBLIC cxx_std_20)

add_executable(lutshop_core_tests
  tests/workflow_tests.cpp
)

target_link_libraries(lutshop_core_tests PRIVATE lutshop_core)

cmake_minimum_required(VERSION 3.22.1)
project(lutshop_android LANGUAGES CXX)

set(CORE_DIR ${CMAKE_CURRENT_SOURCE_DIR}/../../../../../../core)

add_subdirectory(${CORE_DIR} ${CMAKE_CURRENT_BINARY_DIR}/lutshop_core)

add_library(lutshop_jni SHARED lutshop_core_jni.cpp)
target_link_libraries(lutshop_jni PRIVATE lutshop_core log)
target_include_directories(lutshop_jni PRIVATE ${CORE_DIR}/include)

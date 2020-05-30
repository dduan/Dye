cmake_minimum_required(VERSION 3.16.0)

list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/cmake/modules)

project(Dye
  LANGUAGES Swift)

option(BUILD_SHARED_LIBS "Build shared libraries by default" YES)

include(CTest)
include(SwiftSupport)

set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(CMAKE_Swift_MODULE_DIRECTORY ${CMAKE_BINARY_DIR}/swift)

add_subdirectory(cmake/modules)

add_library(Dye
  Sources/Dye.swift)

# NOTE: workaround for CMake not setting up include flags yet
set_target_properties(Dye PROPERTIES
  INTERFACE_INCLUDE_DIRECTORIES ${CMAKE_Swift_MODULE_DIRECTORY})

_install_target(Dye)
set_property(GLOBAL APPEND PROPERTY Dye_EXPORTS Dye)

add_executable(example
  Examples/main.swift)
target_link_libraries(example PRIVATE
  "Dye")
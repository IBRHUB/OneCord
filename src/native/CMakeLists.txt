cmake_minimum_required(VERSION 3.20)
project(onecord_native LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

include(FetchContent)
FetchContent_Declare(
    minhook
    GIT_REPOSITORY https://github.com/TsudaKageyu/minhook.git
    GIT_TAG        v1.3.4
)
FetchContent_MakeAvailable(minhook)

add_library(version SHARED
    src/dllmain.cpp
    src/config.cpp
    src/hooks.cpp
    src/socks5.cpp
    src/exports.cpp
)

target_include_directories(version PRIVATE src ${minhook_SOURCE_DIR}/include)
target_link_libraries(version PRIVATE minhook ws2_32)

set_target_properties(version PROPERTIES
    OUTPUT_NAME "version"
    RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin"
)

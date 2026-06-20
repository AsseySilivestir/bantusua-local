cmake_minimum_required(VERSION 3.16)
project(bantu VERSION 1.2.1 LANGUAGES CXX C)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# ─── Compiler Flags for Maximum Performance + Portability ───
# NOTE: -march=native is intentionally removed — the binary must run on
# older CPUs (Render's free tier uses generic x86-64).
# We target x86-64-v1 (baseline SSE2) which works on every 64-bit Intel/AMD CPU.
if(CMAKE_BUILD_TYPE STREQUAL "Release")
    set(CMAKE_CXX_FLAGS_RELEASE "-O2 -mtune=generic -fno-lto")
    set(CMAKE_EXE_LINKER_FLAGS_RELEASE "")
endif()

# Always-on compatibility flags
add_compile_options(
    -ffile-prefix-map=${CMAKE_SOURCE_DIR}=.
    -fno-plt
)

# ─── v1.2.1 Optional Real Drivers ──────────────────────────
# Enable with `cmake .. -DBANTU_POSTGRES=ON -DBANTU_MYSQL=ON -DBANTU_WEBRTC=ON`
# When OFF (default), the in-process stubs are used (offline-friendly).
option(BANTU_POSTGRES "Link libpq for real PostgreSQL connectivity" OFF)
option(BANTU_MYSQL    "Link mysqlclient for real MySQL connectivity" OFF)
option(BANTU_WEBRTC   "Link libdatachannel for real WebRTC peers" OFF)

if(BANTU_POSTGRES)
    find_path(LIBPQ_INCLUDE_DIR libpq-fe.h)
    find_library(LIBPQ_LIBRARY NAMES pq)
    if(LIBPQ_INCLUDE_DIR AND LIBPQ_LIBRARY)
        add_compile_definitions(HAS_LIBPQ=1)
        include_directories(${LIBPQ_INCLUDE_DIR})
        message(STATUS "Bantu: PostgreSQL (libpq) enabled")
    else()
        message(WARNING "BANTU_POSTGRES=ON but libpq not found; falling back to stub")
    endif()
endif()

if(BANTU_MYSQL)
    find_path(MYSQL_INCLUDE_DIR mysql.h)
    find_library(MYSQL_LIBRARY NAMES mysqlclient mysql)
    if(MYSQL_INCLUDE_DIR AND MYSQL_LIBRARY)
        add_compile_definitions(HAS_MYSQL=1)
        include_directories(${MYSQL_INCLUDE_DIR})
        message(STATUS "Bantu: MySQL (mysqlclient) enabled")
    else()
        message(WARNING "BANTU_MYSQL=ON but mysqlclient not found; falling back to stub")
    endif()
endif()

if(BANTU_WEBRTC)
    find_path(RTC_INCLUDE_DIR rtc/rtc.hpp)
    find_library(RTC_LIBRARY NAMES datachannel rtc)
    if(RTC_INCLUDE_DIR AND RTC_LIBRARY)
        add_compile_definitions(HAS_RTC=1)
        include_directories(${RTC_INCLUDE_DIR})
        message(STATUS "Bantu: WebRTC (libdatachannel) enabled")
    else()
        message(WARNING "BANTU_WEBRTC=ON but libdatachannel not found; falling back to stub")
    endif()
endif()

# ─── Source Files ───
set(SOURCES
    src/main.cpp
    src/lexer.cpp
    src/parser.cpp
    src/evaluator.cpp
    src/ast.cpp
    src/types.cpp
    src/function.cpp
    src/class.cpp
)

# ─── Compatibility Stub ───
# Provides _ZSt21ios_base_library_initv as a no-op so the binary doesn't
# require GLIBCXX_3.4.32 (only available on GCC 14+ runtimes). This lets
# the binary run on Ubuntu 22.04's libstdc++ (GCC 11).
enable_language(C)
add_library(ios_stub STATIC stubs/ios_base_library_initv.c)
set_target_properties(ios_stub PROPERTIES POSITION_INDEPENDENT_CODE ON)


set(HEADERS
    src/types.hpp
    src/lexer.hpp
    src/parser.hpp
    src/evaluator.hpp
    src/ast.hpp
    src/environment.hpp
    src/function.hpp
    src/class.hpp
    src/server.hpp
    src/template.hpp
    src/module_resolver.hpp
)

# ─── Main Executable ───
add_executable(bantu ${SOURCES} ${HEADERS})

target_include_directories(bantu PRIVATE
    ${CMAKE_SOURCE_DIR}/src
    ${CMAKE_SOURCE_DIR}/../../drivers
)

# ─── Threading Support ───
find_package(Threads REQUIRED)
target_link_libraries(bantu PRIVATE Threads::Threads)

# ─── Platform-Specific Settings ───
if(WIN32)
    target_compile_definitions(bantu PRIVATE _WIN32_WINNT=0x0601)
    target_link_libraries(bantu PRIVATE ws2_32)
endif()

if(UNIX AND NOT APPLE)
    set(BANTU_LIBS pthread sqlite3 curl dl ios_stub)
    if(BANTU_POSTGRES AND LIBPQ_LIBRARY)
        list(APPEND BANTU_LIBS ${LIBPQ_LIBRARY})
    endif()
    if(BANTU_MYSQL AND MYSQL_LIBRARY)
        list(APPEND BANTU_LIBS ${MYSQL_LIBRARY})
    endif()
    if(BANTU_WEBRTC AND RTC_LIBRARY)
        list(APPEND BANTU_LIBS ${RTC_LIBRARY})
    endif()
    target_link_libraries(bantu PRIVATE ${BANTU_LIBS})
endif()

# ─── Install ───
install(TARGETS bantu DESTINATION bin)


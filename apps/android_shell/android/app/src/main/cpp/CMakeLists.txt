cmake_minimum_required(VERSION 3.22.1)
project(pokrov_byedpi LANGUAGES C)

# hufrea/byedpi (MIT), main ba532298de7b28cfe854aea83d061369d13ca290.
# The embedded proxy.c patch adds session stop and admission callbacks only.
add_library(pokrov_byedpi SHARED
    android_byedpi.c
    byedpi/main.c
    byedpi/proxy.c
    byedpi/conev.c
    byedpi/desync.c
    byedpi/extend.c
    byedpi/mpool.c
    byedpi/packets.c)
target_include_directories(pokrov_byedpi PRIVATE byedpi)
target_compile_features(pokrov_byedpi PRIVATE c_std_99)
target_compile_definitions(pokrov_byedpi PRIVATE _DEFAULT_SOURCE POKROV_EMBEDDED)
target_compile_options(pokrov_byedpi PRIVATE -fvisibility=hidden -ffunction-sections -fdata-sections)
target_link_options(pokrov_byedpi PRIVATE -Wl,--gc-sections)
set_source_files_properties(byedpi/main.c PROPERTIES COMPILE_DEFINITIONS main=byedpi_cli_main)

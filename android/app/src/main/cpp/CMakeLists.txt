cmake_minimum_required(VERSION 3.21)

set(PACKAGE_VERSION "3.19")
project("oliloiperf")

set(IPERF_SRC_DIR ${CMAKE_SOURCE_DIR}/iperf/iperf-3.19)

configure_file(
        ${CMAKE_SOURCE_DIR}/iperf/iperf_config_android.h
        ${IPERF_SRC_DIR}/iperf_config.h
)

configure_file(
        ${IPERF_SRC_DIR}/version.h.in
        ${IPERF_SRC_DIR}/version.h
        @ONLY
)

set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

add_library(oliloiperf SHARED
        olilo_iperf_jni.c
        ${IPERF_SRC_DIR}/iperf_pthread.c
        ${IPERF_SRC_DIR}/iperf_api.c
        ${IPERF_SRC_DIR}/iperf_client_api.c
        ${IPERF_SRC_DIR}/iperf_util.c
        ${IPERF_SRC_DIR}/iperf_udp.c
        ${IPERF_SRC_DIR}/iperf_tcp.c
        ${IPERF_SRC_DIR}/net.c
        ${IPERF_SRC_DIR}/timer.c
        ${IPERF_SRC_DIR}/units.c
        ${IPERF_SRC_DIR}/iperf_error.c
        ${IPERF_SRC_DIR}/iperf_time.c
        ${IPERF_SRC_DIR}/iperf_locale.c
        ${IPERF_SRC_DIR}/cjson.c
        ${IPERF_SRC_DIR}/tcp_info.c
        ${IPERF_SRC_DIR}/dscp.c
)

target_include_directories(oliloiperf PRIVATE
        ${IPERF_SRC_DIR}
        ${CMAKE_SOURCE_DIR}/iperf
)

target_compile_definitions(oliloiperf PRIVATE HAVE_PTHREAD)

if (ANDROID)
    target_compile_definitions(oliloiperf PRIVATE __ANDROID__)
endif()

find_package(Threads REQUIRED)
target_link_libraries(oliloiperf
        Threads::Threads
        log
        android
)

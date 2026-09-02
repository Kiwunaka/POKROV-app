add_library(pokrov_service_common STATIC
  "service_protocol.cpp"
  "service_security.cpp"
  "windows_crash_profile.cpp"
)
apply_standard_settings(pokrov_service_common)
target_include_directories(pokrov_service_common PUBLIC
  "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(pokrov_service_common PUBLIC
  "advapi32.lib"
  "shell32.lib"
)

add_library(pokrov_service_runtime STATIC
  "service_events.cpp"
  "service_network_state.cpp"
  "service_recovery.cpp"
  "service_runtime.cpp"
)
apply_standard_settings(pokrov_service_runtime)
target_include_directories(pokrov_service_runtime PUBLIC
  "${CMAKE_CURRENT_SOURCE_DIR}")
target_link_libraries(pokrov_service_runtime PUBLIC
  pokrov_service_common
  "ole32.lib"
  "bcrypt.lib"
  "iphlpapi.lib"
  "shell32.lib"
  "winhttp.lib"
  "ws2_32.lib"
)

add_executable(pokrov_service
  "service_main.cpp"
  "service_server.cpp"
)
apply_standard_settings(pokrov_service)
target_link_libraries(pokrov_service PRIVATE
  pokrov_service_common
  pokrov_service_runtime
  "bcrypt.lib"
)

if(BUILD_TESTING)
  add_executable(pokrov_service_protocol_test
    "service_protocol_test.cpp"
  )
  apply_standard_settings(pokrov_service_protocol_test)
  target_link_libraries(pokrov_service_protocol_test PRIVATE
    pokrov_service_common)
  add_test(NAME pokrov_service_protocol
    COMMAND pokrov_service_protocol_test)

  add_executable(pokrov_service_security_test
    "service_security_test.cpp"
  )
  apply_standard_settings(pokrov_service_security_test)
  target_link_libraries(pokrov_service_security_test PRIVATE
    pokrov_service_common)
  add_test(NAME pokrov_service_security
    COMMAND pokrov_service_security_test)

  add_executable(pokrov_windows_crash_profile_test
    "windows_crash_profile_test.cpp"
  )
  apply_standard_settings(pokrov_windows_crash_profile_test)
  target_link_libraries(pokrov_windows_crash_profile_test PRIVATE
    pokrov_service_common)
  add_test(NAME pokrov_windows_crash_profile
    COMMAND pokrov_windows_crash_profile_test)

  add_executable(pokrov_service_runtime_test
    "service_runtime_test.cpp"
  )
  apply_standard_settings(pokrov_service_runtime_test)
  target_link_libraries(pokrov_service_runtime_test PRIVATE
    pokrov_service_runtime)
  add_test(NAME pokrov_service_runtime
    COMMAND pokrov_service_runtime_test)

  add_executable(pokrov_service_events_test
    "service_events_test.cpp"
  )
  apply_standard_settings(pokrov_service_events_test)
  target_link_libraries(pokrov_service_events_test PRIVATE
    pokrov_service_runtime)
  add_test(NAME pokrov_service_events
    COMMAND pokrov_service_events_test)

  add_executable(pokrov_service_integration_test
    "service_integration_test.cpp"
  )
  apply_standard_settings(pokrov_service_integration_test)
  target_link_libraries(pokrov_service_integration_test PRIVATE
    pokrov_service_common)
  add_dependencies(pokrov_service_integration_test pokrov_service)
  add_test(NAME pokrov_service_integration
    COMMAND pokrov_service_integration_test)
  set_tests_properties(pokrov_service_integration PROPERTIES
    CONFIGURATIONS Debug)

  add_executable(pokrov_service_pipe_client_test
    "service_pipe_client.cpp"
    "service_pipe_client_test.cpp"
  )
  apply_standard_settings(pokrov_service_pipe_client_test)
  add_test(NAME pokrov_service_pipe_client
    COMMAND pokrov_service_pipe_client_test)
endif()

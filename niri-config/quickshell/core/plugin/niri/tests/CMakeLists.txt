find_package(Qt6 REQUIRED COMPONENTS Test)

qt_add_executable(niri_plugin_update_tests
    niri_plugin_update_test.cpp
)

target_link_libraries(niri_plugin_update_tests PRIVATE
    ClavisNiri
    ClavisNiriCore
    Qt6::Core
    Qt6::Network
    Qt6::Qml
    Qt6::Test
)

add_test(
    NAME niri_plugin_update_tests
    COMMAND niri_plugin_update_tests
)

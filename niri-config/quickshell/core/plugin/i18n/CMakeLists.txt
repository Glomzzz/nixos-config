qt_add_library(ClavisI18n SHARED)

set_target_properties(ClavisI18n PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/Clavis/I18n
)

qt_add_qml_module(ClavisI18n
    URI Clavis.I18n
    VERSION 1.0
    SOURCES
        src/i18n_manager.h
        src/i18n_manager.cpp
    OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/Clavis/I18n
)

qt_add_translations(ClavisI18n
    TS_FILES
        ${PROJECT_SOURCE_DIR}/../i18n/clavis_en_US.ts
        ${PROJECT_SOURCE_DIR}/../i18n/clavis_zh_CN.ts
        ${PROJECT_SOURCE_DIR}/../i18n/clavis_zh_TW.ts
    RESOURCE_PREFIX "/i18n"
)

target_include_directories(ClavisI18n PUBLIC src)

target_link_libraries(ClavisI18n PRIVATE
    Qt6::Core
    Qt6::Qml
)

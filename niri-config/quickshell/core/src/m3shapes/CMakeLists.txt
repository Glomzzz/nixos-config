add_library(M3ShapesCore STATIC
    core/Point.hpp
    core/Utils.hpp
    core/CornerRounding.hpp
    core/Cubic.hpp
    core/Cubic.cpp
    core/Feature.hpp
    core/Feature.cpp
    core/RoundedPolygon.hpp
    core/RoundedPolygon.cpp
)

add_library(M3ShapesMorph STATIC
    morph/FloatMapping.hpp
    morph/FloatMapping.cpp
    morph/PolygonMeasure.hpp
    morph/PolygonMeasure.cpp
    morph/FeatureMapping.hpp
    morph/FeatureMapping.cpp
    morph/Morph.hpp
    morph/Morph.cpp
)

add_library(M3ShapesGeometry STATIC
    shapes/Shapes.hpp
    shapes/Shapes.cpp
    shapes/MaterialShapes.hpp
    shapes/MaterialShapes.cpp
)

foreach(m3_target IN ITEMS M3ShapesCore M3ShapesMorph M3ShapesGeometry)
    target_compile_features(${m3_target} PUBLIC cxx_std_20)
    set_target_properties(${m3_target} PROPERTIES
        CXX_EXTENSIONS OFF
        POSITION_INDEPENDENT_CODE ON
    )
    target_include_directories(${m3_target} PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}
        ${PROJECT_SOURCE_DIR}/src
    )
endforeach()

target_link_libraries(M3ShapesCore PUBLIC Qt6::Core)
target_link_libraries(M3ShapesMorph PUBLIC M3ShapesCore)
target_link_libraries(M3ShapesGeometry PUBLIC M3ShapesCore)

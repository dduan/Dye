set(Dye_EXPORTS_FILE ${CMAKE_CURRENT_BINARY_DIR}/DyeExports.cmake)

 configure_file(DyeConfig.cmake.in
   ${CMAKE_CURRENT_BINARY_DIR}/DyeConfig.cmake)

 get_property(Dye_EXPORTS GLOBAL PROPERTY Dye_EXPORTS)
 export(TARGETS ${Dye_EXPORTS}
   FILE ${Dye_EXPORTS_FILE})

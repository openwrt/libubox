ADD_SUBDIRECTORY(cram)

MACRO(ADD_UNIT_TEST name)
  ADD_EXECUTABLE(${name} ${name}.c)
  TARGET_LINK_LIBRARIES(${name} ubox blobmsg_json json_script ${json})
  TARGET_INCLUDE_DIRECTORIES(${name} PRIVATE ${PROJECT_SOURCE_DIR})
ENDMACRO(ADD_UNIT_TEST)

FILE(GLOB test_cases "test-*.c")
FOREACH(test_case ${test_cases})
	GET_FILENAME_COMPONENT(test_case ${test_case} NAME_WE)
	ADD_UNIT_TEST(${test_case})
ENDFOREACH(test_case)

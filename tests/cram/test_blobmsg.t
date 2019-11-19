check that blobmsg is producing expected results:

  $ [ -n "$TEST_BIN_DIR" ] && export PATH="$TEST_BIN_DIR:$PATH"
  $ valgrind --quiet --leak-check=full test-blobmsg
  Message: Hello, world!
  List: {
  0
  1
  2
  133.700000
  }
  Testdata: {
  \tdouble : 133.700000 (esc)
  \thello : 1 (esc)
  \tworld : 2 (esc)
  }
  json: {"message":"Hello, world!","testdata":{"double":133.700000,"hello":1,"world":"2"},"list":[0,1,2,133.700000]}

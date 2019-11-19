set test bin path:

  $ [ -n "$TEST_BIN_DIR" ] && export PATH="$TEST_BIN_DIR:$PATH"

check that base64 is producing expected results:

  $ valgrind --quiet --leak-check=full test-b64
  0 
  4 Zg==
  4 Zm8=
  4 Zm9v
  8 Zm9vYg==
  8 Zm9vYmE=
  8 Zm9vYmFy
  0 
  1 f
  2 fo
  3 foo
  4 foob
  5 fooba
  6 foobar

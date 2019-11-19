check that runqueue is producing expected results:

  $ [ -n "$TEST_BIN_DIR" ] && export PATH="$TEST_BIN_DIR:$PATH"
  $ valgrind --quiet --leak-check=full test-runqueue
  [1/1] start 'sleep 1'
  [1/1] cancel 'sleep 1'
  [0/1] finish 'sleep 1'
  [1/1] start 'sleep 1'
  [1/1] cancel 'sleep 1'
  [0/1] finish 'sleep 1'
  [1/1] start 'sleep 1'
  [1/1] cancel 'sleep 1'
  [0/1] finish 'sleep 1'
  All done!

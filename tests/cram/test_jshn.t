set jshn for convenience:

  $ [ -n "$JSHN" ] && export PATH="$(dirname "$JSHN"):$PATH"
  $ alias jshn="valgrind --quiet --leak-check=full jshn"

check usage:

  $ jshn
  Usage: jshn [-n] [-i] -r <message>|-R <file>|-o <file>|-p <prefix>|-w
  [2]

test bad json:

  $ jshn -r '[]'
  Failed to parse message data
  [1]

test good json:

  $ jshn -r '{"foo": "bar", "baz": {"next": "meep"}}'
  json_init;
  json_add_string 'foo' 'bar';
  json_add_object 'baz';
  json_add_string 'next' 'meep';
  json_close_object;

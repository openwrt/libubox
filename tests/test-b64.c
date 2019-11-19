#include <stdio.h>
#include <string.h>

#include "utils.h"

static void test_b64_encode(const char *src)
{
	char dst[255] = {0};
	int r = b64_encode(src, strlen(src), dst, sizeof(dst));
	fprintf(stdout, "%d %s\n", r, dst);
}

static void test_b64_decode(const char *src)
{
	char dst[255] = {0};
	int r = b64_decode(src, dst, sizeof(dst));
	fprintf(stdout, "%d %s\n", r, dst);
}

int main()
{
	test_b64_encode("");
	test_b64_encode("f");
	test_b64_encode("fo");
	test_b64_encode("foo");
	test_b64_encode("foob");
	test_b64_encode("fooba");
	test_b64_encode("foobar");

	test_b64_decode("");
	test_b64_decode("Zg==");
	test_b64_decode("Zm8=");
	test_b64_decode("Zm9v");
	test_b64_decode("Zm9vYg==");
	test_b64_decode("Zm9vYmE=");
	test_b64_decode("Zm9vYmFy");

	return 0;
}

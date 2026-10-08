#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

#include "blobmsg.h"
#include "blobmsg_json.h"

/*
 * Regression test for the type-confusion / out-of-bounds read reported in
 * GHSA-r59q-rcp6-w5j2.
 *
 * A non-extended attribute carries no blobmsg name header, yet when such an
 * attribute appears in a table context blobmsg_format_element() used to call
 * blobmsg_name() on it unconditionally. blobmsg_name() blind-casts the raw
 * payload to struct blobmsg_hdr and returns hdr->name, which is then strlen()d
 * with no guarantee that a NUL terminator exists within the attribute's own
 * bounds.
 *
 * This builds a tightly sized buffer so the crafted attribute's payload ends
 * exactly at the end of the allocation. On an unfixed build the name strlen()
 * reads past that boundary, which an ASAN build detects. The payload bytes are
 * all non-NUL and non-'A'-free so that, even without ASAN, a leaked name would
 * surface as 'A' characters in the JSON output.
 */

static void put_be32(uint8_t *p, uint32_t v)
{
	p[0] = v >> 24;
	p[1] = v >> 16;
	p[2] = v >> 8;
	p[3] = v;
}

int main(void)
{
	/*
	 * Layout, all 4-byte aligned:
	 *   [0]  outer table container: non-extended, id TABLE, raw_len = size
	 *   [4]  crafted child:         non-extended, id TABLE, raw_len = size - 4
	 *   [8]  child payload:         non-NUL bytes up to the allocation end
	 */
	const size_t size = 64;
	uint8_t *buf = malloc(size);
	char *json;

	if (!buf)
		return EXIT_FAILURE;

	put_be32(buf, (BLOBMSG_TYPE_TABLE << BLOB_ATTR_ID_SHIFT) | size);
	put_be32(buf + 4, (BLOBMSG_TYPE_TABLE << BLOB_ATTR_ID_SHIFT) | (size - 4));
	memset(buf + 8, 'A', size - 8);

	json = blobmsg_format_json((struct blob_attr *)buf, true);

	if (json) {
		fprintf(stderr, "result: %s\n", json);
		if (strchr(json, 'A')) {
			fprintf(stderr, "FAIL: leaked payload bytes in output\n");
			free(json);
			free(buf);
			return EXIT_FAILURE;
		}
		free(json);
	}

	free(buf);
	return EXIT_SUCCESS;
}

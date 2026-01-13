#include <string.h>
#include "md5.h"
#include "network.h"

uint32_t network_generate_iface_iaid(const char *ifname) {
	uint8_t hash[16] = {0};
	uint32_t iaid;
	md5_ctx_t md5;

	md5_begin(&md5);
	md5_hash(ifname, strlen(ifname), &md5);
	md5_end(hash, &md5);

	iaid = hash[0] << 24;
	iaid |= hash[1] << 16;
	iaid |= hash[2] << 8;
	iaid |= hash[3];

	return iaid;
}

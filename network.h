#ifndef _LIBUBOX_NETWORK_H
#define _LIBUBOX_NETWORK_H

#include <stdint.h>

/**
 * Generate stable IAID from interface name.
 *
 * @param ifname interface name
 * @return generated IAID
 */
uint32_t network_generate_iface_iaid(const char *ifname);

#endif /* _LIBUBOX_NETWORK_H */

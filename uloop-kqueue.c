/*
 * uloop - event loop implementation
 *
 * Copyright (C) 2010-2016 Felix Fietkau <nbd@openwrt.org>
 *
 * Permission to use, copy, modify, and/or distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */
static int uloop_init_pollfd(void)
{
	struct timespec timeout = { 0, 0 };
	struct kevent ev = {};

	if (poll_fd >= 0)
		return 0;

	poll_fd = kqueue();
	if (poll_fd < 0)
		return -1;

	EV_SET(&ev, SIGCHLD, EVFILT_SIGNAL, EV_ADD, 0, 0, 0);
	kevent(poll_fd, &ev, 1, NULL, 0, &timeout);

	return 0;
}


static uint16_t get_flags(unsigned int flags, unsigned int mask)
{
	uint16_t kflags = 0;

	if (!(flags & mask))
		return EV_DELETE;

	kflags = EV_ADD;
	if (flags & ULOOP_EDGE_TRIGGER)
		kflags |= EV_CLEAR;

	return kflags;
}

static struct kevent events[ULOOP_MAX_EVENTS];

static int register_kevent(struct uloop_fd *fd, unsigned int flags)
{
	struct timespec timeout = { 0, 0 };
	struct kevent ev[2];
	int nev = 0;
	unsigned int fl = 0;
	unsigned int changed;
	uint16_t kflags;

	if (flags & ULOOP_EDGE_DEFER)
		flags &= ~ULOOP_EDGE_TRIGGER;

	changed = flags ^ fd->flags;
	if (changed & ULOOP_EDGE_TRIGGER)
		changed |= flags;

	if (!changed)
		return 0;

	if (changed & ULOOP_READ) {
		kflags = get_flags(flags, ULOOP_READ);
		EV_SET(&ev[nev++], fd->fd, EVFILT_READ, kflags, 0, 0, fd);
	}

	if (changed & ULOOP_WRITE) {
		kflags = get_flags(flags, ULOOP_WRITE);
		EV_SET(&ev[nev++], fd->fd, EVFILT_WRITE, kflags, 0, 0, fd);
	}

	if (!flags)
		fl |= EV_DELETE;

	if (kevent(poll_fd, ev, nev, NULL, fl, &timeout) == -1)
		return -1;

	return 0;
}

static int register_poll(struct uloop_fd *fd, unsigned int flags)
{
	if (flags & ULOOP_EDGE_TRIGGER)
		flags |= ULOOP_EDGE_DEFER;
	else
		flags &= ~ULOOP_EDGE_DEFER;

	return register_kevent(fd, flags);
}

static int __uloop_fd_delete(struct uloop_fd *fd)
{
	return register_poll(fd, 0);
}

static int64_t get_timestamp_us(void)
{
#ifdef CLOCK_MONOTONIC
	struct timespec ts = { 0, 0 };

	clock_gettime(CLOCK_MONOTONIC, &ts);

	return ts.tv_sec * 1000000 + ts.tv_nsec / 1000;
#else
	struct timeval tv = { 0, 0 };

	gettimeofday(&tv, NULL);

	return tv.tv_sec * 1000000 + tv.tv_usec;
#endif
}

static int uloop_fetch_events(int timeout)
{
	struct timespec ts;
	int nfds, n;

	if (timeout >= 0) {
		ts.tv_sec = timeout / 1000;
		ts.tv_nsec = (timeout % 1000) * 1000000;
	}

	nfds = kevent(poll_fd, NULL, 0, events, ARRAY_SIZE(events), timeout >= 0 ? &ts : NULL);
	for (n = 0; n < nfds; n++) {
		if (events[n].filter == EVFILT_TIMER) {
			struct uloop_interval *tm = events[n].udata;

			tm->private.time.fired = get_timestamp_us();
			tm->expirations += events[n].data;
			tm->cb(tm);

			continue;
		}

		struct uloop_fd_event *cur = &cur_fds[n];
		struct uloop_fd *u = events[n].udata;
		unsigned int ev = 0;

		cur->fd = u;
		if (!u)
			continue;

		if (events[n].flags & EV_ERROR) {
			u->error = true;
			if (!(u->flags & ULOOP_ERROR_CB))
				uloop_fd_delete(u);
		}

		if(events[n].filter == EVFILT_READ)
			ev |= ULOOP_READ;
		else if (events[n].filter == EVFILT_WRITE)
			ev |= ULOOP_WRITE;

		if (events[n].flags & EV_EOF)
			u->eof = true;
		else if (!ev)
			cur->fd = NULL;

		cur->events = ev;
		if (u->flags & ULOOP_EDGE_DEFER) {
			u->flags &= ~ULOOP_EDGE_DEFER;
			u->flags |= ULOOP_EDGE_TRIGGER;
			register_kevent(u, u->flags);
		}
	}
	return nfds;
}

static int timer_register(struct uloop_interval *tm, unsigned int msecs)
{
	struct kevent ev;

	tm->private.time.msecs = msecs;
	tm->private.time.fired = get_timestamp_us();

	EV_SET(&ev, (uintptr_t)tm, EVFILT_TIMER, EV_ADD, NOTE_USECONDS, msecs * 1000, tm);

	return kevent(poll_fd, &ev, 1, NULL, 0, NULL);
}

static int timer_remove(struct uloop_interval *tm)
{
	struct kevent ev;

	EV_SET(&ev, (uintptr_t)tm, EVFILT_TIMER, EV_DELETE, 0, 0, NULL);

	return kevent(poll_fd, &ev, 1, NULL, 0, NULL);
}

static int64_t timer_next(struct uloop_interval *tm)
{
	int64_t t1 = tm->private.time.fired;
	int64_t t2 = get_timestamp_us();

	while (t1 < t2)
		t1 += tm->private.time.msecs * 1000;

	return (t1 - t2) / 1000;
}

#include <sys/epoll.h>

#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#define get_fd(self) PerlIO_fileno(IoOFP(sv_2io(SvRV(self))));

static void get_sys_error(char* buffer, size_t buffer_size) {
#ifdef _GNU_SOURCE
	const char* message = strerror_r(errno, buffer, buffer_size);
	if (message != buffer) {
		memcpy(buffer, message, buffer_size -1);
		buffer[buffer_size] = '\0';
	}
#else
	strerror_r(errno, buffer, buffer_size);
#endif
}

static void S_die_sys(pTHX_ const char* format) {
	char buffer[128];
	get_sys_error(buffer, sizeof buffer);
	Perl_croak(aTHX_ format, buffer);
}
#define die_sys(format) S_die_sys(aTHX_ format)

const sigset_t* sv_to_sigset(pTHX_ SV* sigmask) {
	const char* string = SvPV_nolen(sigmask);
	return (const sigset_t*) string;
}

typedef struct { const char* key; uint32_t value; } map[];

static map events = {
	{ "in"     , EPOLLIN      },
	{ "out"    , EPOLLOUT     },
	{ "err"    , EPOLLERR     },
	{ "prio"   , EPOLLPRI     },
	{ "et"     , EPOLLET      },
	{ "hup"    , EPOLLHUP     },
#ifdef EPOLLRDHUP
	{ "rdhup"  , EPOLLRDHUP   },
#endif
	{ "oneshot", EPOLLONESHOT }
};

static uint32_t S_get_eventid(pTHX_ const char* event_name) {
	size_t i;
	for (i = 0; i < sizeof events / sizeof *events; ++i) {
		if (strEQ(event_name, events[i].key))
			return events[i].value;
	}
	Perl_croak(aTHX_ "No such event type '%s' known", event_name);
}
#define get_eventid(name) S_get_eventid(aTHX_ name)

static const char* S_get_event_name(pTHX_ uint32_t event_bit) {
	size_t i;
	for (i = 0; i < sizeof events / sizeof *events; ++i)
		if (events[i].value == event_bit)
			return events[i].key;
	Perl_croak(aTHX_ "No such event type '%d' known", event_bit);
}
#define get_event_name(event_bit) S_get_event_name(aTHX_ event_bit)

static SV* S_get_event_names(pTHX_ uint32_t events) {
	if (__builtin_popcount(events))
		return newSVpv(get_event_name(events), 0);
	else {
		return &PL_sv_undef; /* Not yet implemented */
	}
}
#define get_event_names(event_bits) S_get_event_names(aTHX_ event_bits)

CV* S_extract_cv(pTHX_ SV* sv) {
	HV* stash;
	GV* gv;
	CV* ret = sv_2cv(sv, &stash, &gv, FALSE);
	if (!ret)
		Perl_croak(aTHX_ "Couldn't convert callback parameter to a CV");
}
#define extract_cv(sv) S_extract_cv(aTHX_ sv)

#define undef &PL_sv_undef

MODULE = Linux::Epoll				PACKAGE = Linux::Epoll

int
_create()
	CODE:
#ifdef EPOLL_CLOEXEC
		RETVAL = epoll_create1(EPOLL_CLOEXEC);
#else
		RETVAL = epoll_create(0);
#endif
	OUTPUT:
		RETVAL

void
add(self, fh, events, callback)
	SV* self;
	SV* fh;
	SV* events;
	SV* callback;
	PREINIT:
		int efd, ofd;
		struct epoll_event event;
		CV* real_callback;
	CODE:
		efd = get_fd(self);
		ofd = get_fd(fh);
		event.events = get_events(events);
		event.data.ptr = extract_cv(callback);
		if (epoll_ctl(efd, EPOLL_CTL_ADD, ofd, &event) == -1) 
			die_sys("Couldn't add filehandle from epoll set: %s");

void
modify(self, fh, events, callback)
	SV* self;
	SV* fh;
	SV* events;
	SV* callback;
	PREINIT:
		int efd, ofd;
		struct epoll_event event;
	CODE:
		efd = get_fd(self);
		ofd = get_fd(fh);
		event.events = get_events(events);
		event.data.ptr = extract_cv(callback);
		if (epoll_ctl(efd, EPOLL_CTL_MOD, ofd, &event) == -1) 
			die_sys("Couldn't modify filehandle from epoll set: %s");

void
delete(self, fh)
	SV* self;
	SV* fh;
	PREINIT:
		int efd, ofd;
	CODE:
		efd = get_fd(self);
		ofd = get_fd(fh);
		if (epoll_ctl(efd, EPOLL_CTL_DEL, ofd, NULL) == -1) 
			die_sys("Couldn't delete filehandle from epoll set: %s");

int
wait(self, maxevents, timeout = undef, sigset = undef)
	SV* self;
	size_t maxevents;
	SV* timeout;
	SV* sigset;
	PREINIT:
		int efd, i;
		int real_timeout;
		const sigset_t* real_sigset;
		struct epoll_event* events;
	CODE:
		efd = get_fd(self);
		real_timeout = SvOK(timeout) ? SvNV(timeout) * 1000 : -1;
		real_sigset = SvOK(sigset) ? sv_to_sigset(aTHX_ sigset) : NULL;

		events = alloca(sizeof(struct epoll_event) * maxevents);
		do {
			RETVAL = epoll_pwait(efd, events, maxevents, real_timeout, real_sigset);
		} while (RETVAL == -1 && errno == EINTR);
		if (RETVAL == -1)
			die_sys("Couldn't wait on epollfd: %s");
		for (i = 0; i < RETVAL; i++) {
			CV* callback = (CV*) events[i].data.ptr;
			PUSHMARK(SP);
			PUSHs(get_event_names(events[i].events));
			PUTBACK;
			call_sv((SV*)callback, G_VOID | G_DISCARD);
		}
	OUTPUT:
		RETVAL

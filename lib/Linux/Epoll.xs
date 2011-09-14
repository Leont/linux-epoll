#ifndef _GNU_SOURCE
#	define _GNU_SOURCE
#endif
#define GNU_STRERROR_R

#include <string.h>

#include <sys/epoll.h>

#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#define get_fd(self) PerlIO_fileno(IoIFP(sv_2io(SvRV(self))));

static void get_sys_error(char* buffer, size_t buffer_size) {
#if _POSIX_VERSION >= 200112L
	const char* message = strerror_r(errno, buffer, buffer_size);
	if (message != buffer)
		memcpy(buffer, message, buffer_size);
#else
	const char* message = strerror(errno);
	strncpy(buffer, message, buffer_size - 1);
	buffer[buffer_size - 1] = '\0';
#endif
}

static void S_die_sys(pTHX_ const char* format) {
	char buffer[128];
	get_sys_error(buffer, sizeof buffer);
	Perl_croak(aTHX_ format, buffer);
}
#define die_sys(format) S_die_sys(aTHX_ format)

sigset_t* S_sv_to_sigset(pTHX_ SV* sigmask, const char* name) {
	if (!SvOK(sigmask))
		return NULL;
	if (!SvROK(sigmask) || !sv_derived_from(sigmask, "POSIX::SigSet"))
		Perl_croak(aTHX_ "%s is not of type POSIX::SigSet");
#if PERL_VERSION > 15 || PERL_VERSION == 15 && PERL_SUBVERSION > 2
	return (sigset_t *) SvPV_nolen(SvRV(sigmask));
#else
	IV tmp = SvIV((SV*)SvRV(sigmask));
	return INT2PTR(sigset_t*, tmp);
#endif
}
#define sv_to_sigset(sigmask, name) S_sv_to_sigset(aTHX_ sigmask, name)

typedef struct { const char* key; size_t keylen; uint32_t value; } entry;
typedef entry map[];

static map events = {
	{ "in"     , 2, EPOLLIN      },
	{ "out"    , 3, EPOLLOUT     },
	{ "err"    , 3, EPOLLERR     },
	{ "prio"   , 4, EPOLLPRI     },
	{ "et"     , 2, EPOLLET      },
	{ "hup"    , 3, EPOLLHUP     },
#ifdef EPOLLRDHUP
	{ "rdhup"  , 5, EPOLLRDHUP   },
#endif
	{ "oneshot", 7, EPOLLONESHOT }
};

static uint32_t S_get_eventid(pTHX_ SV* event) {
	STRLEN len;
	const char* event_name = SvPV(event, len);
	size_t i;
	for (i = 0; i < sizeof events / sizeof *events; ++i) {
		if (events[i].keylen == len && strEQ(events[i].key, event_name))
			return events[i].value;
	}
	Perl_croak(aTHX_ "No such event type '%s' known", event_name);
}
#define get_eventid(name) S_get_eventid(aTHX_ name)

static uint32_t S_event_names_to_bits(pTHX_ SV* names) {
	if (SvROK(names)) {
		AV* array = (AV*)SvRV(names);
		uint32_t ret = 0;
		int i, len;
		if (!SvTYPE(array) == SVt_PVAV)
			Perl_croak(aTHX_ "event names must be string or arrayref");
		len = av_len(array) + 1;
		for (i = 0; i < len; ++i) {
			SV** elem = av_fetch(array, i, FALSE);
			ret |= get_eventid(*elem);
		}
		return ret;
	}
	else 
		return get_eventid(names);
}
#define event_names_to_bits(name) S_event_names_to_bits(aTHX_ name)

static entry* S_get_event_name(pTHX_ uint32_t event_bit) {
	size_t i;
	for (i = 0; i < sizeof events / sizeof *events; ++i)
		if (events[i].value == event_bit)
			return &events[i];
	Perl_croak(aTHX_ "No such event type '%d' known", event_bit);
}
#define get_event_name(event_bit) S_get_event_name(aTHX_ event_bit)

static CV* S_extract_cv(pTHX_ SV* sv) {
	HV* stash;
	GV* gv;
	CV* ret = sv_2cv(sv, &stash, &gv, FALSE);
	if (!ret)
		Perl_croak(aTHX_ "Couldn't convert callback parameter to a CV");
	return ret;
}
#define extract_cv(sv) S_extract_cv(aTHX_ sv)

static MAGIC* S_mg_find_ext(pTHX_ SV* sv, U16 private) {
	PERL_UNUSED_CONTEXT;
	if (sv && SvMAGICAL(sv)) {
		MAGIC* mg;
		for (mg = SvMAGIC(sv); mg; mg = mg->mg_moremagic)
			if (mg->mg_type == PERL_MAGIC_ext && mg->mg_private == private)
				return mg;
	}
	return NULL;
}
#define mg_find_ext(sv, private) S_mg_find_ext(aTHX_ sv, private)

static const U16 magic_number = 0x4c45;

struct data {
	AV* backrefs;
	int index;
};

int weak_set(pTHX_ SV* sv, MAGIC* magic) {
	struct data* data = (struct data*)magic->mg_ptr;
	av_delete(data->backrefs, data->index, G_DISCARD);
	return 0;
}

MGVTBL weak_magic = { NULL, weak_set, NULL, NULL, NULL };

static void S_set_backref(pTHX_ SV* epoll, SV* fh, CV* callback) {
	MAGIC* mg = mg_find_ext(SvRV(epoll), magic_number);
	AV* backrefs = (AV*)mg->mg_obj;
	int fd = get_fd(fh);
	struct data backref = { backrefs, fd };
	SV* ref = newSVsv(fh);
	sv_rvweaken(ref);

	av_store(backrefs, fd, ref);
	sv_magicext(ref, (SV*)callback, PERL_MAGIC_ext, &weak_magic, (const char*)&backref, sizeof backref);
}
#define set_backref(epoll, fh, cb) S_set_backref(aTHX_ epoll, fh, cb)

static void S_del_backref(pTHX_ SV* epoll, SV* fh) {
	MAGIC* mg = mg_find_ext(SvRV(epoll), magic_number);
	I32 fd = get_fd(fh);
	av_delete((AV*)mg->mg_obj, fd, G_DISCARD);
}
#define del_backref(epoll, fh) S_del_backref(aTHX_ epoll, fh)

#define undef &PL_sv_undef

static SV* S_io_fdopen(pTHX_ int fd) {
	PerlIO* pio = PerlIO_fdopen(fd, "r");
	GV* gv = newGVgen("Symbol");
	SV* ret = newRV_noinc((SV*)gv);
	IO* io = GvIOn(gv);
	IoTYPE(io) = '<';
	IoIFP(io) = pio;
	IoOFP(io) = pio;
	return ret;
}
#define io_fdopen(fd) S_io_fdopen(aTHX_ fd)

static int S_interrupted(pTHX_ int retval) {
	int ret = retval == -1 && errno == EINTR;
	if (ret)
		PERL_ASYNC_CHECK();
	return ret;
}
#define interrupted(retval) S_interrupted(aTHX_ retval)

MODULE = Linux::Epoll				PACKAGE = Linux::Epoll

SV*
new(const char* package)
	PREINIT:
		int fd;
		MAGIC* mg;
	CODE: 
#ifdef EPOLL_CLOEXEC
		fd = epoll_create1(EPOLL_CLOEXEC);
#else
		fd = epoll_create(0);
#endif
		if (fd < 0) 
			die_sys("Couldn't open epollfd: %s");
		RETVAL = io_fdopen(fd);
		mg = sv_magicext(SvRV(RETVAL), sv_2mortal((SV*)newAV()), PERL_MAGIC_ext, NULL, NULL, 0);
		mg->mg_private = magic_number;
		sv_bless(RETVAL, gv_stashpv(package, TRUE));
	OUTPUT:
		RETVAL

const char*
add(self, fh, events, callback)
	SV* self;
	SV* fh;
	SV* events;
	SV* callback;
	PREINIT:
		int efd, ofd;
		struct epoll_event event;
		CV* real_callback;
		MAGIC* mg;
	CODE:
		efd = get_fd(self);
		ofd = get_fd(fh);
		event.events = event_names_to_bits(events);
		real_callback = extract_cv(callback);
		event.data.ptr = real_callback;
		if (epoll_ctl(efd, EPOLL_CTL_ADD, ofd, &event) == -1) {
			if (GIMME_V != G_VOID && errno == EEXIST)
				XSRETURN_EMPTY;
			else
				die_sys("Couldn't add filehandle from epoll set: %s");
		}
		set_backref(self, fh, real_callback);
		RETVAL = "0 but true";
	OUTPUT:
		RETVAL

const char*
modify(self, fh, events, callback)
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
		event.events = event_names_to_bits(events);
		real_callback = extract_cv(callback);
		event.data.ptr = real_callback;
		if (epoll_ctl(efd, EPOLL_CTL_MOD, ofd, &event) == -1) {
			if (GIMME_V != G_VOID && errno == ENOENT)
				XSRETURN_EMPTY;
			else
				die_sys("Couldn't modify filehandle from epoll set: %s");
		}
		set_backref(self, fh, real_callback);
		RETVAL = "0 but true";
	OUTPUT:
		RETVAL

const char*
delete(self, fh)
	SV* self;
	SV* fh;
	PREINIT:
		int efd, ofd;
	CODE:
		efd = get_fd(self);
		ofd = get_fd(fh);
		if (epoll_ctl(efd, EPOLL_CTL_DEL, ofd, NULL) == -1) {
			if (GIMME_V != G_VOID && errno == ENOENT)
				XSRETURN_EMPTY;
			else
				die_sys("Couldn't delete filehandle from epoll set: %s");
		}
		del_backref(self, fh);
		RETVAL = "0 but true";
	OUTPUT:
		RETVAL

int
wait(self, maxevents = 1, timeout = undef, sigset = undef)
	SV* self;
	ssize_t maxevents;
	SV* timeout;
	SV* sigset;
	PREINIT:
		int efd, i;
		int real_timeout;
		const sigset_t* real_sigset;
		struct epoll_event* events;
	CODE:
		if (maxevents <= 0)
			Perl_croak(aTHX_ "Can't wait for a non-positive number of events (maxevents = %d)", maxevents);
		efd = get_fd(self);
		real_timeout = SvOK(timeout) ? SvNV(timeout) * 1000 : -1;
		real_sigset = SvOK(sigset) ? sv_to_sigset(aTHX_ sigset, "epoll_pwait") : NULL;

		events = alloca(sizeof(struct epoll_event) * maxevents);
		do {
			RETVAL = epoll_pwait(efd, events, maxevents, real_timeout, real_sigset);
		} while (interrupted(RETVAL));
		if (RETVAL == -1)
			die_sys("Couldn't wait on epollfd: %s");
		for (i = 0; i < RETVAL; ++i) {
			CV* callback = (CV*) events[i].data.ptr;
			PUSHMARK(SP);
			mXPUSHu(events[i].events);
			PUTBACK;
			call_sv((SV*)callback, G_VOID | G_DISCARD);
		}
	OUTPUT:
		RETVAL

int
CLONE_SKIP(...)
	CODE:
		RETVAL = 1;
	OUTPUT:
		RETVAL

MODULE = Linux::Epoll				PACKAGE = Linux::Epoll::Util

SV*
event_bits_to_hash(bits)
	UV bits;
	CODE:
		int shift;
		HV* ret = newHV();
		for (shift = 0; shift < 32; ++shift) {
			if (bits & (1 << shift)) {
				entry* tmp = get_event_name(1 << shift);
				hv_store(ret, tmp->key, tmp->keylen, newSViv(1), 0);
			}
		}
		RETVAL = newRV_noinc((SV*)ret);
	OUTPUT:
		RETVAL

SV*
event_bits_to_names(bits)
	UV bits;
	CODE:
		int shift;
		AV* ret = newAV();
		for (shift = 0; shift < 32; ++shift) {
			if (bits & (1 << shift)) {
				entry* tmp = get_event_name(1 << shift);
				SV* val = newSVpvn(tmp->key, tmp->keylen);
				av_push(ret, val);
			}
		}
		RETVAL = newRV_noinc((SV*)ret);
	OUTPUT:
		RETVAL

UV
event_names_to_bits(names)
	SV* names;

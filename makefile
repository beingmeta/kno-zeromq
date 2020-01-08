prefix		::= $(shell knoconfig prefix)
libsuffix	::= $(shell knoconfig libsuffix)
KNO_CFLAGS	::= -I. -fPIC $(shell knoconfig cflags)
KNO_LDFLAGS	::= -fPIC $(shell knoconfig ldflags)
ZMQ_CFLAGS    ::= $(shell etc/pkc --cflags libzmq)
ZMQ_LDFLAGS   ::= $(shell etc/pkc --libs libzmq)
CFLAGS		::= ${CFLAGS} ${ZMQ_CFLAGS} ${KNO_CFLAGS} 
LDFLAGS		::= ${LDFLAGS} ${ZMQ_LDFLAGS} ${KNO_LDFLAGS}
CMODULES	::= $(DESTDIR)$(shell knoconfig cmodules)
LIBS		::= $(shell knoconfig libs)
LIB		::= $(shell knoconfig lib)
INCLUDE		::= $(shell knoconfig include)
KNO_VERSION	::= $(shell knoconfig version)
KNO_MAJOR	::= $(shell knoconfig major)
KNO_MINOR	::= $(shell knoconfig minor)
PKG_RELEASE	::= $(cat ./etc/release)
DPKG_NAME	::= $(shell ./etc/dpkgname)
MKSO		::= $(CC) -shared $(CFLAGS) $(LDFLAGS) $(LIBS)
MSG		::= echo
SYSINSTALL      ::= /usr/bin/install -c
MOD_NAME	::= zeromq
MOD_RELEASE     ::= $(shell cat etc/release)
MOD_VERSION	::= ${KNO_MAJOR}.${KNO_MINOR}.${MOD_RELEASE}

GPGID           ::= FE1BC737F9F323D732AA26330620266BE5AFF294
SUDO            ::= $(shell which sudo)

default: ${MOD_NAME}.${libsuffix}

zeromq.o: zeromq.c makefile
	@$(CC) $(CFLAGS) -o $@ -c $<
	@$(MSG) CC "(ZEROMQ)" $@
zeromq.so: zeromq.o
	$(MKSO) $(LDFLAGS) -o $@ zeromq.o ${LDFLAGS}
	@$(MSG) MKSO  $@ $<
	@ln -sf $(@F) $(@D)/$(@F).${KNO_MAJOR}
zeromq.dylib: zeromq.c makefile
	@$(MACLIBTOOL) -install_name \
		`basename $(@F) .dylib`.${KNO_MAJOR}.dylib \
		${CFLAGS} ${LDFLAGS} -o $@ $(DYLIB_FLAGS) \
		zeromq.c
	@$(MSG) MACLIBTOOL  $@ $<

TAGS: zeromq.c
	etags -o TAGS zeromq.c

install:
	@${SUDO} ${SYSINSTALL} ${MOD_NAME}.${libsuffix} \
			${CMODULES}/${MOD_NAME}.so.${MOD_VERSION}
	@echo === Installed ${CMODULES}/${MOD_NAME}.so.${MOD_VERSION}
	@${SUDO} ln -sf ${MOD_NAME}.so.${MOD_VERSION} \
			${CMODULES}/${MOD_NAME}.so.${KNO_MAJOR}.${KNO_MINOR}
	@echo === Linked ${CMODULES}/${MOD_NAME}.so.${KNO_MAJOR}.${KNO_MINOR} \
		to ${MOD_NAME}.so.${MOD_VERSION}
	@${SUDO} ln -sf ${MOD_NAME}.so.${MOD_VERSION} \
			${CMODULES}/${MOD_NAME}.so.${KNO_MAJOR}
	@echo === Linked ${CMODULES}/${MOD_NAME}.so.${KNO_MAJOR} \
		to ${MOD_NAME}.so.${MOD_VERSION}
	@${SUDO} ln -sf ${MOD_NAME}.so.${MOD_VERSION} ${CMODULES}/${MOD_NAME}.so
	@echo === Linked ${CMODULES}/${MOD_NAME}.so to ${MOD_NAME}.so.${MOD_VERSION}

clean:
	rm -f *.o *.${libsuffix}
fresh:
	make clean
	make default

debian: zeromq.c makefile \
	dist/debian/rules dist/debian/control \
	dist/debian/changelog.base
	rm -rf debian
	cp -r dist/debian debian
	cat debian/changelog.base | etc/gitchangelog kno-zeromq > debian/changelog

debian/changelog: debian zeromq.c makefile
	cat debian/changelog.base | etc/gitchangelog kno-zeromq > $@

debian.built: zeromq.c makefile debian debian/changelog
	dpkg-buildpackage -sa -us -uc -b -rfakeroot && \
	touch $@

debian.signed: debian.built
	debsign --re-sign -k${GPGID} ../kno-zeromq_*.changes && \
	touch $@

debian.updated: debian.signed
	dupload -c ./debian/dupload.conf --nomail --to bionic ../kno-zeromq_*.changes && touch $@

update-apt: debian.updated

debinstall: debian.signed
	${SUDO} dpkg -i ../kno-zeromq*.deb

debclean:
	rm -f ../kno-zeromq_* ../kno-zeromq-* debian/changelog

debfresh:
	make debclean
	make debian.built

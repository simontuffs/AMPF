# Define if you want to place your source in a subdirectory
# SUBDIRS = src

# Define if your sources are in the root
plugin_LTLIBRARIES = libmpf-rdf-dump.la		

libmpf_rdf_dump_la_SOURCES = mpf-rdf-dump.c

EXTRA_DIST =					\
	autogen.sh				\
	mpf-rdf-dump.spec			\
	mpf-rdf-dump.spec.in
	
svnclean:
	make distclean
	rm -rf configure Makefile.in depcomp config.guess \
		ltmain.sh config.sub config.h.in autom4te.cache \
		missing aclocal.m4 install-sh INSTALL \
		$(PACKAGE)-[.0-9]* $(PACKAGE)-[.0-9]*.tar*


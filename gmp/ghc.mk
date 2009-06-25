# -----------------------------------------------------------------------------
#
# (c) 2009 The University of Glasgow
#
# This file is part of the GHC build system.
#
# To understand how the build system works and how to modify it, see
#      http://hackage.haskell.org/trac/ghc/wiki/Building/Architecture
#      http://hackage.haskell.org/trac/ghc/wiki/Building/Modifying
#
# -----------------------------------------------------------------------------

ifneq "$(phase)" "0"

ifeq "$(findstring clean,$(MAKECMDGOALS))" ""
include libraries/integer-gmp/gmp/config.mk
endif

libraries/integer-gmp/cbits/mkGmpDerivedConstants$(exeext): libraries/integer-gmp/cbits/mkGmpDerivedConstants.c
	"$(CC)" $(SRC_CC_OPTS) $(libraries/integer-gmp_CC_OPTS) $< -o $@

libraries/integer-gmp/cbits/GmpDerivedConstants.h: libraries/integer-gmp/cbits/mkGmpDerivedConstants$(exeext)
	$< > $@

# Compile GMP only if we don't have it already
#
# We use GMP's own configuration stuff, because it's all rather hairy
# and not worth re-implementing in our Makefile framework.

ifeq "$(findstring dyn, $(GhcRTSWays))" "dyn"
BUILD_SHARED=yes
else
BUILD_SHARED=no
endif

# In a bindist, we don't want to know whether /this/ machine has gmp,
# but whether the machine the bindist was built on had gmp.
ifeq "$(BINDIST)" "YES"
ifeq "$(wildcard libraries/integer-gmp/gmp/libgmp.a)" ""
HaveLibGmp = YES
HaveFrameworkGMP = YES
else
HaveLibGmp = NO
HaveFrameworkGMP = NO
endif
endif

$(libraries/integer-gmp_dist-install_v_CMM_OBJS): libraries/integer-gmp/cbits/GmpDerivedConstants.h
$(libraries/integer-gmp_dist-install_v_C_OBJS):   libraries/integer-gmp/cbits/GmpDerivedConstants.h

ifneq "$(HaveLibGmp)" "YES"
ifneq "$(HaveFrameworkGMP)" "YES"
libraries/integer-gmp/cbits/mkGmpDerivedConstants$(exeext): libraries/integer-gmp/gmp/gmp.h

libraries/integer-gmp_CC_OPTS += -I$(TOP)/libraries/integer-gmp/gmp

libraries/integer-gmp_dist-install_EXTRA_OBJS += libraries/integer-gmp/gmp/objs/*.o

#INSTALL_LIBS += libraries/integer-gmp/gmp/libgmp.a
#INSTALL_HEADERS += libraries/integer-gmp/gmp/gmp.h
#
#$(eval $(call all-target,gmp_dynamic,libraries/integer-gmp/gmp/libgmp.a))
#
#ifeq "$(BUILD_SHARED)" "yes"
#$(eval $(call all-target,gmp_dynamic,libraries/integer-gmp/gmp/libgmp.dll.a libraries/integer-gmp/gmp/libgmp-3.dll))
#endif

endif
endif

PLATFORM := $(shell echo $(HOSTPLATFORM) | sed 's/i[567]86/i486/g')

# 2007-09-26
#     set -o igncr 
# is not a valid command on non-Cygwin-systems.
# Let it fail silently instead of aborting the build.
#
# 2007-07-05
# We do
#     set -o igncr; export SHELLOPTS
# here as otherwise checking the size of limbs
# makes the build fall over on Cygwin. See the thread
# http://www.cygwin.com/ml/cygwin/2006-12/msg00011.html
# for more details.

# 2007-07-05
# Passing
#     as_ln_s='cp -p'
# isn't sufficient to stop cygwin using symlinks the mingw gcc can't
# follow, as it isn't used consistently. Instead we put an ln.bat in
# path that always fails.

# We use a tarball like gmp-4.2.4-nodoc.tar.bz2, which is
# gmp-4.2.4.tar.bz2 repacked without the doc/ directory contents.
# That's because the doc/ directory contents are under the GFDL,
# which causes problems for Debian.

GMP_TARBALL := $(wildcard libraries/integer-gmp/gmp/tarball/gmp*.tar.bz2)
GMP_DIR := $(patsubst libraries/integer-gmp/gmp/tarball/%-nodoc-patched.tar.bz2,%,$(GMP_TARBALL))

libraries/integer-gmp/gmp/libgmp.a libraries/integer-gmp/gmp/gmp.h:
	$(RM) -rf $(GMP_DIR) libraries/integer-gmp/gmp/gmpbuild libraries/integer-gmp/gmp/objs
	cd libraries/integer-gmp/gmp && $(TAR) -jxf ../../../$(GMP_TARBALL)
	mv libraries/integer-gmp/gmp/$(GMP_DIR) libraries/integer-gmp/gmp/gmpbuild
	chmod +x libraries/integer-gmp/gmp/ln
	cd libraries/integer-gmp/gmp; (set -o igncr 2>/dev/null) && set -o igncr; export SHELLOPTS; \
	    PATH=`pwd`:$$PATH; \
	    export PATH; \
	    cd gmpbuild && \
	    CC=$(WhatGccIsCalled) $(SHELL) configure \
	          --enable-shared=no --host=$(PLATFORM) --build=$(PLATFORM)
	$(MAKE) -C libraries/integer-gmp/gmp/gmpbuild MAKEFLAGS=
	$(CP) libraries/integer-gmp/gmp/gmpbuild/gmp.h libraries/integer-gmp/gmp/
	$(CP) libraries/integer-gmp/gmp/gmpbuild/.libs/libgmp.a libraries/integer-gmp/gmp/
	$(MKDIRHIER) libraries/integer-gmp/gmp/objs
# XXX This should be $(AR), except that has the creation options baked in,
# so we use ar for now instead
	cd libraries/integer-gmp/gmp/objs && ar x ../libgmp.a
	$(RANLIB) libraries/integer-gmp/gmp/libgmp.a

ifneq "$(NO_CLEAN_GMP)" "YES"
$(eval $(call clean-target,gmp,,\
  libraries/integer-gmp/gmp/libgmp.a \
  libraries/integer-gmp/gmp/gmp.h \
  libraries/integer-gmp/gmp/gmpbuild \
  libraries/integer-gmp/gmp/$(GMP_DIR)))
endif

# XXX TODO:
#stamp.gmp.shared:
#	$(RM) -rf $(GMP_DIR) gmpbuild-shared
#	$(TAR) -zxf $(GMP_TARBALL)
#	mv $(GMP_DIR) gmpbuild-shared
#	chmod +x ln
#	(set -o igncr 2>/dev/null) && set -o igncr; export SHELLOPTS; \
#	    PATH=`pwd`:$$PATH; \
#	    export PATH; \
#	    cd gmpbuild-shared && \
#	    CC=$(WhatGccIsCalled) $(SHELL) configure \
#	          --enable-shared=yes --disable-static --host=$(PLATFORM) --build=$(PLATFORM)
#	touch $@
#
#gmp.h: stamp.gmp.static
#	$(CP) gmpbuild/gmp.h .
#
#libgmp.a: stamp.gmp.static
#
#libgmp-3.dll: stamp.gmp.shared
#	$(MAKE) -C gmpbuild-shared MAKEFLAGS=
#	$(CP) gmpbuild-shared/.libs/libgmp-3.dll .
#
#libgmp.dll.a: libgmp-3.dll
#	$(CP) gmpbuild-shared/.libs/libgmp.dll.a .

## GMP takes a long time to build, but changes rarely.  Hence we don't
## bother cleaning it before validating, because that adds a
## significant overhead to validation.
#ifeq "$(Validating)" "NO"
#clean distclean maintainer-clean ::
#	$(RM) -f stamp.gmp.static stamp.gmp.shared
#	$(RM) -rf gmpbuild
#	$(RM) -rf gmpbuild-shared
#endif

endif

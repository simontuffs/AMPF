#!/bin/sh

# Fill these two fields in with the name of your project
# and any existing source file you want
package=mpf-test-eos
srcfile=mpf-test-eos.c

DIE=0

debug ()
# print out a debug message if DEBUG is a defined variable
{
  if test ! -z "$DEBUG"
  then
    echo "DEBUG: $1"
  fi
}

version_check ()
# check the version of a package
# first argument : package name (executable)
# second argument : optional path where to look for it instead
# third argument : source download url
# rest of arguments : major, minor, micro version
# all consecutive ones : suggestions for binaries to use
# (if not specified in second argument)
{
  PACKAGE=$1
  PKG_PATH=$2
  URL=$3
  MAJOR=$4
  MINOR=$5
  MICRO=$6

  # for backwards compatibility, we let PKG_PATH=PACKAGE when PKG_PATH null
  if test -z "$PKG_PATH"; then PKG_PATH=$PACKAGE; fi
  debug "major $MAJOR minor $MINOR micro $MICRO"
  VERSION=$MAJOR
  if test ! -z "$MINOR"; then VERSION=$VERSION.$MINOR; else MINOR=0; fi
  if test ! -z "$MICRO"; then VERSION=$VERSION.$MICRO; else MICRO=0; fi

  debug "major $MAJOR minor $MINOR micro $MICRO"
  
  for SUGGESTION in $PKG_PATH; do 
    COMMAND="$SUGGESTION"

    # don't check if asked not to
    test -z "$NOCHECK" && {
      echo -n "  checking for $COMMAND >= $VERSION ... "
    } || {
      # we set a var with the same name as the package, but stripped of
      # unwanted chars
      VAR=`echo $PACKAGE | sed 's/-//g'`
      debug "setting $VAR"
      eval $VAR="$COMMAND"
      return 0
    }

    debug "checking version with $COMMAND"
    ($COMMAND --version) < /dev/null > /dev/null 2>&1 || 
    {
      echo "not found."
      continue
    }
    # strip everything that's not a digit, then use cut to get the first field
    pkg_version=`$COMMAND --version|head -n 1|sed 's/^.*)[^0-9]*//'|cut -d' ' -f1`
    debug "pkg_version $pkg_version"
    # remove any non-digit characters from the version numbers to permit numeric
    # comparison
    pkg_major=`echo $pkg_version | cut -d. -f1 | sed s/[a-zA-Z\-].*//g`
    pkg_minor=`echo $pkg_version | cut -d. -f2 | sed s/[a-zA-Z\-].*//g`
    pkg_micro=`echo $pkg_version | cut -d. -f3 | sed s/[a-zA-Z\-].*//g`
    test -z "$pkg_major" && pkg_major=0
    test -z "$pkg_minor" && pkg_minor=0
    test -z "$pkg_micro" && pkg_micro=0
    debug "found major $pkg_major minor $pkg_minor micro $pkg_micro"

    #start checking the version
    debug "version check"

    # reset check
    WRONG=

    if [ ! "$pkg_major" -gt "$MAJOR" ]; then
      debug "major: $pkg_major <= $MAJOR"
      if [ "$pkg_major" -lt "$MAJOR" ]; then
        debug "major: $pkg_major < $MAJOR"
        WRONG=1
      elif [ ! "$pkg_minor" -gt "$MINOR" ]; then
        debug "minor: $pkg_minor <= $MINOR"
        if [ "$pkg_minor" -lt "$MINOR" ]; then
          debug "minor: $pkg_minor < $MINOR"
          WRONG=1
        elif [ "$pkg_micro" -lt "$MICRO" ]; then
          debug "micro: $pkg_micro < $MICRO"
	  WRONG=1
        fi
      fi
    fi

    if test ! -z "$WRONG"; then
      echo "found $pkg_version, not ok !"
      continue
    else
      echo "found $pkg_version, ok."
      # we set a var with the same name as the package, but stripped of
      # unwanted chars
      VAR=`echo $PACKAGE | sed 's/-//g'`
      debug "setting $VAR"
      eval $VAR="$COMMAND"
      return 0
    fi
  done

  echo "not found !"
  echo "You must have $PACKAGE installed to compile $package."
  echo "Download the appropriate package for your distribution,"
  echo "or get the source tarball at $URL"
  return 1;
}

aclocal_check ()
{
  # normally aclocal is part of automake
  # so we expect it to be in the same place as automake
  # so if a different automake is supplied, we need to adapt as well
  # so how's about replacing automake with aclocal in the set var,
  # and saving that in $aclocal ?
  # note, this will fail if the actual automake isn't called automake*
  # or if part of the path before it contains it
  if [ -z "$automake" ]; then
    echo "Error: no automake variable set !"
    return 1
  else
    aclocal=`echo $automake | sed s/automake/aclocal/`
    debug "aclocal: $aclocal"
    if [ "$aclocal" != "aclocal" ];
    then
      CONFIGURE_DEF_OPT="$CONFIGURE_DEF_OPT --with-aclocal=$aclocal"
    fi
    if [ ! -x `which $aclocal` ]; then
      echo "Error: cannot execute $aclocal !"
      return 1
    fi
  fi
}

autoheader_check ()
{
  # same here - autoheader is part of autoconf
  # use the same voodoo
  if [ -z "$autoconf" ]; then
    echo "Error: no autoconf variable set !"
    return 1
  else
    autoheader=`echo $autoconf | sed s/autoconf/autoheader/`
    debug "autoheader: $autoheader"
    if [ "$autoheader" != "autoheader" ];
    then
      CONFIGURE_DEF_OPT="$CONFIGURE_DEF_OPT --with-autoheader=$autoheader"
    fi
    if [ ! -x `which $autoheader` ]; then
      echo "Error: cannot execute $autoheader !"
      return 1
    fi
  fi

}
autoconf_2_52d_check ()
{
  # autoconf 2.52d has a weird issue involving a yes:no error
  # so don't allow it's use
  test -z "$NOCHECK" && {
    ac_version=`$autoconf --version|head -n 1|sed 's/^[a-zA-Z\.\ ()]*//;s/ .*$//'`
    if test "$ac_version" = "2.52d"; then
      echo "autoconf 2.52d has an issue with our current build."
      echo "We don't know who's to blame however.  So until we do, get a"
      echo "regular version.  RPM's of a working version are on the gstreamer site."
      exit 1
    fi
  }
  return 0
}

die_check ()
{
  # call with $DIE
  # if set to 1, we need to print something helpful then die
  DIE=$1
  if test "x$DIE" = "x1";
  then
    echo
    echo "- Please get the right tools before proceeding."
    echo "- Alternatively, if you're sure we're wrong, run with --nocheck."
    exit 1
  fi
}

autogen_options ()
{
  if test "x$1" = "x"; then
    return 0
  fi

  while test "x$1" != "x" ; do
    optarg=`expr "x$1" : 'x[^=]*=\(.*\)'`
    case "$1" in
      --noconfigure)
          NOCONFIGURE=defined
	  AUTOGEN_EXT_OPT="$AUTOGEN_EXT_OPT --noconfigure"
          echo "+ configure run disabled"
          shift
          ;;
      --nocheck)
	  AUTOGEN_EXT_OPT="$AUTOGEN_EXT_OPT --nocheck"
          NOCHECK=defined
          echo "+ autotools version check disabled"
          shift
          ;;
      --debug)
          DEBUG=defined
	  AUTOGEN_EXT_OPT="$AUTOGEN_EXT_OPT --debug"
          echo "+ debug output enabled"
          shift
          ;;
      --prefix=*)
	  CONFIGURE_EXT_OPT="$CONFIGURE_EXT_OPT --prefix=$optarg"
	  echo "+ passing --prefix=$optarg to configure"
          shift
          ;;
      --prefix)
	  shift
	  echo "DEBUG: $1"
	  CONFIGURE_EXT_OPT="$CONFIGURE_EXT_OPT --prefix=$1"
	  echo "+ passing --prefix=$1 to configure"
          shift
          ;;

      -h|--help)
          echo "autogen.sh (autogen options) -- (configure options)"
          echo "autogen.sh help options: "
          echo " --noconfigure            don't run the configure script"
          echo " --nocheck                don't do version checks"
          echo " --debug                  debug the autogen process"
	  echo " --prefix		  will be passed on to configure"
          echo
          echo " --with-autoconf PATH     use autoconf in PATH"
          echo " --with-automake PATH     use automake in PATH"
          echo
          echo "to pass options to configure, put them as arguments after -- "
	  exit 1
          ;;
      --with-automake=*)
          AUTOMAKE=$optarg
          echo "+ using alternate automake in $optarg"
	  CONFIGURE_DEF_OPT="$CONFIGURE_DEF_OPT --with-automake=$AUTOMAKE"
          shift
          ;;
      --with-autoconf=*)
          AUTOCONF=$optarg
          echo "+ using alternate autoconf in $optarg"
	  CONFIGURE_DEF_OPT="$CONFIGURE_DEF_OPT --with-autoconf=$AUTOCONF"
          shift
          ;;
      --disable*|--enable*|--with*)
          echo "+ passing option $1 to configure"
	  CONFIGURE_EXT_OPT="$CONFIGURE_EXT_OPT $1"
          shift
          ;;
       --) shift ; break ;;
      *) echo "- ignoring unknown autogen.sh argument $1"; shift ;;
    esac
  done

  for arg do CONFIGURE_EXT_OPT="$CONFIGURE_EXT_OPT $arg"; done
  if test ! -z "$CONFIGURE_EXT_OPT"
  then
    echo "+ options passed to configure: $CONFIGURE_EXT_OPT"
  fi
}

toplevel_check ()
{
  srcfile=$1
  test -f $srcfile || {
        echo "You must run this script in the top-level $package directory"
        exit 1
  }
}


tool_run ()
{
  tool=$1
  options=$2
  run_if_fail=$3
  echo "+ running $tool $options..."
  $tool $options || {
    echo
    echo $tool failed
    eval $run_if_fail
    exit 1
  }
}

CONFIGURE_DEF_OPT='--enable-maintainer-mode --enable-debug'

autogen_options $@

echo -n "+ check for build tools"
if test ! -z "$NOCHECK"; then echo " skipped"; else  echo; fi
version_check "autoconf" "$AUTOCONF autoconf autoconf259 autoconf257 autoconf-2.54 autoconf-2.53 autoconf-2.52" \
              "ftp://ftp.gnu.org/pub/gnu/autoconf/" 2 52 || DIE=1
version_check "automake" "$AUTOMAKE automake automake-1.9 automake19 automake-1.7 automake-1.6 automake-1.5" \
              "ftp://ftp.gnu.org/pub/gnu/automake/" 1 7 || DIE=1
###version_check "autopoint" "autopoint" \
###              "ftp://ftp.gnu.org/pub/gnu/gettext/" 0 11 5 || DIE=1
version_check "libtoolize" "$LIBTOOLIZE libtoolize glibtoolize" \
              "ftp://ftp.gnu.org/pub/gnu/libtool/" 1 5 0 || DIE=1
version_check "pkg-config" "" \
              "http://www.freedesktop.org/software/pkgconfig" 0 8 0 || DIE=1

die_check $DIE

autoconf_2_52d_check || DIE=1
aclocal_check || DIE=1
autoheader_check || DIE=1

die_check $DIE

# if no arguments specified then this will be printed
if test -z "$*"; then
  echo "+ checking for autogen.sh options"
  echo "  This autogen script will automatically run ./configure as:"
  echo "  ./configure $CONFIGURE_DEF_OPT"
  echo "  To pass any additional options, please specify them on the $0"
  echo "  command line."
fi

tool_run "$aclocal" "$ACLOCAL_FLAGS"
tool_run "$libtoolize" "--copy --force"
tool_run "$autoheader"
tool_run "$autoconf"
tool_run "$automake" "-a -c"

# if enable exists, add an -enable option for each of the lines in that file
if test -f enable; then
  for a in `cat enable`; do
    CONFIGURE_FILE_OPT="--enable-$a"
  done
fi

# if disable exists, add an -disable option for each of the lines in that file
if test -f disable; then
  for a in `cat disable`; do
    CONFIGURE_FILE_OPT="$CONFIGURE_FILE_OPT --disable-$a"
  done
fi

test -n "$NOCONFIGURE" && {
  echo "+ skipping configure stage for package $package, as requested."
  echo "+ autogen.sh done."
  exit 0
}

echo "+ running configure ... "
test ! -z "$CONFIGURE_DEF_OPT" && echo "  ./configure default flags: $CONFIGURE_DEF_OPT"
test ! -z "$CONFIGURE_EXT_OPT" && echo "  ./configure external flags: $CONFIGURE_EXT_OPT"
test ! -z "$CONFIGURE_FILE_OPT" && echo "  ./configure enable/disable flags: $CONFIGURE_FILE_OPT"
echo

./configure $CONFIGURE_DEF_OPT $CONFIGURE_EXT_OPT $CONFIGURE_FILE_OPT || {
        echo "  configure failed"
        exit 1
}

echo "Now type 'make' to compile $package."

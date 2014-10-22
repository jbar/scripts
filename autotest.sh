#!/bin/bash

# This script test a source repository using autotools
# It retrieve it, launch ./buildconf or ./autogen.sh, ./configure, make, and make test or check.

version="0.1 10Sep2014"

hlpmsg="
${0##*/} perform compilation and check/test of a source repository using autotools.

 Usage: $0 [options] directory or command to retrieve a source repository (git clone .../svn co .../tar xf .../cp .../...)
 Options:
    -p|--pre COMMANDS   actions to perform just after the retrieving command and before autogen.sh or buildconf.
    -a|--autoconf ARG   arguments for the autoconf.sh/buildconf command.
    -c|--configure ARG  arguments for the ./configure command.
    -m|--make ARG       arguments for the make command.
    -t|--test ARG       arguments for the make test/check command.
    -k|--keep           don't clean the local git repository on exit.
    -h|--help           print this help and exit.
    -V|--version        show version and exit.
    --                  separator to end options ; usefull if the url begin with a dash \"-\".

 Notes:
    If you specified a directory, it will be used it as working directory.
    If you specified a command, ${0##*/} use \$TMPDIR environment variable to create a working directory.
      
    Then aim is to generate a Makefile. Trying autogen.sh (or buildconf if there is no autogen.sh), then configure.
    Once a Makefile exist, try make and make test (or make check if there is no make test). 
"
    #-l|--log DIRECTORY  enable logging of each actions to separate files in a specified repository

while [ "${1::1}" == "-" ] ; do
	case "$1" in 
#		-l|--log)
#           shift
#			logdir="$(readlink -f "$1")"
#			;;
		-p|--pre)
            shift
			preargs="$1"
			;;
		-a|--autoconf)
            shift
			autoargs="$1"
			;;
		-c|--configure)
            shift
			confargs="$1"
			;;
		-m|--make)
            shift
			makeargs="$1"
			;;
		-t|--test)
            shift
			testargs="$1"
			;;
		-k|--keep)
			keep="yes"
			;;
		-h|--help)
			echo "$hlpmsg"
			exit
			;;
		-V|--version)
			echo "$0/$version"
			exit
			;;
		--)
			shift
			break
			;;
		-*)
			echo -e "Warning: Unkown option \"$1\" try: $0 --help\n" >&2
			;;
	esac
	shift
done

if (($# < 1 )) ; then
	echo "$hlpmsg"
	exit 255
fi

if [ -d "$1" ] && (($#==1)) ; then
    function quit {
        #echo $?
        if ! [ "$keep" ] ; then
            echo "${0##*/}: make distclean ... (in $1)" >&2
            make distclean
        fi
    }
    trap quit EXIT

    cd "$1"
    echo "${0##*/}: make distclean ... (in $1)" >&2
    make distclean
else
    function quit {
        #echo $?
        if [ "$keep" ] ; then
            echo -en "\n$tmpdir/ -> "
            ls -m "$tmpdir"
        else
            rm -rf "$tmpdir"
        fi
    }

    tmpdir="$(readlink -f $(mktemp -d --tmpdir ${0##*/}.XXXX))" || exit
    trap quit EXIT

    cd "$tmpdir" 
    echo "${0##*/}: working directory: $tmpdir" >&2
    echo "${0##*/}: retrieving source ... ($@)" >&2
    eval "$@" || exit 250
fi


# If there is only one dir (and no file) in current dir, go in
(( $(find . -maxdepth 1 -type d | wc -l) == 2 && $(find . -maxdepth 1 | wc -l) == 2 )) && pushd "$(find . -maxdepth 1 | tail -1)"

if [ "$preargs" ] ; then
    echo "${0##*/}: launching pre-action ... ($preargs)" >&2
    eval "$preargs" || exit 249
fi

function trymake {
    if [ -f "Makefile" ] ; then
        [ "$1" ] && echo "${0##*/}: $@" >&2
        echo "${0##*/}: make $makeargs ..." >&2
        eval make "$makeargs" || exit 245
        if make -n test > /dev/null ; then
            echo "${0##*/}: make test ..." >&2
            eval make test "$testargs" || exit 244
        else
            echo "${0##*/}: make check ..." >&2
            eval make check "$testargs" || exit 244
        fi
        exit 0
    fi
}   

trymake "Warning: Makefile already present"

[ -f "buildconf" ] && autoconf="buildconf" 
[ -f "autogen.sh" ] && autoconf="autogen.sh" 

if [ "$autoconf" ] ; then
    echo "${0##*/}: launching $autoconf ... (./$autoconf $autoargs)" >&2
    eval "./$autoconf $autoargs" || exit 248
fi

trymake

echo "${0##*/}: launching configure ... (./configure $confargs)" >&2
eval "./configure $confargs" || exit 247

trymake


#! /bin/sh
# Test rl_read_init_file()'s colon-separated, wildcard-aware init file lists
# (what makes a SYS_INPUTRC such as "/sw/*/etc/inputrc:/etc/inputrc" work):
# vendor-then-/etc precedence, a literal filename containing ':', '~'
# expansion, empty leading/trailing list entries, and ":" alone.  Every
# fixture lives under a temporary directory; nothing here reads the host's
# own inputrc files.
#
# Run from the build directory after "make", normally via "make check":
#   CC=... CFLAGS=... LDFLAGS=... TERMCAP_LIB=... srcdir=... $(SHELL) tests/inputrc-glob.sh

: "${CC:=cc}" "${srcdir:=.}"
td="$(mktemp -d)" || exit 99
trap 'rm -rf "$td"' EXIT
fail=0

# Link against the library this tree just built: libreadline.a if static
# libraries were built, otherwise shlib/libreadline.so.X.Y through a private
# directory holding the libreadline.so and soname links the build tree lacks.
if test -f ./libreadline.a
then
    rllib=./libreadline.a
else
    real=
    for f in shlib/libreadline.so.*
    do
        test -f "$f" && test ! -h "$f" && real="$f"
    done
    if test -z "$real"
    then
        echo "FAIL: no libreadline.a or shlib/libreadline.so.* (run make first)"
        exit 1
    fi
    mkdir "$td/lib" || exit 99
    n="${real##*/}"
    ln -s "$(cd "${real%/*}" && pwd)/$n" "$td/lib/$n" || exit 99
    while case "$n" in *.so.*) true ;; *) false ;; esac
    do
        ln -s "$n" "$td/lib/${n%.*}" || exit 99
        n="${n%.*}"
    done
    rllib="-L$td/lib -Wl,-rpath,$td/lib -lreadline"
fi

prog="$td/inputrc-glob"
if ! $CC $CFLAGS -DREADLINE_LIBRARY -I. -I"$srcdir" $LDFLAGS \
    -o "$prog" "$srcdir/tests/inputrc-glob.c" $rllib $TERMCAP_LIB
then
    echo "FAIL: cannot build $prog"
    exit 1
fi

mkdir -p "$td/sw/pkgA/etc" "$td/sw/pkgB/etc" "$td/etc" "$td/home" || exit 99
printf 'set bell-style none\nset editing-mode emacs\n' > "$td/sw/pkgA/etc/inputrc"
printf 'set completion-ignore-case on\n' > "$td/sw/pkgB/etc/inputrc"
printf 'set bell-style audible\nset editing-mode vi\n' > "$td/my:inputrc"
printf 'set bell-style visible\n' > "$td/home/.inputrc"

# expect EXPECTED FILENAME DESCRIPTION
expect() {
    got="$(TERM=dumb HOME="$td/home" INPUTRC=/dev/null "$prog" "$2" < /dev/null 2> "$td/stderr")"
    if test "$got" = "$1"
    then
        echo "PASS: $3"
    else
        echo "FAIL: $3: rl_read_init_file(\"$2\"): expected '$1', got '$got'"
        sed 's/^/  stderr: /' "$td/stderr"
        fail=1
    fi
}

expect 'none|emacs|on' "$td/sw/*/etc/inputrc:$td/etc/inputrc" \
    'wildcard vendor files are all read; a missing /etc entry is harmless'
expect 'none|emacs|on' ":$td/sw/*/etc/inputrc:" \
    'empty leading and trailing entries are ignored'
expect 'audible|vi|off' "$td/my:inputrc" \
    'an existing file whose name contains a colon is read literally'
expect 'visible|emacs|on' "$td/sw/*/etc/inputrc:~/.inputrc" \
    '~ is expanded in a list entry, and later entries win'
expect 'none|emacs|on' "~/.inputrc:$td/sw/*/etc/inputrc" \
    'entries are read in list order'
expect 'ERR:2' ':' \
    'a list with only empty entries fails with ENOENT'

printf 'set bell-style visible\n' > "$td/etc/inputrc"
expect 'visible|emacs|on' "$td/sw/*/etc/inputrc:$td/etc/inputrc" \
    '/etc entry after the vendor wildcard overrides vendor settings'

exit $fail

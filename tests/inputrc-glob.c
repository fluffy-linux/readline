/* inputrc-glob.c -- read one init file list with rl_read_init_file() and
   print the variables the inputrc-glob.sh fixtures set.

   Usage: inputrc-glob FILENAME
   Prints "bell-style|editing-mode|completion-ignore-case" on success, or
   "ERR:<errno>" and exits 1 if rl_read_init_file() fails. */

#include <stdio.h>
#include <string.h>

#include "readline.h"

static const char *
var (const char *name)
{
  const char *v = rl_variable_value (name);
  return v ? v : "";
}

int
main (int argc, char **argv)
{
  int r;

  if (argc != 2)
    {
      fprintf (stderr, "usage: %s FILENAME\n", argv[0]);
      return 2;
    }

  rl_initialize ();
  r = rl_read_init_file (argv[1]);
  if (r != 0)
    {
      printf ("ERR:%d\n", r);
      return 1;
    }
  printf ("%s|%s|%s\n", var ("bell-style"), var ("editing-mode"),
	  var ("completion-ignore-case"));
  return 0;
}

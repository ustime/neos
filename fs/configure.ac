AC_PREREQ([2.69])
AC_INIT([YFS], [1.2], [51318027@qq.com])
AM_INIT_AUTOMAKE([foreign])
AC_CONFIG_SRCDIR([yfs/yfs.c])
AC_CONFIG_HEADERS([config.h])

AC_PROG_CC_C99

AC_CHECK_HEADERS([stdlib.h string.h strings.h])

AC_TYPE_SIZE_T

AC_FUNC_MALLOC
AC_CHECK_FUNCS([memset strcasecmp])

AC_CONFIG_FILES([Makefile
                 yfs/Makefile])
AC_OUTPUT

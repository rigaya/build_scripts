#ifndef _UTIL_H_
#define _UTIL_H_ 1

#include <windows.h>
#define EXIST(s) (GetFileAttributes(s) != 0xFFFFFFFF)

static __inline int64_t muldiv(int64_t val, int m, int d)
{
	int64_t w;

	w = val;
	w *= m;
	w += (d>>1);
	w /= d;

	return w;
}


#endif // _UTIL_H_

#! /bin/sh

# TTF to font.h generator

if [ "$#" -ne 1 ]; then
	echo "Usage: $0 SOME_FONT.ttf"
	exit 1
fi

otf2bdf -p 22 -r 75 -v $1 -o font.bdf
bdftobogl font.bdf > font.h
rm font.bdf
sed -i 's/#include "bogl\.h"/#include "psplash\.h"/g' font.h
sed -i 's/struct bogl_font font_font/PSplashFont font/g' font.h

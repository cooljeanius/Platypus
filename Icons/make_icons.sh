#!/bin/bash

if test ! -d PlatypusAppIcon.iconset; then
  mkdir PlatypusAppIcon.iconset
fi
sips -z 16 16     PlatypusAppIcon1024.png --out PlatypusAppIcon.iconset/icon_16x16.png
sips -z 32 32     PlatypusAppIcon1024.png --out PlatypusAppIcon.iconset/icon_16x16@2x.png
sips -z 32 32     PlatypusAppIcon1024.png --out PlatypusAppIcon.iconset/icon_32x32.png
sips -z 64 64     PlatypusAppIcon1024.png --out PlatypusAppIcon.iconset/icon_32x32@2x.png
sips -z 128 128   PlatypusAppIcon1024.png --out PlatypusAppIcon.iconset/icon_128x128.png
sips -z 256 256   PlatypusAppIcon1024.png --out PlatypusAppIcon.iconset/icon_128x128@2x.png
sips -z 256 256   PlatypusAppIcon1024.png --out PlatypusAppIcon.iconset/icon_256x256.png
sips -z 512 512   PlatypusAppIcon1024.png --out PlatypusAppIcon.iconset/icon_256x256@2x.png
sips -z 512 512   PlatypusAppIcon1024.png --out PlatypusAppIcon.iconset/icon_512x512.png
if test -e PlatypusAppIcon1024.png; then
  cp PlatypusAppIcon1024.png PlatypusAppIcon.iconset/icon_512x512@2x.png
fi
if test -x "$(which iconutil)" -a ! -e PlatypusAppIcon.iconset; then
  iconutil -c icns PlatypusAppIcon.iconset
  if test -d PlatypusAppIcon.iconset -a -w PlatypusAppIcon.iconset; then
    touch PlatypusAppIcon.iconset || rm -R PlatypusAppIcon.iconset
  fi
fi

if test ! -d PlatypusDefault.iconset; then
  mkdir PlatypusDefault.iconset
fi
sips -z 16 16     PlatypusDefault1024.png --out PlatypusDefault.iconset/icon_16x16.png
sips -z 32 32     PlatypusDefault1024.png --out PlatypusDefault.iconset/icon_16x16@2x.png
sips -z 32 32     PlatypusDefault1024.png --out PlatypusDefault.iconset/icon_32x32.png
sips -z 64 64     PlatypusDefault1024.png --out PlatypusDefault.iconset/icon_32x32@2x.png
sips -z 128 128   PlatypusDefault1024.png --out PlatypusDefault.iconset/icon_128x128.png
sips -z 256 256   PlatypusDefault1024.png --out PlatypusDefault.iconset/icon_128x128@2x.png
sips -z 256 256   PlatypusDefault1024.png --out PlatypusDefault.iconset/icon_256x256.png
sips -z 512 512   PlatypusDefault1024.png --out PlatypusDefault.iconset/icon_256x256@2x.png
sips -z 512 512   PlatypusDefault1024.png --out PlatypusDefault.iconset/icon_512x512.png
if test -e PlatypusDefault1024.png; then
  cp PlatypusDefault1024.png PlatypusDefault.iconset/icon_512x512@2x.png
fi
if test -x "$(which iconutil)" -a ! -e PlatypusDefault.icns; then
  iconutil -c icns PlatypusDefault.iconset
  if test -d PlatypusDefault.iconset -a -w PlatypusDefault.iconset; then
    touch PlatypusDefault.iconset || rm -R PlatypusDefault.iconset
  fi
fi

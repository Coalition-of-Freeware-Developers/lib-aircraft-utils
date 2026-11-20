#!/bin/bash

set -euo pipefail

if [ "$#" -lt 2 ]; then
	echo "Usage: $0 <redist-directory> <platform> [platform ...]" >&2
	exit 2
fi

redist="$1"
shift

require_file() {
	if [ ! -s "$1" ]; then
		echo "Missing or empty redistribution file: $1" >&2
		exit 1
	fi
}

# Keep this list in sync with STATIC_LIBS in build_redist.
static_libraries=(
	libacfutils.a
	libcairo.a
	libfreetype.a
	libpixman-1.a
	libpng16.a
	libopusfile.a
	libopus.a
	libopusurl.a
	libogg.a
	libproj.a
	libshp.a
	libcurl.a
	libssl.a
	libcrypto.a
	libxml2.a
	libpcre2-8.a
	libcharset.a
	libiconv.a
	libz.a
	liblzma.a
)

require_file "$redist/README.md"
require_file "$redist/include/acfutils/assert.h"
require_file "$redist/include/cglm/cglm.h"

for platform in "$@"; do
	case "$platform" in
	lin64|mingw64|mac64|win64) ;;
	*)
		echo "Unknown redistribution platform: $platform" >&2
		exit 2
		;;
	esac

	require_file "$redist/$platform/include/cairo.h"
	require_file "$redist/$platform/include/cairo-ft.h"
	require_file "$redist/$platform/include/ft2build.h"
	require_file "$redist/$platform/include/GL/glew.h"
	library_dir="$redist/$platform/lib"

	if [ "$platform" = win64 ]; then
		shopt -s nullglob
		dlls=("$library_dir"/acfutils*.dll)
		if [ "${#dlls[@]}" -ne 1 ]; then
			echo "Expected one acfutils DLL in $library_dir" >&2
			exit 1
		fi
		require_file "${dlls[0]}"
		import_library="$library_dir/lib$(basename "${dlls[0]}" .dll).a"
		require_file "$import_library"
		ar -t "$import_library" > /dev/null
		continue
	fi

	for library in "${static_libraries[@]}"; do
		require_file "$library_dir/$library"
	done
	if [ "$platform" = mingw64 ]; then
		require_file "$library_dir/libglew32mx.a"
		require_file "$library_dir/libgcc.a"
		require_file "$library_dir/libgcc_eh.a"
	else
		require_file "$library_dir/libGLEWmx.a"
	fi

	for library in "$library_dir"/*.a; do
		if [ "$platform" = mac64 ]; then
			# The macOS build job verifies slices before uploading its artifact.
			if [ "$(uname)" = Darwin ]; then
				lipo "$library" -verify_arch x86_64 arm64
			fi
		else
			ar -t "$library" > /dev/null
		fi
	done
done

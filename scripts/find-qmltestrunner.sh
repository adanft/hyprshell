#!/usr/bin/env bash

set -u

if [[ -n "${QMLTESTRUNNER:-}" && -x "$QMLTESTRUNNER" ]]; then
	printf '%s\n' "$QMLTESTRUNNER"
	exit 0
fi

if runner=$(command -v qmltestrunner 2>/dev/null); then
	printf '%s\n' "$runner"
	exit 0
fi

for runner in \
	/usr/lib/qt6/bin/qmltestrunner \
	/usr/lib64/qt6/bin/qmltestrunner \
	/usr/lib/qt6/libexec/qmltestrunner \
	/usr/libexec/qt6/qmltestrunner; do
	if [[ -x "$runner" ]]; then
		printf '%s\n' "$runner"
		exit 0
	fi
done

exit 1

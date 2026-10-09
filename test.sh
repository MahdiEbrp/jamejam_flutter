#!/bin/bash
export LD_LIBRARY_PATH="/run/media/mahdi/Archive/Project/Flutter/jamejam/.lib:${LD_LIBRARY_PATH}"
export TZ=UTC
flutter test "$@"

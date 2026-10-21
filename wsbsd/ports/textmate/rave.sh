#!/bin/sh
# stands in for bin/rave inside build.ninja: ninja regenerates build.ninja with it, and every regeneration must be fixed again (see fix-ninja.py)
ruby bin/rave "$@" || exit $?
python3 /root/wsbsd/ports/textmate/fix-ninja.py build.ninja
sed -i '' 's#${env}bin/rave#${env}sh /root/wsbsd/ports/textmate/rave.sh#' build.ninja

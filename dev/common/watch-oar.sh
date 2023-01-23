#!/bin/bash
set -uex

# The source to watch
SRCDIR=$1
# The folder  containing the copy
TMPDIR=$2

while true; do

  inotifywait -e modify,create,delete,move -r ${SRCDIR} && \
    rsync -r ${SRCDIR}/* ${TMPDIR} && \
    cd ${TMPDIR} && /root/.local/bin/poetry build && \
    pip install dist/*.whl --force-reinstall
  echo "event"

done

#!/usr/bin/env bash

# Better logs
set -eu

CONFIG=$1
FOLDER=$2

REPEAT="${3:-1}"

run_bench() {
  CONFIG=$1
  RESULT=$2
  echo "Reset database"
  oar-database --drop --db-is-local -y
  oar-database --create --db-is-local -y

  echo "Run benchmark"
  _oarbench -f ${CONFIG} -r ${RESULT}
}

if [ ! -d ${FOLDER} ]; then
  mkdir -p ${FOLDER}
fi

echo "Bench will execute ${REPEAT} time(s)"

# Save the configuration file for later replay
cat ${CONFIG} > ${FOLDER}/$(basename ${CONFIG})

for (( c=0; c<=$REPEAT; c++ ))
do
  echo "Run first bench"
  run_bench $CONFIG $FOLDER/bench_${c}
done
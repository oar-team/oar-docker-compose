#!/usr/bin/env bash

# Script that run a set of oarbenchmarks (very similar to bench_script.sh).
# However, at the end of the script, we have some data about the postgres request
# using the plugin pg_stat_statements. The resulting file is located in ${FOLDER}/sql_stats;

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

# Configure postgres
echo "shared_preload_libraries = 'pg_stat_statements'"  >> /etc/postgresql/11/main/postgresql.conf
echo "pg_stat_statements.max = 10000" >> /etc/postgresql/11/main/postgresql.conf
echo "pg_stat_statements.track = all" >> /etc/postgresql/11/main/postgresql.conf

systemctl restart postgresql

su postgres --command "psql -c \"CREATE EXTENSION pg_stat_statements;\"" | true
su postgres --command "psql -c \"SELECT pg_stat_statements_reset();\""


# Save the configuration file for later replay
cat ${CONFIG} > ${FOLDER}/$(basename ${CONFIG})

for (( c=0; c<=$REPEAT; c++ ))
do
  echo "Run first bench"
  run_bench $CONFIG $FOLDER/bench_${c}
done

REQUEST="select query, queryid, calls, rows, total_time,  mean_time, stddev_time from pg_stat_statements where query LIKE '%INSERT INTO gantt_jobs_resources%' OR query LIKE '%INSERT INTO gantt_jobs_predictions%'"
su postgres --command "psql -c \"\COPY (${REQUEST}) TO '/tmp/sql_stats' WITH (FORMAT CSV, HEADER);\""

# Write the result to the destination folder
cat /tmp/sql_stats > ${FOLDER}/sql_stats
#/usr/bin/env bash

set -eux

JOB_ID=$1

# Start a first job, content of the envelop
docker exec --user oar dev_frontend_1 oardel $JOB_ID

sleep 10
docker exec -t --user root dev_server_1 /srv/set_job_tolaunch.py $JOB_ID

sleep 3
docker exec -t --user oar dev_server_1 /usr/local/lib/oar/oar-bipbip $JOB_ID
echo "Job created: $JOB_ID"

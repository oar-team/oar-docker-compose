#/usr/bin/env bash

set -eux

nb_nodes_content1=2
nb_nodes_content2=2


# Start job envelop
envelop_id=$(docker exec --user user1 dev_frontend_1 oarsub -t envelop "sleep 4h" | grep "OAR_JOB_ID=" | sed "s/OAR_JOB_ID= //g")
docker exec -t --user root dev_server_1 /srv/set_job_tolaunch.py $envelop_id 1
docker exec -t --user oar dev_server_1 /usr/local/lib/oar/oar-bipbip $envelop_id
echo "Job envelop created: $envelop_id"


sleep 3

# Start a first job, content of the envelop
job_id=$(docker exec --user user1 dev_frontend_1 oarsub -l nodes=$nb_nodes_content1 -t content=$envelop_id "/srv/python_job.py" | grep "OAR_JOB_ID=" | sed "s/OAR_JOB_ID= //g")
docker exec -t --user root dev_server_1 /srv/set_job_tolaunch.py $job_id $nb_nodes_content1
sleep 1
docker exec -t --user oar dev_server_1 /usr/local/lib/oar/oar-bipbip $job_id
echo "Job created: $job_id"

sleep 3

# start a second job, that should supplent the firt one
job_id=$(docker exec --user user1 -ti dev_frontend_1 oarsub -l nodes=$nb_nodes_content2 -t content=$envelop_id "/srv/python_job.py" | grep "OAR_JOB_ID=" | sed "s/OAR_JOB_ID= //g")
docker exec -t --user root dev_server_1 /srv/set_job_tolaunch.py $job_id $nb_nodes_content2
docker exec -t --user oar dev_server_1 usr/local/lib/oar/oar-bipbip $job_id
echo "Job created: $job_id"

sleep 2
docker exec --user user1 -ti dev_frontend_1 oarstat

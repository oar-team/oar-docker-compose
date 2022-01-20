# Oar Docker Compose

## How to use

- Install [docker-compose](https://docs.docker.com/compose/install/).
- Build the containers: `cd dev && docker-compose build`.
- Start the containers: `docker-compose up`.
- Connect as user 1 to the frontend `docker exec -u user1 -ti dev_frontend_1 bash` (the name might be different on your commputer).
- Now you can try to submit a job with `oarsub -I`.


## oar-docker-compose for oar developers

The folder `dev` contains a setup for oar developers.

### configuration

The file `dev/.env_oar_provisioning.sh` contains configuration parameters that will be forwarded to dev/common/provisioning.sh (in charge of installing oar).

The variable `SRC` points to your oar sources. And needs to be available from the root of the dev folder (i.e `dev/oar3`) so it can be mounted in the dockers.

### Live reload

To lighten the number of actions to do to test new code, a live reload service can be installed. It waits for changes in $SRC (provided in `dev/.env_oar_provisioning.sh`) and redeploy oar3 python from sources.

Live reload can be activated with `LIVE_RELOAD=true` in `dev/.env_oar_provisioning.sh`.
It take some time to redeploy oar, so the changes might not be visible directly.

It is possible to follow the activity of the reload service you can use `journalctl -u live-reload.service`.
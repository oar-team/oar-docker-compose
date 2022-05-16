# Oar Docker Compose

## How to use

- Install [docker-compose](https://docs.docker.com/compose/install/).
- Build the containers: `cd dev && docker-compose build`.
- Start the containers: `docker-compose up`.
- Connect as user 1 to the frontend `docker exec -u user1 -ti dev_frontend_1 bash` (the name might be different on your commputer).
- Now you can try to submit a job with `oarsub -I`.


## oar-docker-compose for oar developers

The folder `dev` contains a setup for oar developers.

### Debian version

The docker images are based on debian stable: bullseye. To change the debian version edit the Dockerfile.
For instance, change `FROM debian:bullseye as base` for `FROM debian:bookworm as base`.

### configuration

The file `dev/.env_oar_provisioning.sh` contains configuration parameters that will be forwarded to dev/common/provisioning.sh (in charge of installing oar).

The variable `SRC` points to your oar sources. And needs to be available from the root of the dev folder (i.e `dev/oar3`) so it can be mounted in the dockers.

- If you leave `SRC` empty the sources will be fetched from github on the branch master (very unstable).
- To work from your sources, you can clone the repository at `dev/oar3-your-clone`, and set `SRC=oar3-your-clone`.

## Provisioning

The installation of OAR is not done when the docker images are built (using `docker build` or `docker-compose build`) but when the dockers are first launched.
The installation is done by the script `dev/common/provisioning.sh`, and is executed when the images are started as a systemd service.
To follow its activity, you can use the command `systemctl status oardocker-provision.service`, when the script exits (with success) OAR should be installed and ready.


### Live reload

To lighten the number of actions to do to test new code, a live reload service can be installed. It waits for changes in $SRC (provided in `dev/.env_oar_provisioning.sh`) and redeploy oar3 python from sources.

Live reload can be activated with `LIVE_RELOAD=true` in `dev/.env_oar_provisioning.sh`.
It take some time to redeploy oar, so the changes might not be visible directly.

It is possible to follow the activity of the reload service you can use `journalctl -u live-reload.service`.

**However, keep in mind that some services such as almighty needs to be restarted for the changes to take effects.**

### Start fastapi

The new version of OAR's RestAPI is developed with Fastapi, and its deployment is not automatised yet.

First, add the port 8001 (its an example, and is configured in the command below).
To add the port, edit `docker-compose.yml` at the section frontend such as:

```yml
  frontend:
    hostname: frontend
    privileged: true
    ports:
      - 8000:8000
      - 8001:8001 # <---- HERE
      - 6668:6668
```

Then, to start the API, use the following command after running `docker-compose up`.

```bash
docker exec --user oar --env OARCONFFILE=/etc/oar/oar.conf dev_frontend_1 uvicorn oar.api.app:app --port 8001 --host 0.0.0.0
```

The API should now be accessible in your browser at the address localhost:8001 (try http://localhost:8001/docs).


## Visualization
You can access the OAR's two webapp tools for visualizing the resources utilization via the host:

- **Monika** \
which displays the current state of resources as well as all running and waiting jobs \
http://localhost:8000/monika

- **Drawgantt** \
which displays gantt chart of nodes and jobs for the past and future \
http://localhost:8000/drawgantt/


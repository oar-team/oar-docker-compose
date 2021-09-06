# Oar Docker Compose

## How to use

- Install [docker-compose](https://docs.docker.com/compose/install/).
- Build the containers: `cd dev && docker-compose build`.
- Start the containers: `docker-compose up`.
- Connect as user 1 to the frontend `docker exec -u user1 -ti dev_frontend_1 bash` (the name might be different on your commputer).
- Now you can try to submit a job with `oarsub -I`.

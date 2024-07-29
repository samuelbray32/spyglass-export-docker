# Dockerizing a Spyglass Export

## TODO

Will ...

1. Add `Makefile` commands for publishing the docker image.
1. Clean up `Dockerfile` commands with debug tools.
1. Add snippet to send to collaborators.

Maybe ...

1. Workflow actions for publishing the docker image.
1. Template repository for creating a new paper repository.

## About

[Spyglass](lorenfranklab.github.io/spyglass/) is an open-source framework for
managing and analyzing data in neuroscience research. The Export feature allows
users to generate scripts[^1] to recreate both their conda environmen and the
database, as well as upload data to [DANDI Archive](https://dandiarchive.org/).

[^1]: The `.sh` scripts generated by Spyglass must first be run by a database
    administrator to create the database and tables. The resulting `.sql` will
    then be used to populate the Docker database.

This repository is intended to be used with the
[Docker](https://www.docker.com/) to create and share a reproducible
environment for replicating a paper's analyses.

## Quick Start

1. Pre-requisites: `make` and `docker`.
    - `make` is available on most Unix systems as part of
    [GNU Make](https://www.gnu.org/software/make/), or available with
    `choco` (Windows) or `brew` (macOS).
    - [Docker](https://docs.docker.com/get-docker/) builds, runs, and manages
    containers.
1. Register for [Docker Hub](https://hub.docker.com/signup) and run
    `docker login`.
1. Clone this repository to your local machine.
1. Copy `env.example` to `.env` and edit the values.
1. Copy the paper's notebooks to `notebooks/`[^2].
1. Run `make build` to build the docker image.
1. Navigate to `http://localhost:8888/lab`, using the paper ID as the password.
1. Test the notebooks.
1. Run `make publish` to publish the image.
1. Share the image with collaborators, who can run `make run` to start the
    container and visit the same URL. They will need (a) the `.env` file,
    (b) the `docker-compose-collab.yml` file, and (c) the `Makefile`.

[^2]: If your paper depends on a specific version of Spyglass or additional
    custom packages, please link to these in your notebooks. You can find the
    version of Spyglass at the top of any `.sql` file, and find the link in the
    list of [Spyglass tags](https://github.com/LorenFrankLab/spyglass/tags).

## Overview

- `Makefile`: Contains commands for building and publishing the docker image.
  - `copy_files`: Copies the export `sql` and `yml` files to the
    `export_data/` directory.
  - `down`: Stops and removes existing docker containers.
  - `up`: Runs `down`, then starts the docker container.
  - `enter`: Enters the running docker container for debugging.
- `docker-compose.yml`: Defines the docker containers and volumes.
  - `db`: Service. MySQL database container.
  - `hub`: Service. Jupyter notebook server container.
  - `conda`: Volume. Cache of the hub's conda environment.
  - `db_data`: Volume. Cache of the database's data.
- `docker-compose-collab.yml`: Similar to `docker-compose.yml`, but using the
  `hub` image from Docker Hub. This file is intended for collaborators.
- `Dockerfile`: Adds additional instructions to the `hub` container.
  - Copies in datajoint and jupyter configuration files.
  - Installs `git` for possible git installs in the conda environment. For a
    faster build time, remove this line if no such installs are needed.
  - Installs the paper's conda environment.
  - Runs `entrypoint.py` to configure the datajoint connection.
- `env.example`: Example environment variables for the `.env` file. Must be
  copied to `.env` and edited.
- `config`: Contains additional configuration files.
  - `.datajoint_config.py`: Default configuration for the datajoint connection.
  - `entrypoint.py`: Edits the datajoint config based on environment variables.
  - `entrypoint_db.sh`: Loads exported `sql` files. Run my the `db` service.
  - `jupyter_server_config.py`: Configures the jupyter notebook server.
        - Sets the default kernel to the paper's conda environment.
        - Sets the server password.

## Security

This repository is intended for use in a secure environment. It is not intended
for use in a production environment.

By default the jupyter notebook server password is the paper ID variable.

## Troubleshooting

### Table Declaration

If you see `OperationalError` when trying to import a table that may not be
in your exported `sql` file, you may need to remove the charset sepecifications.
This can be done with the following command(s) for each `sql` file:

```bash
sed -i 's/ DEFAULT CHARSET=[^ ]\w*//g' _Populate_YourPaper.sql
sed -i 's/ DEFAULT COLLATE [^ ]\w*//g' _Populate_YourPaper.sql
```

<details><summary>What will this do?</summary>

These `sed` commands remove encoding specifications from the `sql` file(s).

```sql
CREATE TABLE your_table (
    ...
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE swedish_latin=ci COMMENT='X';
```

Will become:

```sql
CREATE TABLE your_table (
    ...
) ENGINE=InnoDB COMMENT='X';
```

The line with `ENGINE=InnoDB` should always end in `;`. It may or may not have
a `COMMENT` field.

</details>

## Elevated Access

The default hub container does not have sudo access. If you need to install
additional package or debug within the container, you may wish do the following:

<details><summary>Admin within the container</summary>

Add sudo for the default user, mysql credentials to the `Dockerfile`, and add
`mysql-client` to allow command line access to the database.

```Dockerfile
USER root

# Allow sudo
RUN echo "jovyan:jovyanpassword" | chpasswd
RUN echo "jovyan ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/jovyan
# Add mysql credentials - Vars must also be added to docker-compose.yml
ARG MYSQL_HOST
ARG MYSQL_USER
ARG MYSQL_ROOT_PASSWORD
# Add default mysql credentials
RUN echo -e "\
[client]\n\
host=${MYSQL_HOST}\n\
user=${MYSQL_USER}\n\
password=${MYSQL_ROOT_PASSWORD}\n\n\
[mysqld]\n\
character-set-server = latin1\n\
collation-server = latin1_swedish_ci" > ${HOME}/.my.cnf
RUN apt update && apt install mysql-client -y

USER ${NB_UID}
```

Each `ARG` item must also be added to the `docker-compose.yml` file under the
`hub` service:

```yaml
    build:
      context: .
      dockerfile: Dockerfile
      args:
        MYSQL_HOST: db
        MYSQL_USER: root
        MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
```

And add `GRANT_SUDO=yes` to the `.env` file.

</details>

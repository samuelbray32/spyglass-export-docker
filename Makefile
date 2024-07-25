.PHONY: down
up: copy_files down only_up
enter: copy_files down only_up only_enter

# Include .env file
include .env

# Helpers
IS_RUNNING=$(shell docker ps --filter "name=hub" --filter "status=running" -q)
DOCKER_EXEC_SH = docker exec -it hub /bin/bash -c
DOCKER_EXEC_SQL = docker exec -it hub mysql -e


# Copy files from the paper directory to the export_files directory
copy_files:
	@cp -f ${SPYGLASS_PAPER_DIR}/environment.yml ./export_files/
	@cp -rf ${SPYGLASS_PAPER_DIR}/*sql ./export_files/

# Tear down the container, if it is running
down:
	@if [ -z "$(IS_RUNNING)" ]; then \
		echo "The container is not running."; \
	else \
		docker stop hub; \
		docker rm hub; \
	fi

# Build the container, run sanity check ls
only_up:
	docker compose up --build -d
	$(DOCKER_EXEC) "ls -l /home"

# Enter the container
only_enter:
	docker exec -it hub /bin/bash
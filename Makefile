.PHONY: down
build: up
up: check_env copy_files down only_up
enter: check_env copy_files down only_up only_enter
run: check_env only_run

# Include .env file
include .env

# Helpers
IS_RUNNING=$(shell docker ps --filter "name=hub" --filter "status=running" -q)
DOCKER_EXEC_SH = docker exec -it hub /bin/bash -c
DOCKER_EXEC_SQL = docker exec -it hub mysql -e

# Check for .env file
check_env:
	@if [ ! -f .env ]; then \
			echo ".env file not found!"; \
			echo "Please copy example.env to .env and fill in the required values."; \
			exit 1; \
	fi

# Copy files from the paper directory to the export_files directory
copy_files:
	@cp -f ${SPYGLASS_PAPER_DIR}/environment.yml ./export_files/
	@cp -rf ${SPYGLASS_PAPER_DIR}/*sql ./export_files/
	@for file in ./export_files/*sql; do \
		sed -i 's/ DEFAULT CHARSET=[^ ]\w*//g' $${file}; \
		sed -i 's/ DEFAULT COLLATE [^ ]\w*//g' $${file}; \
	done

# Tear down the container, if it is running
down:
	@if [ -z "$(IS_RUNNING)" ]; then \
		echo "The container is not running."; \
	else \
		docker stop hub; \
		docker rm hub; \
		docker stop db; \
		docker rm db; \
	fi

# Build the container, run sanity check ls
only_up: # needs timeout and error message
	@docker compose up --build -d -t 300; \
	exit_status=$$?; \
	if [ $$exit_status -ne 0 ]; then \
		echo "Container failed."; \
		echo "Please check which container is not running (hub or db)"; \
		echo "And run 'docker logs <container_name>' to see the error message."; \
		exit 1; \
	fi


# Enter the container
only_enter:
	@docker exec -it hub /bin/bash

# Publish to docker hub
publish:
	@docker login
	@docker build -f Docker_hub.Dockerfile . -t ${HUB_IMAGE_NAME}:latest
	@docker build -f Docker_db.Dockerfile . -t ${DB_IMAGE_NAME}:latest
	@docker push ${HUB_IMAGE_NAME}:latest
	@docker push ${DB_IMAGE_NAME}:latest

# Run the published container
only_run:
	@docker compose -f docker-compose-collab.yml up -d

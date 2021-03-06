# Copyright 2020 - Offen Authors <hioffen@posteo.de>
# SPDX-License-Identifier: Apache-2.0

help:
	@echo "    up"
	@echo "        Start the development server"
	@echo "    down"
	@echo "        Tear down the development server"
	@echo "    setup"
	@echo "        Build the development containers and install dependencies"
	@echo "    bootstrap"
	@echo "        Set up and seed databases"
	@echo "        **IMPORTANT**: this wipes any existing data in your local database"
	@echo "    update"
	@echo "        Install / update dependencies in the containers"
	@echo "    audit"
	@echo "        Run npm audit for all apps"
	@echo "    migrate"
	@echo "        Apply pending database migrations"
	@echo "    build"
	@echo "        Build binaries"
	@echo "        You can pass TARGETS if you are targeting other platforms than Linux"
	@echo "    build-docker"
	@echo "        Build the Docker image"
	@echo "        You can pass DOCKER_IMAGE_TAG if you want to use a non-default tag"
	@echo "    docs"
	@echo "    extract-strings"
	@echo "        Extract strings for localization"
	@echo "    secret"
	@echo "        Generate a random base64 encoded secret"
	@echo "    test"
	@echo "        Run unit tests for all apps"
	@echo "    integration"
	@echo "        Run integration tests against a running dev environment"
	@echo "        Run the docs site locally"
	@echo "    setup-docs"
	@echo "        Build the docs containers and install dependencies"
	@echo "    build-docs"
	@echo "        Build the documentation site"

setup: dev-build update howto


dev-build:
	@docker-compose build

howto:
	@echo "Successfully built containers and installed dependencies."
	@echo "If this is your initial setup, you can run 'make bootstrap' next"
	@echo "to create seed the database."

bootstrap:
	@echo "Bootstrapping Server service ..."
	@docker-compose run --rm server make setup

update:
	@echo "Installing / updating dependencies ..."
	@docker-compose run --rm script npm install
	@docker-compose run --rm vault npm install
	@docker-compose run --rm auditorium npm install
	@docker-compose run --rm server go mod download -x

audit:
	@echo "Auditing npm dependencies ..."
	@docker-compose run --rm script npm audit
	@docker-compose run --rm vault npm audit
	@docker-compose run --rm auditorium npm audit

migrate:
	@docker-compose run --rm server make migrate

extract-strings:
	@docker-compose run --rm server make extract-strings
	@docker-compose run --rm auditorium npm run extract-strings
	@docker-compose run --rm script npm run extract-strings
	@docker-compose run --rm vault npm run extract-strings

TARGETS ?= linux/amd64
LDFLAGS ?= -static
DOCKER_IMAGE_TAG ?= local
OFFEN_GIT_REVISION ?= none

build:
	@docker build --build-arg ldflags=${LDFLAGS} --build-arg targets=${TARGETS} --build-arg rev=${OFFEN_GIT_REVISION} -t offen/build -f build/Dockerfile.build .
	@mkdir -p bin
	@docker create --entrypoint=bash -it --name binary offen/build
	@docker cp binary:/build/. ./bin
	@docker rm binary

build-docker:
	@docker build -t offen/offen:${DOCKER_IMAGE_TAG} -f build/Dockerfile .

secret:
	@docker-compose run server make secret

up:
	@docker-compose up

down:
	@docker-compose down

test:
	@docker-compose run --rm script npm test
	@docker-compose run --rm vault npm test
	@docker-compose run --rm auditorium npm test
	@docker-compose run --rm server make test

integration:
	@docker-compose -f docker-compose.integration.yml run --rm integration npm t

setup-docs:
	@docker-compose -f docker-compose.docs.yml build
	@docker-compose -f docker-compose.docs.yml run --rm docs_jekyll bundle install
	@docker-compose -f docker-compose.docs.yml run --rm docs_jekyll bundle exec just-the-docs rake search:init

docs:
	@docker-compose -f docker-compose.docs.yml up

build-docs:
	@docker build -t offen/docs -f build/Dockerfile.docs .
	@rm -rf docs-site && mkdir docs-site
	@docker create --entrypoint=bash -it --name assets offen/docs
	@docker cp assets:/repo/_site/. ./docs-site/
	@docker rm assets

.PHONY: setup build build-docker bootstrap build secret test up down integration docs

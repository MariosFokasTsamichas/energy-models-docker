# Energy Models Workbench — common tasks.
#
# Everything reads its pins from versions.env, so `make build` and CI build
# exactly the commits listed there.

SHELL := /usr/bin/env bash
.DEFAULT_GOAL := help

include versions.env
export

IMAGE_NAME ?= ghcr.io/mariosfokastsamichas/energy-models-workbench
IMAGE_TAG ?= dev

BUILD_ARGS = \
	--build-arg PYPSA_EUR_REPO=$(PYPSA_EUR_REPO) \
	--build-arg PYPSA_EUR_REF=$(PYPSA_EUR_REF) \
	--build-arg EU_FLEX_REPO=$(EU_FLEX_REPO) \
	--build-arg EU_FLEX_REF=$(EU_FLEX_REF) \
	--build-arg OSEMOSYS_REPO=$(OSEMOSYS_REPO) \
	--build-arg OSEMOSYS_REF=$(OSEMOSYS_REF)

.PHONY: help build build-amd64 build-arm64 up down logs shell test test-lite \
        notebooks clean clean-all update-pins pins doctor

help: ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

build: ## Build the image for the host architecture (IMAGE_TAG=dev)
	docker build $(BUILD_ARGS) \
		--tag $(IMAGE_NAME):$(IMAGE_TAG) \
		--file Dockerfile .

build-amd64: ## Cross-build for linux/amd64 (needs buildx + emulation)
	docker buildx build --platform linux/amd64 --load $(BUILD_ARGS) \
		--tag $(IMAGE_NAME):$(IMAGE_TAG)-amd64 \
		--file Dockerfile .

build-arm64: ## Build for linux/arm64
	docker buildx build --platform linux/arm64 --load $(BUILD_ARGS) \
		--tag $(IMAGE_NAME):$(IMAGE_TAG)-arm64 \
		--file Dockerfile .

up: ## Start the workbench in the background (docker compose)
	IMAGE_TAG=$(IMAGE_TAG) docker compose up -d --build

down: ## Stop and remove the container (volumes are kept)
	docker compose down

logs: ## Follow the container logs
	docker compose logs -f --tail=100

shell: ## Open a bash shell in the image as the workbench user
	docker run --rm -it \
		-e START_OSEMOSYS_STUDIO=0 \
		--entrypoint /bin/bash \
		$(IMAGE_NAME):$(IMAGE_TAG)

test: ## Run the full smoke test suite inside the image
	docker run --rm \
		-e START_OSEMOSYS_STUDIO=0 \
		-v $(CURDIR)/tests:/opt/tests:ro \
		$(IMAGE_NAME):$(IMAGE_TAG) \
		/opt/conda/envs/workbench/bin/python -m pytest -q -p no:cacheprovider /opt/tests

test-lite: ## Run only the environment/kernel tests (fast)
	docker run --rm \
		-e START_OSEMOSYS_STUDIO=0 \
		$(IMAGE_NAME):$(IMAGE_TAG) \
		/opt/conda/envs/workbench/bin/python -m pytest -q -p no:cacheprovider /opt/tests \
		-k "kernel or environment"

notebooks: ## Copy the example notebooks from the image into ./examples
	mkdir -p examples
	docker run --rm --entrypoint /bin/bash \
		-v $(CURDIR)/examples:/out \
		$(IMAGE_NAME):$(IMAGE_TAG) \
		-c 'rsync -a --delete /opt/examples/ /out/'

pins: ## Show the pinned upstream commits and their dates
	@printf '  PyPSA-Eur  %s\n' "$(PYPSA_EUR_REF)"
	@printf '  EU-Flex    %s\n' "$(EU_FLEX_REF)"
	@printf '  OSeMOSYS   %s\n' "$(OSEMOSYS_REF)"
	@printf '  pinned on  %s\n' "$(PINNED_ON)"

doctor: ## Print container state, token, kernels and disk usage
	./scripts/doctor.sh

update-pins: ## Re-resolve the pins from each upstream default branch
	./scripts/update-pins.sh

clean: ## Remove the container and the image built by this Makefile
	-docker compose down --remove-orphans
	-docker image rm $(IMAGE_NAME):$(IMAGE_TAG)

clean-all: clean ## Also delete the work, data and results volumes (destructive)
	-docker volume rm energy-models-work energy-models-data energy-models-results

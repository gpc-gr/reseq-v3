#
# (c) 2019 Center for Genome Platform Projects, Tohoku Medical Megabank Organization
#

DOCKER				:= docker

GIT_HASH			:= $(shell git rev-parse HEAD | head -c8)
DOCKER_IMAGE_REPO	:= tommo-gpc
DOCKER_IMAGE_NAME	:= reseq
DOCKER_IMAGE_TAG	:= v3-$(GIT_HASH)

.DEFAULT_GOAL := singularity
.PHONY: singularity clean


singularity:
	# generate build info file
	mkdir -p build
	echo "ToMMo GPC Resequencing Pipeline v3" > build/BUILD
	echo "    Build date: $(shell date +%Y%m%d-%H%M%S)" >> build/BUILD
	echo "    Git Hash: $(GIT_HASH)" >> build/BUILD

	# build docker image
	$(DOCKER) build\
		--build-arg http_proxy=$(http_proxy)\
		--build-arg https_proxy=$(https_proxy)\
		--target prod\
		--tag $(DOCKER_IMAGE_REPO)/$(DOCKER_IMAGE_NAME):$(DOCKER_IMAGE_TAG)\
		.

	# convert docker image to singularity image
	$(DOCKER) run\
		--tty\
		--privileged\
		--rm\
		--volume /var/run/docker.sock:/var/run/docker.sock\
		--volume $(shell pwd)/build:/output\
		singularityware/docker2singularity\
			--name gpc-reseq-v4-$(GIT_HASH)\
			$(DOCKER_IMAGE_REPO)/$(DOCKER_IMAGE_NAME):$(DOCKER_IMAGE_TAG)


clean:
	rm -rf ./build

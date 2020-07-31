ARG UBUNTU_VER="bionic"
ARG ALPINE_VER="edge"
FROM alpine:${ALPINE_VER} as fetch-stage

############## fetch stage ##############

# install fetch packages
RUN \
	apk add --no-cache \
		bash \
		curl

# set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# fetch version file
RUN \
	set -ex \
	&& curl -o \
	/tmp/version.txt -L \
	"https://raw.githubusercontent.com/sparklyballs/versioning/master/version.txt"

# fetch source code
# hadolint ignore=SC1091
RUN \
	. /tmp/version.txt \
	&& set -ex \
	&& mkdir -p \
		/source/shellcheck \
	&& curl -o \
	/tmp/shellcheck.tar.gz	-L \
		"https://github.com/koalaman/shellcheck/archive/${SHELLCHECK_COMMIT}.tar.gz" \
	&& tar xf \
	/tmp/shellcheck.tar.gz -C \
	/source/shellcheck --strip-components=1

FROM ubuntu:${UBUNTU_VER} as build-stage

############## build stage ##############

# install build packages
RUN \
	apt-get update \
	&& apt-get install -y \
		--no-install-recommends \
		cabal-install \
		curl \
		ghc \
		git \
	\
# cleanup
	\
	&& rm -rf \
		/tmp/* \
		/var/lib/apt/lists/* \
		/var/tmp/*

# add artifacts from source stage
COPY --from=fetch-stage /source /source

# set workdir
WORKDIR /source/shellcheck

# build app
RUN \
	set -ex \
	&& cabal update \
	&& cabal install --dependencies-only \
	&& cabal build Paths_ShellCheck \
	&& ghc \
		-idist/build/autogen \
		-isrc \
		-optl-pthread \
		-optl-static \
		--make \
	shellcheck \
	&& strip --strip-all shellcheck

FROM alpine:${ALPINE_VER}

############## runtine stage ##############

# add artifacts from build stage
COPY --from=build-stage /source/shellcheck/shellcheck /usr/local/bin/

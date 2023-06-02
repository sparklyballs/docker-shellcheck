ARG ALPINE_VER="edge"
FROM alpine:${ALPINE_VER} as fetch-stage

############## fetch stage ##############

# build args
ARG RELEASE

# install fetch packages
RUN \
	apk add --no-cache \
		bash \
		curl \
		jq

# set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# fetch source
RUN \
	if [ -z ${RELEASE+x} ]; then \
	RELEASE=$(curl -u "${SECRETUSER}:${SECRETPASS}" -sX GET "https://api.github.com/repos/koalaman/shellcheck/commits/master" \
	| jq -r ".sha"); \
	fi \
	&& RELEASE="${RELEASE:0:7}" \
	&& mkdir -p \
		/src/shellcheck \
	&& curl -o \
	/tmp/shellcheck.tar.gz	-L \
		"https://github.com/koalaman/shellcheck/archive/${RELEASE}.tar.gz" \
	&& tar xf \
	/tmp/shellcheck.tar.gz -C \
	/src/shellcheck --strip-components=1

FROM alpine:${ALPINE_VER} as build-stage

############## build stage ##############

# install build packages
RUN \
	apk add --no-cache \
		bash \
		cabal \
		curl \
		ghc \
		git \
		libffi-dev \
		musl-dev

# add artifacts from source stage
COPY --from=fetch-stage /src /src

# set workdir
WORKDIR /src/shellcheck

# build app
RUN \
	_cabal_home="/src/shellcheck/dist" \
	&& set -ex \
	&& HOME="$_cabal_home" cabal update \
	&& HOME="$_cabal_home" cabal v1-install \
		--disable-documentation \
		--only-dependencies \
	&& HOME="$_cabal_home" cabal v1-configure \
		--libs --static \
		--enable-executable-static \
		--enable-executable-stripping \
	&& HOME="$_cabal_home" cabal v1-build -j \
	&& strip --strip-all /src/shellcheck/dist/build/shellcheck/shellcheck

FROM alpine:${ALPINE_VER}

############## runtine stage ##############

RUN \
	apk add --no-cache \
		bash \
		findutils

# set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# add artifacts from build stage
COPY --from=build-stage /src/shellcheck/dist/build/shellcheck/shellcheck /usr/local/bin/

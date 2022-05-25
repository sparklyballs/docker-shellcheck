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
COPY --from=fetch-stage /source /source

# set workdir
WORKDIR /source/shellcheck

# build app
RUN \
	_cabal_home="/source/shellcheck/dist" \
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
	&& strip --strip-all /source/shellcheck/dist/build/shellcheck/shellcheck

FROM alpine:${ALPINE_VER}

############## runtine stage ##############

# add artifacts from build stage
COPY --from=build-stage /source/shellcheck/dist/build/shellcheck/shellcheck /usr/local/bin/

pipeline {
	agent {
	label 'DOCKER_BUILD_X86_64'
	}

options {
	skipDefaultCheckout(true)
	buildDiscarder(logRotator(numToKeepStr: '5', artifactNumToKeepStr: '5'))
	}

environment {
	CREDS_DOCKERHUB=credentials('420d305d-4feb-4f56-802b-a3382c561226')
	CREDS_GITHUB=credentials('bd8b00ff-decf-4a75-9e56-1ea2c7d0d708')
	CONTAINER_NAME = 'shellcheck'
	CONTAINER_REPOSITORY = 'sparklyballs/shellcheck'
	GITHUB_RELEASE_URL_SUFFIX = 'koalaman/shellcheck/commits/master'
	GITHUB_REPOSITORY = 'sparklyballs/docker-shellcheck'
	HADOLINT_OPTIONS = '--ignore DL3008 --ignore DL3013 --ignore DL3018 --ignore DL3028 --format json'
	}

stages {

stage('Query Release Version') {
steps {
script{
	env.RELEASE_VER = sh(script: 'curl -sX GET "https://api.github.com/repos/${GITHUB_RELEASE_URL_SUFFIX}" | jq -r ".sha"', returnStdout: true).trim() 
	env.RELEASE_VER = "$RELEASE_VER"[0..7]
	env.GMP_RELEASE_VER = sh(script: 'curl -s "https://gmplib.org/#DOWNLOAD" | grep lz | grep ftp | grep -o -P "(?<=>gmp-).*(?=.tar.lz)"', returnStdout: true).trim()
	}
	}
	}

stage('Checkout Repository') {
steps {
	cleanWs()
	checkout scm
	}
	}

stage ("Do Some Linting") {
steps {
	sh ('curl -o linting-script.sh -L https://raw.githubusercontent.com/sparklyballs/versioning/master/linting-script.sh')
	sh ('/bin/bash linting-script.sh')
	recordIssues enabledForFailure: true, tool: hadoLint(pattern: 'hadolint-result.xml')	
	recordIssues enabledForFailure: true, tool: checkStyle(pattern: 'shellcheck-result.xml')	
	}
	}

stage('Build Docker Image') {
steps {
	sh ('docker buildx build \
	--no-cache \
	--pull \
	-t $CONTAINER_REPOSITORY:latest \
	-t $CONTAINER_REPOSITORY:$BUILD_NUMBER \
	-t $CONTAINER_REPOSITORY:$RELEASE_VER \
	--build-arg RELEASE=$RELEASE_VER \
	--build-arg GMP_RELEASE=$GMP_RELEASE_VER \
	.')
	}
	}

stage('Push Docker Image and Tags') {
steps {
	sh ('echo $CREDS_DOCKERHUB_PSW | docker login -u $CREDS_DOCKERHUB_USR --password-stdin')
	sh ('docker image push $CONTAINER_REPOSITORY:latest')
	sh ('docker image push $CONTAINER_REPOSITORY:$BUILD_NUMBER')
	sh ('docker image push $CONTAINER_REPOSITORY:$RELEASE_VER')
	}
	}

stage('Readme Sync') {
steps {
	sh('docker pull ghcr.io/linuxserver/readme-sync')
	sh('docker run --rm=true \
	-e DOCKERHUB_USERNAME=$CREDS_DOCKERHUB_USR \
	-e DOCKERHUB_PASSWORD=$CREDS_DOCKERHUB_PSW \
	-e GIT_REPOSITORY=$GITHUB_REPOSITORY \
	-e DOCKER_REPOSITORY=$CONTAINER_REPOSITORY \
	-e GIT_BRANCH=master \
	ghcr.io/linuxserver/readme-sync bash -c "node sync"')
	}
	}
}

post {
success {
sshagent (credentials: ['bd8b00ff-decf-4a75-9e56-1ea2c7d0d708']) {
    sh('git tag -f $BUILD_NUMBER')
    sh('git tag -f $RELEASE_VER')
    sh('git push -f git@github.com:$GITHUB_REPOSITORY.git $BUILD_NUMBER')
    sh('git push -f git@github.com:$GITHUB_REPOSITORY.git $RELEASE_VER')
	}
	}
	}
}

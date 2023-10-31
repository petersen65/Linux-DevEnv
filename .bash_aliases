# Functions library
build_docker_image() {
    local BASE_NAME_TAG='ubuntu:23.10'
    local TARGET_NAME_TAG='ubuntu-develop:latest'
    local CREATE_STEPS='prepare,docker,install,no_git,no_build,finish'
    local PROJECTS='googletest,flatbuffers,fruit,nng,grpc'
    local WHAT_IF=''
    local BUILD_CONTEXT='.'
    local TARGET_ENV='ubuntu_docker'
    local DOCKER_FILE='dockerfile-ubuntu_docker'

    if [ -n "$1" ]; then
        BASE_NAME_TAG=$1
    fi

    if [ -n "$2" ]; then
        TARGET_NAME_TAG=$2
    fi

    if [ -n "$3" ]; then
        CREATE_STEPS=$3
    fi

    if [ -n "$4" ]; then
        PROJECTS=$4
    fi

    if [ -n "$5" -a "$5" = "-w" ]; then
        WHAT_IF=$5
    fi

    if [ -n "$6" -a "$6" != "$DOCKER_FILE" ]; then
        DOCKER_FILE=$6
        CREATE_STEPS="! -> ignored for docker file \"$DOCKER_FILE\" <- !"
    fi

    if [ -n "$7" ]; then
        BUILD_CONTEXT=$7
    fi

    echo "build_docker_image [<base-name:tag>]   = '$BASE_NAME_TAG'"
    echo "                   [<target-name:tag>] = '$TARGET_NAME_TAG'"
    echo "                   [<create-steps>]    = '$CREATE_STEPS'"
    echo "                   [<projects>]        = '$PROJECTS'"
    echo "                   [<what-if>]         = '$WHAT_IF'"
    echo "                   [<docker-file>]     = '$DOCKER_FILE'"
    echo "                   [<build-context>]   = '$BUILD_CONTEXT'"
    echo

    local REPLY=''

    if [ -n "$ZSH_VERSION" ]; then
        read -t 5 -k 1 -s "REPLY?Delete current '$TARGET_NAME_TAG' Docker image [y/n]: "
    else
        read -t 5 -n 1 -s -p "Delete current '$TARGET_NAME_TAG' Docker image [y/n]: " REPLY
    fi

    echo

    if [ -z "$REPLY" -o "$REPLY" != "y" ]; then
        echo 'Docker image creation aborted!'
    else
        docker image rm --force "${TARGET_NAME_TAG}"

        docker buildx build \
        --build-arg BASE_IMG="${BASE_NAME_TAG}" \
        --build-arg TARGET_ENV="${TARGET_ENV}" \
        --build-arg CREATE_STEPS="${CREATE_STEPS}" \
        --build-arg PROJECTS="${PROJECTS}" \
        --build-arg WHAT_IF="${WHAT_IF}" \
        --no-cache \
        --tag "${TARGET_NAME_TAG}" \
        --file "${BUILD_CONTEXT}/${DOCKER_FILE}" \
        "${BUILD_CONTEXT}"
    fi
}

# Docker aliases
alias dkimg='docker image ls'
alias dkcnt='docker container ls -a'
alias dkrmi='docker image rm'
alias dkrm='docker container rm'
alias dkbld='build_docker_image'
alias dkrun='docker run --tty --interactive --rm'
alias dkrune='docker run --entrypoint /bin/bash --tty --interactive --rm'
alias dkrunm='docker run --entrypoint /bin/bash --mount source=$(pwd),target=/root/target,type=bind --mount source=/var/run/docker.sock,target=/var/run/docker.sock,type=bind --tty --interactive --rm'

# Kubernetes aliases
alias kc='kubectl'

# Some alias to avoid making mistakes
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# Utility aliases
alias mypip='dig myip.opendns.com @resolver1.opendns.com +short'

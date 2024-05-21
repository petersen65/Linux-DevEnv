#!/bin/bash
# prepare and install development support for programming with C/C++ and Go

# Prepare & Install on Windows 11 Terminal -----------------------------------------------------------------------------
#
# WSL PS:
#     sl $MY_REPOS_DIR\Linux-DevEnv
#     Copy-Item -Path .\.bash_aliases,.\.vimrc,.\prepare-linux-dev-env.sh -Destination \\wsl.localhost\Ubuntu-24.04\tmp\
#     ubuntu2404.exe
#
# WSL GIT BASH:
#     cd $MY_REPOS_DIR/Linux-DevEnv
#     cp .bash_aliases .vimrc prepare-linux-dev-env.sh //wsl.localhost/Ubuntu-24.04/tmp
#     ubuntu2404.exe
#
# SSH VM:
#     sftp user@dns-name
#     put .* /tmp/
#     put * /tmp/
#     exit
#     ssh user@dns-name
#
# VM or WSL terminal:
#     sudo -i
#     chmod +x /tmp/prepare-linux-dev-env.sh
#     apt-get update
#     apt-get install --yes dos2unix
#     dos2unix -iso -1252 /tmp/prepare-linux-dev-env.sh
#
#     Then a) or b)
#         [] defines an optional parameter like 'cli_only' or 'prepare,docker'
#         <> defines an optional command like 'git_all' or 'build_all'
#
# a) -----------------------------------------------------------------------------------------------------------
#     source /tmp/prepare-linux-dev-env.sh -u 'username'
#     apt_prepare
#     ubuntu_user_experience
#     update_dev_variables
#     ubuntu_install_docker ['cli_only']
#     exit # exit root
#     exit # exit terminal
#     ssh user@dns-name | ubuntu2404.exe
#     sudo -i
#     source /tmp/prepare-linux-dev-env.sh -u 'username'
#     apt_install
#     <git_all>
#     <build_all>
#     user_group
#     final_config
#     exit # exit root
#     exit # exit terminal
#
# b) -----------------------------------------------------------------------------------------------------------
#     /tmp/prepare-linux-dev-env.sh \
#         -u 'username' \
#         -e 'ubuntu_vm' | -e 'ubuntu_wsl' \
#         [-s prepare,docker,install,git,build,finish] \
#         [-p googletest,flatbuffers,fruit,nng,grpc] \
#         [-w]
#
#     exit # exit root
#     exit # exit terminal

# -- prepare functions -------------------------------------------------------------------------------------------------

# bring Ubuntu distribution up to date
apt_prepare() {
    apt-get update
    apt-get upgrade --with-new-pkgs --yes
    apt-get autoremove --yes

    apt-get install --yes \
        dos2unix \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release \
        tzdata

    ln -fs /usr/share/zoneinfo/Europe/Berlin /etc/localtime
    dpkg-reconfigure --frontend noninteractive tzdata
    useradd -m $TARGET_USER || :
}

# adjust .bashrc for better user experiences
ubuntu_user_experience() {
    dos2unix -iso -1252 /tmp/.vimrc
    dos2unix -iso -1252 /tmp/.bash_aliases
    dos2unix -iso -1252 /tmp/prepare-linux-dev-env.sh
    chmod +x /tmp/prepare-linux-dev-env.sh

    cp /tmp/.vimrc /root/
    cp /tmp/.bash_aliases /root/

    sed --in-place 's/#force_color_prompt/force_color_prompt/g' /root/.bashrc
    sed --in-place '/debian_chroot/s/\bw\b/W/g' /root/.bashrc
    sed --in-place '/debian_chroot/s/\\$ / \\$ /g' /root/.bashrc
    sed --in-place '/debian_chroot/s/;32m/;31m/g' /root/.bashrc
    sed --in-place '/color=auto/s/#alias/alias/g' /root/.bashrc
    sed --in-place '/GCC_COLORS/s/#export/export/g' /root/.bashrc

    cp /tmp/.vimrc /home/$TARGET_USER
    cp /tmp/.bash_aliases /home/$TARGET_USER

    sed --in-place 's/#force_color_prompt/force_color_prompt/g' /home/$TARGET_USER/.bashrc
    sed --in-place '/debian_chroot/s/\bw\b/W/g' /home/$TARGET_USER/.bashrc
    sed --in-place '/debian_chroot/s/\\$ / \\$ /g' /home/$TARGET_USER/.bashrc
    sed --in-place '/color=auto/s/#alias/alias/g' /home/$TARGET_USER/.bashrc
    sed --in-place '/GCC_COLORS/s/#export/export/g' /home/$TARGET_USER/.bashrc

    echo "$TARGET_USER ALL=(ALL) NOPASSWD:ALL" >>/etc/sudoers
}

# adjust .bashrc with standardized paths for C/C++ and Go development
update_dev_variables() {
    mkdir -p $MY_INSTALL_DIR/bin $MY_REPOS_DIR

    echo '' >>/home/$TARGET_USER/.bashrc
    echo '# to be used as prefix for local installations' >>/home/$TARGET_USER/.bashrc
    echo 'export MY_INSTALL_DIR=~/.local' >>/home/$TARGET_USER/.bashrc
    echo 'export MY_SOURCE_DIR=~/Source' >>/home/$TARGET_USER/.bashrc
    echo 'export MY_REPOS_DIR=~/Source/Repos' >>/home/$TARGET_USER/.bashrc
    echo 'export MY_REMOTE_CONTAINERS_REPOS_DIR=/home/$TARGET_USER/Source/Repos' >>/home/$TARGET_USER/.bashrc

    echo '' >>/home/$TARGET_USER/.bashrc
    echo '# configure Docker' >>/home/$TARGET_USER/.bashrc
    echo 'export DOCKER_HIDE_LEGACY_COMMANDS=ON' >>/home/$TARGET_USER/.bashrc
    echo 'export DOCKER_BUILDKIT=1' >>/home/$TARGET_USER/.bashrc
    echo 'export COMPOSE_DOCKER_CLI_BUILD=1' >>/home/$TARGET_USER/.bashrc

    echo '' >>/home/$TARGET_USER/.bashrc
    echo '# configure path environment variable' >>/home/$TARGET_USER/.bashrc
    echo 'export PATH=$PATH:/usr/local/go/bin' >>/home/$TARGET_USER/.bashrc
}

# install Docker based on given CPU architecture
ubuntu_install_docker() {
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list >/dev/null

    apt-get update

    if [ -z "$1" -o "$1" != "cli_only" ]; then
        apt-get install --yes docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

        systemctl enable docker.service
        systemctl enable containerd.service
        usermod -aG docker $TARGET_USER
    else
        apt-get install --yes docker-ce-cli docker-compose
    fi

    docker buildx install
    cp --recursive /root/.docker /home/$TARGET_USER
}

# -- install functions -------------------------------------------------------------------------------------------------

# bring Ubuntu distribution up to date
apt_install() {
    local CODE_NAME=$(cat /etc/os-release | grep UBUNTU_CODENAME | cut -d '=' -f 2)

    # tools for building software
    apt-get install --yes \
        uuid-dev \
        zlib1g-dev \
        libtool \
        build-essential \
        debconf-utils \
        pkg-config \
        zip \
        unzip \
        autoconf \
        automake \
        gdb \
        ninja-build \
        cmake \
        git \
        clang-tidy \
        clang-format \
        manpages-dev \
        python3-pip \
        python-is-python3 \
        pylint \
        python3-autopep8 \
        gcovr

    # latest GNU C/C++ compiler for Ubuntu 22.04 LTS
    if [ "$CODE_NAME" = "jammy" ]; then
        apt-get install --yes \
            gcc-12 \
            g++-12 \
            gcc-12-locales \
            gcc-12-doc \
            libstdc++-12-doc

        update-alternatives --remove-all gcc || :
        update-alternatives --remove-all cc || :
        update-alternatives --remove-all cpp || :
        update-alternatives --remove-all g++ || :
        update-alternatives --remove-all c++ || :

        update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-12 0
        update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-12 0
        update-alternatives --install /usr/bin/c++ c++ /usr/bin/g++-12 0
        update-alternatives --install /usr/bin/cc cc /usr/bin/gcc-12 0
        update-alternatives --install /usr/bin/cpp cpp /usr/bin/g++-12 0
    fi

    # latest GNU C/C++ compiler for Ubuntu 23.04
    if [ "$CODE_NAME" = "lunar" ]; then
        apt-get install --yes \
            gcc-13 \
            g++-13 \
            gcc-13-locales \
            gcc-13-doc \
            libstdc++-13-doc

        update-alternatives --remove-all gcc || :
        update-alternatives --remove-all cc || :
        update-alternatives --remove-all cpp || :
        update-alternatives --remove-all g++ || :
        update-alternatives --remove-all c++ || :

        update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-13 0
        update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-13 0
        update-alternatives --install /usr/bin/c++ c++ /usr/bin/g++-13 0
        update-alternatives --install /usr/bin/cc cc /usr/bin/gcc-13 0
        update-alternatives --install /usr/bin/cpp cpp /usr/bin/g++-13 0
    fi

    # latest GNU and LLVM C/C++ compilers for Ubuntu 24.04
    if [ "$CODE_NAME" = "noble" ]; then
        apt-get install --yes \
            gcc-14 \
            g++-14 \
            gcc-14-locales \
            gcc-14-doc \
            libstdc++-14-doc \
            clang \
            clang-18 \
            lldb-18 \
            lld-18 \
            libc++-18-dev \
            libc++abi-18-dev

        update-alternatives --remove-all gcc || :
        update-alternatives --remove-all cc || :
        update-alternatives --remove-all cpp || :
        update-alternatives --remove-all g++ || :
        update-alternatives --remove-all c++ || :

        update-alternatives --install /usr/bin/gcc gcc /usr/bin/gcc-14 0
        update-alternatives --install /usr/bin/g++ g++ /usr/bin/g++-14 0
        update-alternatives --install /usr/bin/c++ c++ /usr/bin/g++-14 0
        update-alternatives --install /usr/bin/cc cc /usr/bin/gcc-14 0
        update-alternatives --install /usr/bin/cpp cpp /usr/bin/g++-14 0
    fi

    # tools for building software with Go
    curl -fsSL -o /tmp/go1.22.3.linux-amd64.tar.gz https://golang.org/dl/go1.22.3.linux-amd64.tar.gz
    tar -C /usr/local -xzf /tmp/go1.22.3.linux-amd64.tar.gz
}

# build googletest for given build type
build_googletest() {
    local BUILD_DIR=$MY_SOURCE_DIR/googletest/cmake/build/$1

    cmake -S $MY_SOURCE_DIR/googletest \
        -B $BUILD_DIR \
        -DCMAKE_BUILD_TYPE=$1 \
        -DBUILD_SHARED_LIBS=OFF \
        -DCMAKE_POSITION_INDEPENDENT_CODE=TRUE \
        -DCMAKE_PREFIX_PATH=$MY_INSTALL_DIR/$1 \
        -DCMAKE_MODULE_PATH=$MY_INSTALL_DIR/$1 \
        -DCMAKE_INSTALL_PREFIX=$MY_INSTALL_DIR/$1

    cmake --build $BUILD_DIR -j $(nproc) --target install
}

# build flatbuffers for given build type
build_flatbuffers() {
    local BUILD_DIR=$MY_SOURCE_DIR/flatbuffers/cmake/build/$1

    cmake -S $MY_SOURCE_DIR/flatbuffers \
        -B $BUILD_DIR \
        -DCMAKE_BUILD_TYPE=$1 \
        -DBUILD_SHARED_LIBS=OFF \
        -DCMAKE_POSITION_INDEPENDENT_CODE=TRUE \
        -DCMAKE_PREFIX_PATH=$MY_INSTALL_DIR/$1 \
        -DCMAKE_MODULE_PATH=$MY_INSTALL_DIR/$1 \
        -DCMAKE_INSTALL_PREFIX=$MY_INSTALL_DIR/$1

    cmake --build $BUILD_DIR -j $(nproc) --target install
}

# build fruit for given build type
build_fruit() {
    local BUILD_DIR=$MY_SOURCE_DIR/fruit/cmake/build/$1

    cmake -S $MY_SOURCE_DIR/fruit \
        -B $BUILD_DIR \
        -DCMAKE_BUILD_TYPE=$1 \
        -DFRUIT_USES_BOOST=False \
        -DBUILD_SHARED_LIBS=OFF \
        -DCMAKE_POSITION_INDEPENDENT_CODE=TRUE \
        -DCMAKE_PREFIX_PATH=$MY_INSTALL_DIR/$1 \
    -DCMAKE_MODULE_PATH=$MY_INSTALL_DIR/$1 \
        -DCMAKE_INSTALL_PREFIX=$MY_INSTALL_DIR/$1

    cmake --build $BUILD_DIR -j $(nproc) --target install
}

# build nng for given build type
build_nng() {
    local BUILD_DIR=$MY_SOURCE_DIR/nng/cmake/build/$1

    cmake -S $MY_SOURCE_DIR/nng \
        -B $BUILD_DIR \
        -DCMAKE_BUILD_TYPE=$1 \
        -DBUILD_SHARED_LIBS=OFF \
        -DCMAKE_POSITION_INDEPENDENT_CODE=TRUE \
        -DCMAKE_PREFIX_PATH=$MY_INSTALL_DIR/$1 \
        -DCMAKE_MODULE_PATH=$MY_INSTALL_DIR/$1 \
        -DCMAKE_INSTALL_PREFIX=$MY_INSTALL_DIR/$1

    cmake --build $BUILD_DIR -j $(nproc) --target install
}

# build gRPC for given build type
build_grpc() {
    local BUILD_DIR=$MY_SOURCE_DIR/grpc/cmake/build/$1

    cmake -S $MY_SOURCE_DIR/grpc \
        -B $BUILD_DIR \
        -DCMAKE_BUILD_TYPE=$1 \
        -DgRPC_INSTALL=ON \
        -DgRPC_CARES_PROVIDER=module \
        -DgRPC_PROTOBUF_PROVIDER=module \
        -DgRPC_SSL_PROVIDER=module \
        -DgRPC_ZLIB_PROVIDER=module \
        -DgRPC_ABSL_PROVIDER=module \
        -DBUILD_TESTING=OFF \
        -DgRPC_BUILD_TESTS=OFF \
        -Dprotobuf_BUILD_TESTS=OFF \
        -Dprotobuf_WITH_ZLIB=OFF \
        -DgRPC_BUILD_TESTS=OFF \
        -DgRPC_BUILD_CSHARP_EXT=OFF \
        -DgRPC_BUILD_GRPC_CSHARP_PLUGIN=OFF \
        -DgRPC_BUILD_GRPC_NODE_PLUGIN=OFF \
        -DgRPC_BUILD_GRPC_OBJECTIVE_C_PLUGIN=OFF \
        -DgRPC_BUILD_GRPC_PHP_PLUGIN=OFF \
        -DgRPC_BUILD_GRPC_PYTHON_PLUGIN=OFF \
        -DgRPC_BUILD_GRPC_RUBY_PLUGIN=OFF \
        -DgRPC_USE_PROTO_LITE=OFF \
        -DABSL_PROPAGATE_CXX_STD=ON \
        -DBUILD_SHARED_LIBS=OFF \
        -DCMAKE_POSITION_INDEPENDENT_CODE=TRUE \
        -DCMAKE_PREFIX_PATH=$MY_INSTALL_DIR/$1 \
        -DCMAKE_MODULE_PATH=$MY_INSTALL_DIR/$1 \
        -DCMAKE_INSTALL_PREFIX=$MY_INSTALL_DIR/$1

    cmake --build $BUILD_DIR -j $(nproc) --target install

    local BUILD_DIR=$MY_SOURCE_DIR/grpc/third_party/abseil-cpp/cmake/build/$1

    cmake -S $MY_SOURCE_DIR/grpc/third_party/abseil-cpp \
        -B $BUILD_DIR \
        -DCMAKE_BUILD_TYPE=$1 \
        -DBUILD_TESTING=OFF \
        -DABSL_PROPAGATE_CXX_STD=ON \
        -DBUILD_SHARED_LIBS=OFF \
        -DCMAKE_POSITION_INDEPENDENT_CODE=TRUE \
        -DCMAKE_PREFIX_PATH=$MY_INSTALL_DIR/$1 \
        -DCMAKE_MODULE_PATH=$MY_INSTALL_DIR/$1 \
        -DCMAKE_INSTALL_PREFIX=$MY_INSTALL_DIR/$1

    cmake --build $BUILD_DIR -j $(nproc) --target install
}

# clone all the repos in parallel to speed it up, note the & character
git_all() {
    mkdir -p $MY_INSTALL_DIR/bin $MY_REPOS_DIR

    git config --global credential.helper store
    git config --global advice.detachedHead false
    git config --global status.submoduleSummary true
    cp /root/.gitconfig /home/$TARGET_USER

    # invoke git per project
    for PROJECT_NAME in ${PROJECTS[@]}; do
        eval ${GIT[$PROJECT_NAME]} &
    done

    # wait for all git operations to finish
    wait
}

# build and install all projects
build_all() {
    # the order of building is important because of cross-dependencies
    for BUILD_TYPE in Debug Release; do
        # invoke build functions per project, as convention functions start with build_*
        for PROJECT_NAME in ${PROJECTS[@]}; do
            build_$PROJECT_NAME $BUILD_TYPE
        done
    done
}

# apply ownership permissions to target user
user_group() {
    chown --recursive $TARGET_USER:$TARGET_USER \
        $MY_INSTALL_DIR \
        $MY_SOURCE_DIR \
        /home/$TARGET_USER/.vimrc \
        /home/$TARGET_USER/.bash_aliases

    if [ -d "/home/$TARGET_USER/.docker" ]; then
        chown --recursive $TARGET_USER:$TARGET_USER /home/$TARGET_USER/.docker
    fi

    if [ -f "/home/$TARGET_USER/.gitconfig" ]; then
        chown $TARGET_USER:$TARGET_USER /home/$TARGET_USER/.gitconfig
    fi
}

# final configuration for C++ development
final_config() {
    apt-get purge --yes --auto-remove cmake
    su --command 'pip install --break-system-packages --upgrade pip' $TARGET_USER
    su --command 'pip install --break-system-packages conan cmake coloredlogs cmake_format' $TARGET_USER
    su --login --command 'conan profile detect' $TARGET_USER
}

# -- environment functions ---------------------------------------------------------------------------------------------

# steps to create an Ubuntu based development environment
create_environment() {
    local DEV_ENV=$1
    local DOCKER_INSTALL=$2
    local UGO_SETTINGS=$3

    if [ ${#CREATE_STEPS[@]} -eq 0 ]; then
        local STEPS=false
        echo "Creating Ubuntu $DEV_ENV development environment ..."
    else
        local STEPS=true
        echo "Creating Ubuntu $DEV_ENV development environment with steps '${CREATE_STEPS[*]}' ..."
    fi

    if [ $STEPS = false -o "${CREATE_STEPS[0]}" = "prepare" ]; then
        [ $WHAT_IF = false ] && apt_prepare || echo "apt_prepare"
        [ $WHAT_IF = false ] && ubuntu_user_experience || echo "ubuntu_user_experience"
        [ $WHAT_IF = false ] && update_dev_variables || echo "update_dev_variables"
    fi

    if [ $STEPS = false -o "${CREATE_STEPS[1]}" = "docker" ]; then
        if [ "$DOCKER_INSTALL" = "full" ]; then
            [ $WHAT_IF = false ] && ubuntu_install_docker || echo "ubuntu_install_docker"
        elif [ "$DOCKER_INSTALL" = "cli" ]; then
            [ $WHAT_IF = false ] && ubuntu_install_docker cli_only || echo "ubuntu_install_docker cli_only"
        fi
    fi

    if [ $STEPS = false -o "${CREATE_STEPS[2]}" = "install" ]; then
        [ $WHAT_IF = false ] && apt_install || echo "apt_install"
    fi

    if [ $STEPS = false -o "${CREATE_STEPS[3]}" = "git" ]; then
        [ $WHAT_IF = false ] && git_all || echo "git_all"
    fi

    if [ $STEPS = false -o "${CREATE_STEPS[4]}" = "build" ]; then
        [ $WHAT_IF = false ] && build_all || echo "build_all"
    fi

    if [ $STEPS = false -o "${CREATE_STEPS[5]}" = "finish" ]; then
        if [ "$UGO_SETTINGS" = "on" ]; then
            [ $WHAT_IF = false ] && user_group || echo "user_group"
        fi

        [ $WHAT_IF = false ] && final_config || echo "final_config"
    fi
}

# print out usage information
print_usage() {
    echo "Usage: prepare-linux-dev-env.sh"
    echo "    -u <target user>"
    echo "    [-e <ubuntu_docker | ubuntu_vm | ubuntu_wsl>]"
    echo "    [-s <prepare,docker,install,git,build,finish | '-,-,-,-,-,-'>]"
    echo "    [-p $(echo ${PROJECTS[*]} | sed 's/ /,/g')]"
    echo "    [-w]"
    echo "    [-h]"
}

# print out parameter set
print_parameter_set() {
    echo "Parameter Set:"
    echo "    Target User = '$TARGET_USER'"
    echo "    Target Environment = '$TARGET_ENVIRONMENT'"
    echo "    Create Steps = ${#CREATE_STEPS[@]} steps through '${CREATE_STEPS[*]}'"
    echo "    Projects = '${PROJECTS[*]}'"
    echo "    What If: $WHAT_IF"
}

# -- main script execution path ----------------------------------------------------------------------------------------

# prepare development environment
set -e +u

TARGET_USER='developer'
TARGET_ENVIRONMENT=''
CREATE_STEPS=()
WHAT_IF=false
PRINT_USAGE=false

declare -A -r GIT=(
    [googletest]='git clone -b v1.14.0 https://github.com/google/googletest.git $MY_SOURCE_DIR/googletest'
    [flatbuffers]='git clone -b v24.3.25 https://github.com/google/flatbuffers.git $MY_SOURCE_DIR/flatbuffers'
    [fruit]='git clone -b v3.7.1 https://github.com/google/fruit.git $MY_SOURCE_DIR/fruit'
    [nng]='git clone -b v1.8.0 https://github.com/nanomsg/nng.git $MY_SOURCE_DIR/nng'
    [grpc]='git clone -b v1.63.0 --recurse-submodules --depth 1 --shallow-submodules https://github.com/grpc/grpc $MY_SOURCE_DIR/grpc'
)

declare -a PROJECTS=(${!GIT[@]})

# parse mandatory and optional parameters into shell variables
while getopts "u:e:s:p:wh" ARG; do
    case $ARG in
    u)
        if [ -n "${OPTARG}" ]; then
            TARGET_USER=${OPTARG}
        fi
        ;;

    e)
        TARGET_ENVIRONMENT=${OPTARG}
        ;;

    s)
        IFS=',' read -ra CREATE_STEPS <<<"${OPTARG}"
        ;;

    p)
        IFS=',' read -ra PROJECTS <<<"${OPTARG}"
        ;;

    w)
        WHAT_IF=true
        ;;

    h | *)
        PRINT_USAGE=true
        ;;
    esac
done

MY_INSTALL_DIR=/home/$TARGET_USER/.local
MY_SOURCE_DIR=/home/$TARGET_USER/Source
MY_REPOS_DIR=/home/$TARGET_USER/Source/Repos

if [ $PRINT_USAGE = true ]; then
    print_usage
elif [ "$TARGET_USER" = "root" ]; then
    echo 'Target user cannot be root, nothing applied!'
else
    # print out parameter set for diagnostic purposes
    print_parameter_set

    # identify environment installation target
    case "$TARGET_ENVIRONMENT" in
    "ubuntu_docker")
        create_environment container cli off
        ;;

    "ubuntu_vm")
        create_environment VM full on
        ;;

    "ubuntu_wsl")
        create_environment WSL cli on
        ;;

    *)
        echo 'No supported target environment provided, nothing applied!'
        ;;
    esac
fi

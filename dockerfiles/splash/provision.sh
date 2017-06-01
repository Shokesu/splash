#!/bin/bash

usage() {
    cat <<EOF
Splash docker image provisioner.

Usage: $0 COMMAND [ COMMAND ... ]

Available commands:
usage -- print this message
prepare_install -- prepare image for installation
install_deps -- install general system-level dependencies
install_qtwebkit_deps -- install Qt and WebKit dependencies
install_qtwebkit -- install updated WebKit for QT
install_pyqt5 -- install PyQT5 from sources
install_python_deps -- install python packages
install_msfonts -- agree with EULA and install Microsoft fonts
install_extra_fonts -- install extra fonts
install_flash -- install flash plugin
remove_builddeps -- WARNING: only for Docker! Remove build-dependencies.
remove_extra -- WARNING: only for Docker! Eemove files that are not necessary to run Splash.

EOF
}

env | grep SPLASH

SPLASH_SIP_VERSION=${SPLASH_SIP_VERSION:-"4.19.2"}
SPLASH_PYQT_VERSION=${SPLASH_PYQT_VERSION:-"5.8.2"}
SPLASH_BUILD_PARALLEL_JOBS=${SPLASH_BUILD_PARALLEL_JOBS:-"1"}

# '2' is not supported by this script; allowed values are "3" and "venv" (?).
SPLASH_PYTHON_VERSION=${SPLASH_PYTHON_VERSION:-"3"}

if [[ ${SPLASH_PYTHON_VERSION} == "venv" ]]; then
    _PYTHON=python
else
    _PYTHON=python${SPLASH_PYTHON_VERSION}
fi

_activate_venv () {
    if [[ ${SPLASH_PYTHON_VERSION} == "venv" ]]; then
        source ${VIRTUAL_ENV}/bin/activate
    fi
}

prepare_install () {
    # Prepare docker image for installation of packages, docker images are
    # usually stripped and apt-get doesn't work immediately.
    #
    # python-software-properties contains "add-apt-repository" command for PPA conf
    sed 's/main$/main universe/' -i /etc/apt/sources.list && \
    apt-get update -q && \
    apt-get install -y --no-install-recommends \
        curl \
        wget \
        software-properties-common \
        apt-transport-https \
        python3-software-properties
}

install_deps () {
    # Install system dependencies for Qt, Python packages, etc.
    # ppa:pi-rho/security is a repo for libre2-dev
    add-apt-repository -y ppa:pi-rho/security && \
    apt-get update -q && \
    apt-get install -y --no-install-recommends \
        python3 \
        python3-dev \
        python3-pip \
        build-essential \
        libre2-dev \
        liblua5.2-dev \
        libsqlite3-dev \
        zlib1g \
        zlib1g-dev \
        netbase \
        ca-certificates \
        pkg-config
}

install_qtwebkit_deps () {
    apt-get install -y --no-install-recommends \
        xvfb \
        libjpeg-turbo8-dev \
        libgl1-mesa-dev \
        libglu1-mesa-dev \
        mesa-common-dev \
        libfontconfig1-dev \
        libicu-dev \
        libpng12-dev \
        libxslt1-dev \
        libxml2-dev \
        libhyphen-dev \
        libgbm1 \
        libxcb-image0 \
        libxcb-icccm4 \
        libxcb-keysyms1 \
        libxcb-render-util0 \
        libxi6 \
        libxcomposite-dev \
        libxrender-dev \
        libgstreamer1.0-dev \
        libgstreamer-plugins-base1.0-dev \
        rsync
}

_ensure_folders () {
    mkdir -p /downloads && \
    mkdir -p /builds && \
    chmod a+rw /downloads && \
    chmod a+rw /builds
}

install_official_qt () {
    # XXX: if qt version is changed, Dockerfile should be updated,
    # as well as qt-installer-noninteractive.qs script.
    _ensure_folders && \
    pushd downloads && \
    wget http://download.qt.io/official_releases/qt/5.8/5.8.0/qt-opensource-linux-x64-5.8.0.run && \
    popd && \
    chmod +x /downloads/qt-opensource-linux-x64-5.8.0.run && \
    xvfb-run /downloads/qt-opensource-linux-x64-5.8.0.run \
        --script /tmp/script.qs \
        | egrep -v '\[[0-9]+\] Warning: (Unsupported screen format)|((QPainter|QWidget))'
}


install_qtwebkit () {
    # Install webkit from https://github.com/annulen/webkit
    _ensure_folders && \
    curl -L -o /downloads/qtwebkit.tar.xz https://github.com/annulen/webkit/releases/download/qtwebkit-tp5/qtwebkit-tp5-qt58-linux-x64.tar.xz && \
    pushd /builds && \
    tar xvfJ /downloads/qtwebkit.tar.xz --keep-newer-files && \
    rsync -aP /builds/qtwebkit-tp5-qt58-linux-x64/* `qmake -query QT_INSTALL_PREFIX`
}


install_pyqt5 () {
    _ensure_folders && \
    _activate_venv && \
    ${_PYTHON} --version && \
    curl -L -o /downloads/sip.tar.gz https://sourceforge.net/projects/pyqt/files/sip/sip-${SPLASH_SIP_VERSION}/sip-${SPLASH_SIP_VERSION}.tar.gz && \
    curl -L -o /downloads/pyqt5.tar.gz https://sourceforge.net/projects/pyqt/files/PyQt5/PyQt-${SPLASH_PYQT_VERSION}/PyQt5_gpl-${SPLASH_PYQT_VERSION}.tar.gz
    ls -lh /downloads && \
    # TODO: check downloads
    pushd /builds && \
    # SIP
    tar xzf /downloads/sip.tar.gz --keep-newer-files  && \
    pushd sip-${SPLASH_SIP_VERSION}  && \
    ${_PYTHON} configure.py  && \
    make -j ${SPLASH_BUILD_PARALLEL_JOBS} && \
    make install  && \
    popd  && \
    # PyQt5
    tar xzf /downloads/pyqt5.tar.gz --keep-newer-files  && \
    pushd PyQt5_gpl-${SPLASH_PYQT_VERSION}  && \
#        --qmake "${SPLASH_QT_PATH}/bin/qmake" \
    ${_PYTHON} configure.py -c \
        --verbose \
        --confirm-license \
        --no-designer-plugin \
        --no-qml-plugin \
        --no-python-dbus \
        -e QtCore \
        -e QtGui \
        -e QtWidgets \
        -e QtNetwork \
        -e QtWebKit \
        -e QtWebKitWidgets \
        -e QtSvg \
        -e QtPrintSupport && \
    make -j ${SPLASH_BUILD_PARALLEL_JOBS} && \
    make install && \
    popd  && \
    # Builds Complete
    popd
}

install_python_deps () {
    # Install python-level dependencies.
    _activate_venv && \
    ${_PYTHON} -m pip install -U pip setuptools six && \
    ${_PYTHON} -m pip install \
        qt5reactor==0.3 \
        psutil==5.0.0 \
        Twisted==16.1.1 \
        adblockparser==0.7 \
        xvfbwrapper==0.2.8 \
        funcparserlib==0.3.6 \
        Pillow==3.4.2 \
        lupa==1.3 && \
    ${_PYTHON} -m pip install https://github.com/sunu/pyre2/archive/c610be52c3b5379b257d56fc0669d022fd70082a.zip#egg=re2
}

install_msfonts() {
    # Agree with EULA and install Microsoft fonts
#    apt-add-repository -y "deb http://archive.ubuntu.com/ubuntu xenial multiverse" && \
#    apt-add-repository -y "deb http://archive.ubuntu.com/ubuntu xenial-updates multiverse" && \
#    apt-get update && \
    echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | debconf-set-selections && \
    apt-get install --no-install-recommends -y ttf-mscorefonts-installer
}

install_extra_fonts() {
    # Install extra fonts (Chinese and other)
    apt-get install --no-install-recommends -y \
        fonts-liberation \
        ttf-wqy-zenhei \
        fonts-arphic-gbsn00lp \
        fonts-arphic-bsmi00lp \
        fonts-arphic-gkai00mp \
        fonts-arphic-bkai00mp
}

install_flash () {
    apt-add-repository -y "deb http://archive.ubuntu.com/ubuntu trusty multiverse" && \
    apt-get update && \
    apt-get install -y flashplugin-installer
}

remove_builddeps () {
    # WARNING: only for Docker, don't run blindly!
    # Uninstall build dependencies.
    apt-get remove -y --purge \
        python3-dev \
        libpython3.5-dev \
        libpython3.5 \
        libpython3.5-dev \
        build-essential \
        libre2-dev \
        liblua5.2-dev \
        zlib1g-dev \
        libc-dev \
        libjpeg-turbo8-dev \
        libcurl3 \
        gcc cpp cpp-5 binutils perl rsync && \
    apt-get clean -y
}

remove_extra () {
    # WARNING: only for Docker, don't run blindly!
    # Remove unnecessary files.
    rm -rf \
        /builds \
        /downloads \
        /opt/qt58/Docs \
        /opt/qt58/Tools \
        /opt/qt58/Examples
#        /usr/share/man \
#        /usr/share/info \
#        /usr/share/doc
#        /var/lib/apt/lists/*
}

if [ \( $# -eq 0 \) -o \( "$1" = "-h" \) -o \( "$1" = "--help" \) ]; then
    usage
    exit 1
fi

UNKNOWN=0
for cmd in "$@"; do
    if [ "$(type -t -- "$cmd")" != "function" ]; then
        echo "Unknown command: $cmd"
        UNKNOWN=1
    fi
done

if [ $UNKNOWN -eq 1 ]; then
    echo "Unknown commands encountered, exiting..."
    exit 1
fi

while [ $# -gt 0 ]; do
    echo "Executing command: $1"
    "$1" || { echo "Command failed (exitcode: $?), exiting..."; exit 1; }
    shift
done

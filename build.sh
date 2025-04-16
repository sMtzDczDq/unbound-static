#!/usr/bin/env bash
set -x

# Set ENV
if [[ ! -f ./env.rc ]]; then
  echo "Cannot find \`env.rc\` file."
  exit 1
else
  source ./env.rc
fi
declare -a missing_pkgs
for pkg in "${required_pkgs[@]}"; do
  pkgman() { apk info -e "${pkg}"; }
  #  if pkgman > /dev/null 2>&1; then
  if pkgman > /dev/null 2>&1; then
    printf "\033[1;36mFound %s\033[0m\n" "$pkg"
  else
    printf "\033[1;31mCould not find %s\033[0m\n" "$pkg"
    missing_pkgs+=("$pkg")
  fi
done
if [ ${#missing_pkgs[@]} -gt 0 ]; then
  printf 'Missing packages %s\n' "${missing_pkgs[*]}"
  if read -r -s -n 1 -t 10 -p "Will install missing packages. Press any key within 10 seconds to abort"; then
    echo "aborted"
    exit
  else
    if ! (doas apk update && doas apk add "${missing_pkgs[@]}"); then
      echo -e "\e[1;31mInstalling missing packages failed.\e[0m"
      exit 1
    fi
  fi
fi
# Check Version
UNBOUND_VERSION=$(curl -s -m 10 "https://api.github.com/repos/NLnetLabs/unbound/releases/latest" | grep "tag_name" | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g;s/release-//g')
if [ -z "$UNBOUND_VERSION" ]; then
  echo -e "\e[1;31mFailed to get UNBOUND latest version.\e[0m" && exit 1
fi

WORK_PATH=$(pwd)
mkdir -p "$WORK_PATH"/static_build/extra && cd "$WORK_PATH"/static_build || exit
TOP=$(pwd)

# download source code
unbound_source() {
  wget https://nlnetlabs.nl/downloads/unbound/unbound-"$UNBOUND_VERSION".tar.gz
  tar -zxf unbound-"$UNBOUND_VERSION".tar.gz && rm -f unbound-"$UNBOUND_VERSION".tar.gz
}

openssl_source() {
  if ! [ "$OPENSSL" = "$OPENSSL_VERSION" ]; then
    wget https://www.openssl.org/source/openssl-"$OPENSSL_VERSION".tar.gz
    tar -zxf openssl-"$OPENSSL_VERSION".tar.gz && rm -f openssl-"$OPENSSL_VERSION".tar.gz
  else
    printf "\033[1;32mFound openssl %s skipping download\033[0m\n" "$OPENSSL_VERSION"
  fi
}

libsodium_source() {
  if ! [ "$LIBSODIUM" = "$LIBSODIUM_VERSION" ]; then
    wget https://download.libsodium.org/libsodium/releases/libsodium-"$LIBSODIUM_VERSION".tar.gz
    mkdir libsodium-"$LIBSODIUM_VERSION" && tar -zxf libsodium-"$LIBSODIUM_VERSION".tar.gz -C libsodium-"$LIBSODIUM_VERSION" && rm -f libsodium-"$LIBSODIUM_VERSION".tar.gz
  else
    printf "\033[1;32mFound libsodium %s skipping download\033[0m\n" "$LIBSODIUM_VERSION"
  fi
}

libmnl_source() {
  if ! [ "$LIBMNL" = "$LIBMNL_VERSION" ]; then
    #  git clone git://git.netfilter.org/libmnl --depth=1 -b libmnl-"$LIBMNL_VERSION" libmnl-"$LIBMNL_VERSION"
    wget https://www.netfilter.org/pub/libmnl/libmnl-"$LIBMNL_VERSION".tar.bz2
    tar -xf libmnl-"$LIBMNL_VERSION".tar.bz2 && rm -f libmnl-"$LIBMNL_VERSION".tar.bz2
  else
    printf "\033[1;32mFound libmnl %s skipping download\033[0m\n" "$LIBMNL_VERSION"
  fi
}

libhiredis_source() {
  if ! [ "$LIBHIREDIS" = "$LIBHIREDIS_VERSION" ]; then
    wget https://github.com/redis/hiredis/archive/refs/tags/v"$LIBHIREDIS_VERSION".tar.gz -O hiredis-"$LIBHIREDIS_VERSION".tar.gz
    tar -zxf hiredis-"$LIBHIREDIS_VERSION".tar.gz && rm -f hiredis-"$LIBHIREDIS_VERSION".tar.gz
  else
    printf "\033[1;32mFound libhiredis %s skipping download\033[0m\n" "$LIBHIREDIS_VERSION"
  fi
}

libevent_source() {
  if ! [ "$LIBEVENT" = "$LIBEVENT_VERSION" ]; then
    wget https://github.com/libevent/libevent/releases/download/release-"$LIBEVENT_VERSION"/libevent-"$LIBEVENT_VERSION".tar.gz
    tar -zxf libevent-"$LIBEVENT_VERSION".tar.gz && rm -f libevent-"$LIBEVENT_VERSION".tar.gz
  else
    printf "\033[1;32mFound libevent %s skipping download\033[0m\n" "$LIBEVENT_VERSION"
  fi
}

nghttp2_source() {
  if ! [ "$NGHTTP2" = "$NGHTTP2_VERSION" ]; then
    wget https://github.com/nghttp2/nghttp2/releases/download/v"$NGHTTP2_VERSION"/nghttp2-"$NGHTTP2_VERSION".tar.gz
    tar -zxf nghttp2-"$NGHTTP2_VERSION".tar.gz && rm -f nghttp2-"$NGHTTP2_VERSION".tar.gz
  else
    printf "\033[1;32mFound nghttp2 %s skipping download\033[0m\n" "$NGHTTP2_VERSION"
  fi
}

expat_source() {
  if ! [ "$EXPAT" = "$EXPAT_SOURCE" ]; then
    wget https://github.com/libexpat/libexpat/releases/download/R_"${EXPAT_SOURCE//./_}"/expat-"$EXPAT_SOURCE".tar.gz
    tar -zxf expat-"$EXPAT_SOURCE".tar.gz && rm -f expat-"$EXPAT_SOURCE".tar.gz
  else
    printf "\033[1;32mFound expat %s skipping download\033[0m\n" "$EXPAT_SOURCE"
  fi
}

cd "$TOP"/extra || exit
if [ -f "$TOP/extra/.progress" ]; then
  #shellcheck disable=1091
  source "$TOP/extra/.progress"
fi

openssl_source || {
  echo -e "\e[1;31mdownload openssl failed.\e[0m"
  exit 1
}
libsodium_source || {
  echo -e "\e[1;31mdownload libsodium failed.\e[0m"
  exit 1
}
libmnl_source || {
  echo -e "\e[1;31mdownload libmnl failed.\e[0m"
  exit 1
}
libhiredis_source || {
  echo -e "\e[1;31mdownload libhiredis failed.\e[0m"
  exit 1
}
libevent_source || {
  echo -e "\e[1;31mdownload libevent failed.\e[0m"
  exit 1
}
nghttp2_source || {
  echo -e "\e[1;31mdownload nghttp2 failed.\e[0m"
  exit 1
}
expat_source || {
  echo -e "\e[1;31mdownload expat failed.\e[0m"
  exit 1
}
cd "$TOP" || exit
unbound_source || {
  echo -e "\e[1;31mdownload unbound failed.\e[0m"
  exit 1
}

# build openssl
if ! [ "$OPENSSL" = "$OPENSSL_VERSION" ]; then
  cd "$TOP"/extra/openssl-"$OPENSSL_VERSION" || exit
  ./config --prefix="$TOP"/extra/openssl no-shared CC=clang CXX=clang++
  if ! make -j$(($(nproc --all) + 1)); then
    echo -e "\n\e[1;31mOpenSSL compilation failed.\e[0m\n"
    exit 1
  else
    make install_sw
    echo "OPENSSL=$OPENSSL_VERSION" >> "$TOP/extra/.progress"
  fi
else
  printf "\033[1;32mFound openssl %s skipping compilation\033[0m\n" "$OPENSSL_VERSION"
fi
export PKG_CONFIG_PATH=$TOP/extra/openssl/lib64/pkgconfig
#read -r -n 1
# build libsodium
if ! [ "$LIBSODIUM" = "$LIBSODIUM_VERSION" ]; then
  cd "$TOP"/extra/libsodium-"$LIBSODIUM_VERSION"/libsodium-stable || exit
  ./configure --prefix="$TOP"/extra/libsodium --disable-shared --enable-static CC=clang CXX=clang++
  if ! make -j$(($(nproc --all) + 1)); then
    echo -e "\n\e[1;31mlibsodium compilation failed.\e[0m\n"
    exit 1
  else
    make install
    echo "LIBSODIUM=$LIBSODIUM_VERSION" >> "$TOP/extra/.progress"
  fi
else
  printf "\033[1;32mFound libsodium %s skipping compilation\033[0m\n" "$LIBSODIUM_VERSION"
fi

# build libmnl
if ! [ "$LIBMNL" = "$LIBMNL_VERSION" ]; then
  cd "$TOP"/extra/libmnl-"$LIBMNL_VERSION" || exit
  #./autogen.sh && ./configure --prefix="$TOP"/extra/libmnl --disable-shared --enable-static CC=clang CXX=clang++
  ./configure --prefix="$TOP"/extra/libmnl --disable-shared --enable-static CC=clang CXX=clang++
  if ! make -j$(($(nproc --all) + 1)); then
    echo -e "\n\e[1;31mlibmnl compilation failed.\e[0m\n"
    exit 1
  else
    make install
    echo "LIBMNL=$LIBMNL_VERSION" >> "$TOP/extra/.progress"
  fi
else
  printf "\033[1;32mFound libmnl %s skipping compilation\033[0m\n" "$LIBMNL_VERSION"
fi

# build libhiredis
if ! [ "$LIBHIREDIS" = "$LIBHIREDIS_VERSION" ]; then
  cd "$TOP"/extra/hiredis-"$LIBHIREDIS_VERSION" || exit
  mkdir build && cd build || exit
  CC=clang CXX=clang++ cmake \
    -DCMAKE_INSTALL_PREFIX="$TOP"/extra/libhiredis \
    -DENABLE_SSL=ON \
    -DENABLE_EXAMPLES=ON \
    -DOPENSSL_ROOT_DIR="$TOP/extra/openssl" \
    ..
  if ! make -j$(($(nproc --all) + 1)); then
    echo -e "\n\e[1;31mlibhiredis compilation failed.\e[0m\n"
    exit 1
  else
    make install
    [ -d "$TOP"/extra/libhiredis/lib64 ] && ln -s "$TOP"/extra/libhiredis/lib64 "$TOP"/extra/libhiredis/lib
    echo "LIBHIREDIS=$LIBHIREDIS_VERSION" >> "$TOP/extra/.progress"
  fi
else
  printf "\033[1;32mFound libhiredis %s skipping compilation\033[0m\n" "$LIBHIREDIS_VERSION"
fi
export PKG_CONFIG_PATH=$TOP/extra/libhiredis/lib/pkgconfig:$PKG_CONFIG_PATH
#read -r -n 1
# build libevent
if ! [ "$LIBEVENT" = "$LIBEVENT_VERSION" ]; then
  cd "$TOP"/extra/libevent-"$LIBEVENT_VERSION" || exit
  ./configure --prefix="$TOP"/extra/libevent --disable-shared --enable-static CC=clang CXX=clang++
  if ! make -j$(($(nproc --all) + 1)); then
    echo -e "\n\e[1;31mlibevent compilation failed.\e[0m\n"
    exit 1
  else
    make install
    echo "LIBEVENT=$LIBEVENT_VERSION" >> "$TOP/extra/.progress"
  fi
else
  printf "\033[1;32mFound libevent %s skipping compilation\033[0m\n" "$LIBEVENT_VERSION"
fi

# build nghttp2
if ! [ "$NGHTTP2" = "$NGHTTP2_VERSION" ]; then
  cd "$TOP"/extra/nghttp2-"$NGHTTP2_VERSION" || exit
  ./configure \
    --prefix="$TOP"/extra/libnghttp2 \
    --disable-shared \
    --enable-static \
    CC=clang CXX=clang++
  if ! make -j$(($(nproc --all) + 1)); then
    echo -e "\n\e[1;31mnghttp2 compilation failed.\e[0m\n"
    exit 1
  else
    make install
    echo "NGHTTP2=$NGHTTP2_VERSION" >> "$TOP/extra/.progress"
  fi
else
  printf "\033[1;32mFound nghttp2 %s skipping compilation\033[0m\n" "$NGHTTP2_VERSION"
fi

# build expat
if ! [ "$EXPAT" = "$EXPAT_SOURCE" ]; then
  cd "$TOP"/extra/expat-"$EXPAT_SOURCE" || exit
  ./configure --prefix="$TOP"/extra/expat --without-docbook CC=clang CXX=clang++
  if ! make -j$(($(nproc --all) + 1)); then
    echo -e "\n\e[1;31mexpat compilation failed.\e[0m\n"
    exit 1
  else
    make install
    echo "EXPAT=$EXPAT_SOURCE" >> "$TOP/extra/.progress"
  fi
else
  printf "\033[1;32mFound expat %s skipping compilation\033[0m\n" "$EXPAT_SOURCE"
fi
export PKG_CONFIG_PATH=$TOP/extra/expat/lib/pkgconfig:$PKG_CONFIG_PATH
# -r -n 1
# build unbound
cd "$TOP"/unbound-* || exit
make clean > /dev/null 2>&1
./configure \
  --disable-rpath \
  --disable-shared \
  --enable-cachedb \
  --enable-dnscrypt \
  --enable-fully-static \
  --enable-ipsecmod \
  --enable-ipset \
  --enable-pie \
  --enable-subnet \
  --enable-tfo-client \
  --enable-tfo-server \
  --prefix="$INSTALL_DIR"/unbound \
  --with-chroot-dir="" \
  --with-libevent="$TOP/extra/libevent" \
  --with-libhiredis="$TOP/extra/libhiredis" \
  --with-libmnl="$TOP/extra/libmnl" \
  --with-libnghttp2="$TOP/extra/libnghttp2" \
  --with-libsodium="$TOP/extra/libsodium" \
  --with-libexpat="$TOP/extra/expat" \
  --with-run-dir="" \
  --with-ssl="$TOP/extra/openssl" \
  --with-username="" \
  CFLAGS="-Ofast -funsafe-math-optimizations -ffinite-math-only -fno-rounding-math -fexcess-precision=fast -funroll-loops -ffunction-sections -fdata-sections -pipe" \
  CC=clang CXX=clang++

if make -j$(($(nproc --all) + 1)); then
  #make -j$(($(nproc --all)+1))
  #if [ $? -eq 0 ]; then
  rm -rf "$INSTALL_DIR"/unbound
  doas make install
  doas llvm-strip "$INSTALL_DIR"/unbound/sbin/unbound* > /dev/null 2>&1
  echo -e " \n\e[1;32munbound-static-$UNBOUND_VERSION compilation success\e[0m\n"
  "$INSTALL_DIR"/unbound/sbin/unbound -V
  pushd "$INSTALL_DIR" || exit
  mkdir -p "$WORK_PATH"/build_out
  tar -Jcf "$WORK_PATH"/build_out/unbound-static-"$UNBOUND_VERSION"-linux-x"$(getconf LONG_BIT)".tar.xz unbound
  tar -zcf "$WORK_PATH"/build_out/unbound-static-"$UNBOUND_VERSION"-linux-x"$(getconf LONG_BIT)".tar.gz unbound
  7z -mx=9 a "$WORK_PATH"/build_out/unbound-static-"$UNBOUND_VERSION"-linux-x"$(getconf LONG_BIT)".7z unbound
  popd || exit
  cd "$WORK_PATH"/build_out && sha256sum ./* > sha256sum.txt
else
  echo -e "\n\e[1;31munbound compilation failed.\e[0m\n"
  #  env 2>&1 env.txt
  exit 1
fi
# export TOP="/home/mitch/unbound-static/static_build"
#export PKG_CONFIG_PATH=$TOP/extra/expat/lib/pkgconfig:$TOP/extra/libhiredis/lib/pkgconfig:$TOP/extra/openssl/lib64/pkgconfig:$PKG_CONFIG_PATH

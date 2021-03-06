#!/bin/bash

set -xe

GNUMAKEFLAGS="-j$(nproc)"

run=$1
where_to_exit=$2
work_dir=$(pwd -P)

# From https://github.com/facebook/proxygen/tree/master/build/deps/github_hashes/facebook
wangel_rev=33d84df82ba2681eb21551346802ec7dc21c7785

good_fbthrift_tag='v2021.04.19.00'
folly_rev=$(curl -s -k "https://raw.githubusercontent.com/facebook/fbthrift/${good_fbthrift_tag}/build/deps/github_hashes/facebook/folly-rev.txt" | awk '{ print $3 } ')
wangle_rev=$(curl -s -k "https://raw.githubusercontent.com/facebook/fbthrift/${good_fbthrift_tag}/build/deps/github_hashes/facebook/wangle-rev.txt" | awk '{ print $3 } ')

should_exit() {
  if [ "$where_to_exit" = "$1" ]; then
  exit 0
  fi
}

function add_glog_cmake_dep() {
  set -xe
  path=$1
  cmake_file=${path}/CMakeLists.txt
  head=$(grep -n 'find_package' $cmake_file | head -n1 | cut -d':' -f1)
  total=$(wc -l $cmake_file | cut -d' ' -f1)
  tail=$((total - head))
  tmp_file=/tmp/.xxxxx.cmake
  head -n${head} $cmake_file > $tmp_file
  echo 'find_package(glog REQUIRED CONFIG NAMES google-glog glog)' >> $tmp_file
  tail -n${tail} $cmake_file >> $tmp_file
  mv -f $tmp_file $cmake_file
}

function git_clone() {
  repo=$1
  name=$(echo $repo | sed 's#.*/\([^/.]\+\).git$#\1#;')
  git clone $repo || (
      cd $name &&
      git pull &&
      cd ..
  ) || true
}

function build_folly_so() {
  git_clone https://github.com/facebook/folly.git
  cd folly

  # add -fPIC to CMake/FollyCompilerUnix.cmake
  sed -i 's/-fsigned-char/-fsigned-char -fPIC/;' CMake/FollyCompilerUnix.cmake

  # build and install libfolly.so
  rm -fr CMakeCache.txt
  cmake configure . -DBUILD_SHARED_LIBS=ON
  make -j $(nproc)
  sudo make install
  cd ..
}

echo "try "rm /usr/local/lib/libfolly.so" if there are undefined folly functions"

if [ "$run" = "apt" ]; then run=""; fi
if [ "$run" = "" ]; then
  yes Y | sudo apt install \
      krb5-user \
      libsodium-dev \
      libboost-all-dev \
      libevent-dev \
      libdouble-conversion-dev \
      libgoogle-glog-dev \
      libgflags-dev \
      libiberty-dev \
      liblz4-dev \
      liblzma-dev \
      libsnappy-dev \
      zlib1g-dev \
      binutils-dev \
      libjemalloc-dev \
      libssl-dev \
      pkg-config \
      bison \
      flex \
      libboost-all-dev \
      libunwind8-dev \
      libelf-dev \
      libdwarf-dev
fi

if [ "$run" = "sodim" ]; then run=""; fi
if [ "$run" = "" ]; then
  cd $work_dir
  wget https://download.libsodium.org/libsodium/releases/LATEST.tar.gz
  tar xvf LATEST.tar.gz
  cd libsodium-stable
  ./configure
  make && make check
  sudo make install
  # rm -fr libsodium-stable
fi

if [ "$run" = "jemalloc" ]; then run=""; fi
if [ "$run" = "" ]; then
  cd $work_dir
  git_clone https://github.com/jemalloc/jemalloc.git
  cd jemalloc
  ./autogen.sh
  make
  touch doc/jemalloc.html
  touch doc/jemalloc.3
  sudo make install
fi

if [ "$run" = "zlib" ]; then run=""; fi
if [ "$run" = "" ]; then
  cd $work_dir
  wget https://zlib.net/zlib-1.2.11.tar.gz
  tar xvf zlib-1.2.11.tar.gz
  cd zlib-1.2.11
  ./configure
  make
  sudo make install
fi

if [ "$run" = "curl" ]; then run=""; fi
if [ "$run" = "" ]; then
  cd $work_dir
  wget https://curl.haxx.se/download/curl-7.59.0.tar.gz
  tar xvf curl-7.59.0.tar.gz
  cd curl-7.59.0/
  cmake .
  make
  sudo make install
fi

if [ "$run" = "mstch" ]; then run=""; fi
if [ "$run" = "" ]; then
  cd $work_dir
  git_clone https://github.com/no1msd/mstch.git
  cd mstch
  mkdir build || true
  cd build
  cmake ..
  make
  sudo make install
  make clean
fi

if [ "$run" = "double" ]; then run=""; fi
if [ "$run" = "" ]; then
  if  ! sudo apt-get install -y libdouble-conversion-dev; then
    if [ ! -e double-conversion ]; then
      echo "Fetching double-conversion from git (apt-get failed)"
      cd $work_dir
      git_clone https://github.com/floitsch/double-conversion.git
      (
        cd double-conversion
        cmake . -DBUILD_SHARED_LIBS=OFF
        sudo make install
      )
    fi
  fi
fi

if [ "$run" = "gflags" ]; then run=""; fi
if [ "$run" = "" ]; then
  cd $work_dir
  git_clone https://github.com/gflags/gflags.git
  cd gflags
  cmake . && make && sudo make install
  rm -fr CMakeCache.txt && cmake . -DBUILD_SHARED_LIBS=OFF && make && sudo make install
  make clean
  should_exit gflags
fi

if [ "$run" = "glog" ]; then run=""; fi
if [ "$run" = "" ]; then
  cd $work_dir
  git_clone https://github.com/google/glog.git
  cd glog
  cmake . && make && sudo make install
  rm -fr CMakeCache.txt && cmake . -DBUILD_SHARED_LIBS=OFF && make && sudo make install
fi

if [ "$run" = "gtest" ]; then run=""; fi
if [ "$run" = "" ]; then
  cd $work_dir
  git_clone http://github.com/google/googletest
  cd googletest
  cmake . && make && sudo make install
fi

if [ "$run" = "fmt" ]; then run=""; fi
if [ "$run" = "" ]; then
  cd $work_dir
  git_clone https://github.com/fmtlib/fmt.git
  cd fmt
  git checkout ${good_fbthrift_tag} || true
  cmake .
  make
  sudo make install

  # rm -fr ${work_dir}/fmt
  should_exit fmt
fi


if [ "$run" = "folly" ]; then run=""; fi
if [ "$run" = "" ]; then
  cd $work_dir
  git_clone https://github.com/facebook/folly.git
  cd folly
  git checkout ${folly_rev}

  rm -fr CMakeCache.txt
  cmake configure . -DBUILD_SHARED_LIBS=OFF -DCMAKE_POSITIOFF_INDEPENDENT_CODE=OFF
  make -j $(nproc)
  sudo make install

  # rm -fr ${work_dir}/folly
  should_exit folly
fi

if [ "$run" = "fizz" ]; then run=""; fi
if [ "$run" = "" ]; then
  cd $work_dir
  git_clone https://github.com/facebookincubator/fizz.git
  cd fizz
  git checkout ${good_fbthrift_tag} || true

  mkdir build_ || true
  cd build_
  add_glog_cmake_dep ../fizz
  cmake ../fizz -DBUILD_TESTS=OFF
  make
  sudo make install
fi

if [ "$run" = "zstd" ]; then run=""; fi
if [ "$run" = "" ]; then
  cd $work_dir
  git_clone https://github.com/facebook/zstd.git
  cd zstd
  git checkout ${good_fbthrift_tag} || true
  make && sudo make install && cd ..

  # rm -fr ${work_dir}/zstd
  should_exit zstd
fi
  

if [ "$run" = "rsocket" ]; then run=""; fi
if [ "$run" = "" ]; then
  cd $work_dir
  git_clone https://github.com/rsocket/rsocket-cpp.git
  cd rsocket-cpp
  git checkout ${good_fbthrift_tag} || true

  mkdir -p build  || true
  cd build
  add_glog_cmake_dep ..
  # Append '-ldl -levent -lboost_context -ldouble-conversion -lgflags -lboost_regex' after '-fuse-ld=' in CMakeList.txt
  cmake ../
  make -d
  sudo make install
  # ./tests

  # rm -fr ${work_dir}/rsocket-cpp
  should_exit rsocket
fi

if [ "$run" = "wangle" ]; then run=""; fi
if [ "$run" = "" ]; then
  cd $work_dir
  git_clone https://github.com/facebook/wangle.git
  cd wangle/wangle
  git checkout ${wangle_rev}
  add_glog_cmake_dep .
  cmake configure . -DBUILD_SHARED_LIBS=OFF -DCMAKE_POSITIOFF_INDEPENDENT_CODE=OFF
  make
  # ctest
  sudo make install
  # rm -fr ${work_dir}/wangle
  should_exit wangle
fi
  
if [ "$run" = "fbthrift" ]; then run=""; fi
if [ "$run" = "" ]; then
  cd $work_dir
  git_clone https://github.com/facebook/fbthrift.git
  root_dir=$PWD
  cd fbthrift
  git co ${good_fbthrift_tag}
  add_glog_cmake_dep .
  cmake configure . -DBUILD_SHARED_LIBS=OFF -DCMAKE_POSITIOFF_INDEPENDENT_CODE=OFF -DCXX_STD=c++14
  for f in $(find .); do if grep -q 'gnu++11' $f 2> /dev/null; then sudo sed -i 's/gnu++11/c++14/g' $f; fi;  done
  # cd thrift/lib/cpp2/transport/rsocket/
  # thrift1 --templates /usr/local/include/thrift/templates -gen py:json,thrift_library -gen mstch_cpp2:enum_strict,frozen2,json -o . Config.thrift
  cd $root_dir
  cd fbthrift
  make -j $(nproc)
  sudo make install
  cd -
  cd fbthrift/thrift/lib/py
  sudo python setup.py install
#  cd -
#  cd fbthrift/thrift/test/py
#  python -m test
#  cd -
  # Installed libthrift* and libprotocol, libtransport, and e.t.c.
  # rm -fr ${work_dir}/fbthrift
  should_exit fbthrift
fi

exit 0

if [ "$where_to_exit" = "proxygen" ]; then
  cd $work_dir
  yes Y | sudo apt-get install gperf unzip
  git_clone https://github.com/facebook/proxygen.git
  cd proxygen/proxygen
  autoreconf -ivf
  ./configure
  make
  sudo make install

  # If you ever happen to want to link against installed libraries
  # in a given directory, LIBDIR, you must either use libtool, and
  # specify the full pathname of the library, or use the '-LLIBDIR'
  # flag during linking and do at least one of the following:
  #    - add LIBDIR to the 'LD_LIBRARY_PATH' environment variable
  #      during execution
  #    - add LIBDIR to the 'LD_RUN_PATH' environment variable
  #      during linking
  #    - use the '-Wl,-rpath -Wl,LIBDIR' linker flag
  #    - have your system administrator add LIBDIR to '/etc/ld.so.conf'
fi

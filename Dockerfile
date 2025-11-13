FROM hiennguyen9874/deepstream:6.3.0-devel as builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
    python3-pip \
    # libatlas-base-dev libatlas3-base \
    # libopenblas-dev \
    # libpcre2-dev \
    # flex bison \
    # libglib2.0-dev \
    # libjson-glib-dev \
    # uuid-dev \
    # libssl-dev \
    curl \
    # libjsoncpp-dev \
    # libopencv-dev \
    libhiredis-dev \
    libboost-system-dev libboost-filesystem-dev libboost-program-options-dev && \
    rm -rf /var/lib/apt/lists/* && \
    apt autoremove && \
    apt-get clean

# Cmake
WORKDIR /tmp
RUN cd /tmp && wget https://github.com/Kitware/CMake/releases/download/v3.31.8/cmake-3.31.8-linux-x86_64.tar.gz \
    && tar -zxvf cmake-3.31.8-linux-x86_64.tar.gz \
    && rm cmake-3.31.8-linux-x86_64.tar.gz \
    && cd /tmp/cmake-3.31.8-linux-x86_64/ \
    && cp -rf bin/ doc/ share/ /usr/local/ \
    && cp -rf man/* /usr/local/man \
    && sync \
    && cmake --version \
    && cd /tmp \
    && rm -rf /tmp/cmake-3.31.8-linux-x86_64/

FROM builder as protobuf

WORKDIR /tmp
RUN cd /tmp && git clone https://github.com/protocolbuffers/protobuf.git \
    && cd protobuf && git checkout v29.3 \
    && git submodule update --init --recursive \
    && cmake -DCMAKE_CXX_STANDARD=17 -Dprotobuf_BUILD_SHARED_LIBS=ON -Dprotobuf_BUILD_TESTS=OFF . && cmake --build . --parallel $(nproc) \
    && make install -j$(nproc) \
    && ldconfig \
    && cd /tmp \
    && mkdir /tmp/lib-protobuf \
    && cp -rf /usr/local/lib/pkgconfig /tmp/lib-protobuf \
    && cp -rf /usr/local/lib/cmake/absl /tmp/lib-protobuf \
    && cp -rf /usr/local/lib/cmake/protobuf /tmp/lib-protobuf \
    && cp -rf /usr/local/lib/cmake/utf8_range /tmp/lib-protobuf \
    && cp -rf /usr/local/lib/libabsl* /tmp/lib-protobuf \
    && cp -rf /usr/local/lib/libutf8* /tmp/lib-protobuf \
    && cp -rf /usr/local/lib/libprotobuf* /tmp/lib-protobuf \
    && cp -rf /usr/local/lib/libprotoc* /tmp/lib-protobuf \
    && cp -rf /usr/local/lib/libupb.a /tmp/lib-protobuf \
    && mkdir /tmp/include-protobuf \
    && cp -rf /usr/local/include/google /tmp/include-protobuf \
    && cp -rf /usr/local/include/absl /tmp/include-protobuf \
    && cp -rf /usr/local/include/upb /tmp/include-protobuf \
    && cp -rf /usr/local/include/utf8_range.h /tmp/include-protobuf \
    && cp -rf /usr/local/include/utf8_validity.h /tmp/include-protobuf \
    && rm -rf protobuf
# /tmp/include-protobuf -> /usr/local/include
# /tmp/lib-protobuf -> /usr/local/lib
# /usr/local/bin/protoc

FROM builder as civetweb

RUN wget https://github.com/civetweb/civetweb/archive/refs/tags/v1.16.tar.gz \
    && tar -xvf v1.16.tar.gz \
    && rm v1.16.tar.gz \
    && cd civetweb-1.16 \
    && WITH_CPP=1 TARGET_OS=LINUX make -j$(nproc) \
    && WITH_CPP=1 TARGET_OS=LINUX make install \
    && WITH_CPP=1 TARGET_OS=LINUX make install-headers \
    && WITH_CPP=1 TARGET_OS=LINUX make install-slib \
    && WITH_CPP=1 TARGET_OS=LINUX make install-lib \
    && cd /tmp \
    && mkdir /tmp/lib-civetweb \
    && cp -rf /usr/local/lib/libcivetweb* /tmp/lib-civetweb \
    && mkdir /tmp/include-civetweb \
    && cp -rf /usr/local/include/civetweb.h /tmp/include-civetweb \
    && cp -rf /usr/local/include/CivetServer.h /tmp/include-civetweb \
    && rm -rf /tmp/civetweb-1.16/
# /usr/local/etc/civetweb.conf
# /usr/local/share/doc/civetweb
# /tmp/include-civetweb -> /usr/local/include
# /tmp/lib-civetweb -> /usr/local/lib

FROM builder as redis

RUN git clone -b 1.3.10 https://github.com/sewenew/redis-plus-plus.git \
    && cd redis-plus-plus \
    && mkdir build \
    && cd build \
    && cmake .. \
    && make -j$(nproc) \
    && make install \
    && cd /tmp \
    && mkdir /tmp/lib-redis \
    && cp -rf /usr/local/lib/libredis++.so.1.3.10 /tmp/lib-redis \
    && cp -rf /usr/local/lib/libredis++.a /tmp/lib-redis \
    && cp -rf /usr/local/lib/libredis++.so.1 /tmp/lib-redis \
    && cp -rf /usr/local/lib/libredis++.so /tmp/lib-redis \
    && cp -rf /usr/local/lib/pkgconfig/redis++.pc /tmp/lib-redis \
    && rm -rf redis-plus-plus
# /usr/local/share/cmake/redis++
# /usr/local/include/sw/redis++
# /tmp/lib-redis -> /usr/local/lib

FROM builder as tensorRT

# Build TensorRT
ARG TRT_OSS_CHECKOUT_TAG=release/8.2
ARG TENSORRT_REPO=https://github.com/hiennguyen9874/TensorRT

WORKDIR /tmp
RUN git clone -b $TRT_OSS_CHECKOUT_TAG $TENSORRT_REPO \
    && export TRT_SOURCE=/tmp/TensorRT \
    && cd /tmp/TensorRT \
    && git submodule update --init --recursive \
    && mkdir -p build \
    && cd /tmp/TensorRT/build \
    && cmake .. \
    -DTRT_LIB_DIR=/usr/lib/x86_64-linux-gnu/ \
    -DCMAKE_C_COMPILER=/usr/bin/gcc \
    -DTRT_BIN_DIR=`pwd`/out \
    && make nvinfer_plugin -j$(nproc) \
    && mkdir -p /TensorRT \
    && cp /tmp/TensorRT/build/libnvinfer_plugin.so.8.* /TensorRT \
    && cp $(find /tmp/TensorRT/build -name "libnvinfer_plugin.so.8.*" -print -quit) \
    $(find /usr/lib/x86_64-linux-gnu/ -name "libnvinfer_plugin.so.8.*" -print -quit) \
    && ldconfig \
    && cd /tmp \
    && rm -rf /tmp/TensorRT
# /TensorRT/libnvinfer_plugin.so.8.*

FROM builder as prometheus

WORKDIR /tmp
RUN git clone --depth 1 --branch v1.2.4 https://github.com/jupp0r/prometheus-cpp.git && \
    cd prometheus-cpp && \
    git submodule init && git submodule update && \
    mkdir _build && cd _build && \
    cmake .. -DBUILD_SHARED_LIBS=ON -DENABLE_PUSH=ON -DENABLE_COMPRESSION=OFF && \
    cmake --build . --parallel 4 && \
    cmake --install . && \
    cd /tmp && \
    mkdir /tmp/lib-prometheus && \
    cp -rf /usr/local/lib/libprometheus* /tmp/lib-prometheus && \
    mkdir /tmp/pkgconfig-prometheus && \
    cp -rf /usr/local/lib/pkgconfig/prometheus-cpp* /tmp/pkgconfig-prometheus && \
    rm -rf prometheus-cpp
# /usr/local/include/prometheus
# /tmp/lib-prometheus -> /usr/local/lib
# /tmp/pkgconfig-prometheus -> /usr/local/lib/pkgconfig
# /usr/local/lib/cmake/prometheus-cpp/

FROM builder as avro

RUN git clone --branch release-1.12.1 https://github.com/apache/avro.git && \
    cd avro/lang/c++ && \
    mkdir build && \
    cd build && \
    cmake .. && \
    make -j$(nproc) && \
    make install && \
    cd /tmp && \
    mkdir /tmp/lib-avro && \
    mkdir /tmp/lib-avro/cmake && \
    mkdir /tmp/lib-avro/pkgconfig && \
    cp -rf /usr/local/lib/libavrocpp.so /tmp/lib-avro/ && \
    cp -rf /usr/local/lib/libavrocpp.so.1.12.1 /tmp/lib-avro/ && \
    cp -rf /usr/local/lib/libavrocpp_s.a /tmp/lib-avro/ && \
    cp -rf /usr/local/lib/cmake/avro-cpp /tmp/lib-avro/cmake/avro-cpp && \
    cp -rf /usr/local/lib/libfmt.a /tmp/lib-avro/ && \
    cp -rf /usr/local/lib/cmake/fmt /tmp/lib-avro/cmake/fmt && \
    cp -rf /usr/local/lib/pkgconfig/fmt.pc /tmp/lib-avro/pkgconfig/fmt.pc && \
    rm -rf avro
# /usr/local/bin/avrogencpp
# /usr/local/include/avro
# /usr/local/include/fmt
# /tmp/lib-avro -> /usr/local/lib

FROM builder as cpr

RUN cd /tmp && \
    if [ -d "/tmp/cpr" ]; then rm -Rf /tmp/cpr; fi && \
    git clone --depth 1 --branch 1.11.1 https://github.com/libcpr/cpr.git && \
    cd cpr && \
    mkdir _build && cd _build && \
    cmake .. -DBUILD_SHARED_LIBS=ON -DCPR_USE_SYSTEM_CURL=ON -DCPR_BUILD_TESTS=OFF -DCPR_ENABLE_SSL=ON && \
    cmake --build . --parallel 4 && \
    cmake --install . && \
    ldconfig && \
    cd /tmp && \
    rm -rf cpr
# /usr/local/lib/libcpr.so.1.11.1
# /usr/local/lib/libcpr.so.1
# /usr/local/lib/libcpr.so
# /usr/local/lib/cmake/cpr
# /usr/local/include/cpr

FROM builder as spdlog

RUN cd /tmp && \
    if [ -d "/tmp/spdlog" ]; then rm -Rf /tmp/spdlog; fi && \
    git clone --depth 1 --branch v1.15.0 https://github.com/gabime/spdlog && \
    cd spdlog && \
    mkdir _build && cd _build && \
    cmake .. -DBUILD_SHARED_LIBS=ON && \
    cmake --build . --parallel 4 && \
    cmake --install . && \
    ldconfig && \
    cd /tmp && \
    rm -rf spdlog
# /usr/local/include/spdlog
# /usr/local/lib/libspdlog.so.1.15.0
# /usr/local/lib/libspdlog.so.1.15
# /usr/local/lib/libspdlog.so
# /usr/local/lib/cmake/spdlog
# /usr/local/lib/pkgconfig/spdlog.pc

FROM builder as onnxruntime

# Install ONNX Runtime
ARG ORT_VERSION=1.22.0
RUN mkdir -p /tmp/onnxruntime && \
    cd /tmp/onnxruntime && \
    curl -L -o onnxruntime-linux-x64-${ORT_VERSION}.tgz \
    "https://github.com/microsoft/onnxruntime/releases/download/v${ORT_VERSION}/onnxruntime-linux-x64-${ORT_VERSION}.tgz" && \
    mkdir -p /opt/onnxruntime && \
    tar -xvzf onnxruntime-linux-x64-${ORT_VERSION}.tgz -C /opt/onnxruntime --strip-components=1 && \
    rm -rf /tmp/onnxruntime

ENV ONNXRUNTIME_DIR=/opt/onnxruntime
ENV CPLUS_INCLUDE_PATH=$ONNXRUNTIME_DIR/include:$CPLUS_INCLUDE_PATH
ENV LIBRARY_PATH=$ONNXRUNTIME_DIR/lib:$LIBRARY_PATH
ENV LD_LIBRARY_PATH=$ONNXRUNTIME_DIR/lib:$LD_LIBRARY_PATH

FROM hiennguyen9874/deepstream:6.3.0-devel as devel

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
    python3-pip \
    libatlas-base-dev libatlas3-base \
    libopenblas-dev \
    libpcre2-dev \
    flex bison \
    libglib2.0 libglib2.0-dev \
    libjson-glib-dev \
    uuid-dev \
    libssl-dev \
    curl \
    libjsoncpp-dev \
    libopencv-dev \
    libhiredis-dev \
    gstreamer1.0-libav \
    gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly \
    libavresample-dev libavresample4 libavutil-dev libavutil56 libavcodec-dev \
    libavcodec58 libavformat-dev libavformat58 libavfilter7 libde265-dev \
    libde265-0 libx264-155 libx265-179 libvpx6 \
    libmpeg2encpp-2.1-0 libmpeg2-4 libmpg123-0 \
    libgstreamer-plugins-base1.0-dev libgstreamer1.0-dev libgstrtspserver-1.0-dev \
    libx11-dev \
    libyaml-cpp-dev \
    libjansson4  libjansson-dev \
    nlohmann-json3-dev iputils-ping netcat-traditional \
    libboost-system-dev libboost-filesystem-dev libboost-program-options-dev && \
    rm -rf /var/lib/apt/lists/* && \
    apt autoremove && \
    apt-get clean

# protobuf
COPY --from=protobuf /tmp/include-protobuf /usr/local/include
COPY --from=protobuf /tmp/lib-protobuf /usr/local/lib
COPY --from=protobuf /usr/local/bin/protoc /usr/local/bin/protoc

# civetweb
COPY --from=civetweb /usr/local/etc/civetweb.conf /usr/local/etc/civetweb.conf
COPY --from=civetweb /usr/local/share/doc/civetweb /usr/local/share/doc/civetweb
COPY --from=civetweb /tmp/include-civetweb /usr/local/include
COPY --from=civetweb /tmp/lib-civetweb /usr/local/lib

# redis plus plus
COPY --from=redis /usr/local/share/cmake/redis++ /usr/local/share/cmake/redis++
COPY --from=redis /usr/local/include/sw/redis++ /usr/local/include/sw/redis++
COPY --from=redis /tmp/lib-redis /usr/local/lib

# tensorRT
COPY --from=tensorRT /TensorRT /tmp/TensorRT
RUN cp $(find /tmp/TensorRT -name "libnvinfer_plugin.so.8.*" -print -quit) \
    $(find /usr/lib/x86_64-linux-gnu/ -name "libnvinfer_plugin.so.8.*" -print -quit) \
    && ldconfig \
    && cd /tmp \
    && rm -rf /tmp/TensorRT

# prometheus
COPY --from=prometheus /usr/local/include/prometheus /usr/local/include/prometheus
COPY --from=prometheus /usr/local/lib/cmake/prometheus-cpp/ /usr/local/lib/cmake/prometheus-cpp/
COPY --from=prometheus /tmp/lib-prometheus /usr/local/lib
COPY --from=prometheus /tmp/pkgconfig-prometheus /usr/local/lib/pkgconfig

# avro
COPY --from=avro /usr/local/bin/avrogencpp /usr/local/bin/avrogencpp
COPY --from=avro /usr/local/include/avro /usr/local/include/avro
COPY --from=avro /usr/local/include/fmt /usr/local/include/fmt
COPY --from=avro /tmp/lib-avro /usr/local/lib

COPY --from=cpr /usr/local/lib/libcpr.so.1.11.1 /usr/local/lib/libcpr.so.1.11.1
COPY --from=cpr /usr/local/lib/libcpr.so.1 /usr/local/lib/libcpr.so.1
COPY --from=cpr /usr/local/lib/libcpr.so /usr/local/lib/libcpr.so
COPY --from=cpr /usr/local/lib/cmake/cpr /usr/local/lib/cmake/cpr
COPY --from=cpr /usr/local/include/cpr /usr/local/include/cpr

COPY --from=spdlog /usr/local/include/spdlog /usr/local/include/spdlog
COPY --from=spdlog /usr/local/lib/libspdlog.so.1.15.0 /usr/local/lib/libspdlog.so.1.15.0
COPY --from=spdlog /usr/local/lib/libspdlog.so.1.15 /usr/local/lib/libspdlog.so.1.15
COPY --from=spdlog /usr/local/lib/libspdlog.so /usr/local/lib/libspdlog.so
COPY --from=spdlog /usr/local/lib/cmake/spdlog /usr/local/lib/cmake/spdlog
COPY --from=spdlog /usr/local/lib/pkgconfig/spdlog.pc /usr/local/lib/pkgconfig/spdlog.pc

COPY --from=onnxruntime /opt/onnxruntime /opt/onnxruntime

WORKDIR /opt/nvidia/deepstream/deepstream-6.3

RUN bash /opt/nvidia/deepstream/deepstream/user_additional_install.sh

RUN ldconfig

FROM hiennguyen9874/deepstream:6.3.0-samples as samples

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
    python3-pip \
    libatlas-base-dev libatlas3-base \
    libopenblas-dev \
    libpcre2-dev \
    flex bison \
    libglib2.0 libglib2.0-dev \
    libjson-glib-dev \
    uuid-dev \
    libssl-dev \
    curl \
    libjsoncpp-dev \
    libopencv-dev \
    libhiredis-dev \
    gstreamer1.0-libav \
    gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly \
    libavresample-dev libavresample4 libavutil-dev libavutil56 libavcodec-dev \
    libavcodec58 libavformat-dev libavformat58 libavfilter7 libde265-dev \
    libde265-0 libx264-155 libx265-179 libvpx6 \
    libmpeg2encpp-2.1-0 libmpeg2-4 libmpg123-0 \
    nlohmann-json3-dev iputils-ping netcat-traditional \
    libboost-system-dev libboost-filesystem-dev libboost-program-options-dev && \
    rm -rf /var/lib/apt/lists/* && \
    apt autoremove && \
    apt-get clean

RUN ln -s /usr/local/cuda/targets/x86_64-linux/lib/libcublasLt.so.11 /usr/local/cuda/targets/x86_64-linux/lib/libcublasLt.so && \
    ln -s /usr/local/cuda/targets/x86_64-linux/lib/libcublas.so.11 /usr/local/cuda/targets/x86_64-linux/lib/libcublas.so && \
    ldconfig

# protobuf
COPY --from=protobuf /tmp/include-protobuf /usr/local/include
COPY --from=protobuf /tmp/lib-protobuf /usr/local/lib
COPY --from=protobuf /usr/local/bin/protoc /usr/local/bin/protoc

# civetweb
COPY --from=civetweb /usr/local/etc/civetweb.conf /usr/local/etc/civetweb.conf
COPY --from=civetweb /usr/local/share/doc/civetweb /usr/local/share/doc/civetweb
COPY --from=civetweb /tmp/include-civetweb /usr/local/include
COPY --from=civetweb /tmp/lib-civetweb /usr/local/lib

# redis plus plus
COPY --from=redis /usr/local/share/cmake/redis++ /usr/local/share/cmake/redis++
COPY --from=redis /usr/local/include/sw/redis++ /usr/local/include/sw/redis++
COPY --from=redis /tmp/lib-redis /usr/local/lib

# tensorRT
COPY --from=tensorRT /TensorRT /tmp/TensorRT
RUN cp $(find /tmp/TensorRT -name "libnvinfer_plugin.so.8.*" -print -quit) \
    $(find /usr/lib/x86_64-linux-gnu/ -name "libnvinfer_plugin.so.8.*" -print -quit) \
    && ldconfig \
    && cd /tmp \
    && rm -rf /tmp/TensorRT

# prometheus
COPY --from=prometheus /usr/local/include/prometheus /usr/local/include/prometheus
COPY --from=prometheus /usr/local/lib/cmake/prometheus-cpp/ /usr/local/lib/cmake/prometheus-cpp/
COPY --from=prometheus /tmp/lib-prometheus /usr/local/lib
COPY --from=prometheus /tmp/pkgconfig-prometheus /usr/local/lib/pkgconfig

# avro
COPY --from=avro /usr/local/bin/avrogencpp /usr/local/bin/avrogencpp
COPY --from=avro /usr/local/include/avro /usr/local/include/avro
COPY --from=avro /usr/local/include/fmt /usr/local/include/fmt
COPY --from=avro /tmp/lib-avro /usr/local/lib

COPY --from=cpr /usr/local/lib/libcpr.so.1.11.1 /usr/local/lib/libcpr.so.1.11.1
COPY --from=cpr /usr/local/lib/libcpr.so.1 /usr/local/lib/libcpr.so.1
COPY --from=cpr /usr/local/lib/libcpr.so /usr/local/lib/libcpr.so
COPY --from=cpr /usr/local/lib/cmake/cpr /usr/local/lib/cmake/cpr
COPY --from=cpr /usr/local/include/cpr /usr/local/include/cpr

COPY --from=spdlog /usr/local/include/spdlog /usr/local/include/spdlog
COPY --from=spdlog /usr/local/lib/libspdlog.so.1.15.0 /usr/local/lib/libspdlog.so.1.15.0
COPY --from=spdlog /usr/local/lib/libspdlog.so.1.15 /usr/local/lib/libspdlog.so.1.15
COPY --from=spdlog /usr/local/lib/libspdlog.so /usr/local/lib/libspdlog.so
COPY --from=spdlog /usr/local/lib/cmake/spdlog /usr/local/lib/cmake/spdlog
COPY --from=spdlog /usr/local/lib/pkgconfig/spdlog.pc /usr/local/lib/pkgconfig/spdlog.pc

COPY --from=onnxruntime /opt/onnxruntime /opt/onnxruntime

WORKDIR /opt/nvidia/deepstream/deepstream-6.3

RUN bash /opt/nvidia/deepstream/deepstream/user_additional_install.sh

RUN ldconfig

FROM hiennguyen9874/deepstream:6.3.0-base as base

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update -y && \
    apt-get install -y --no-install-recommends \
    python3-pip \
    zip \
    libatlas-base-dev libatlas3-base \
    libopenblas-dev \
    libpcre2-dev \
    flex bison \
    libglib2.0 libglib2.0-dev \
    libjson-glib-dev \
    uuid-dev \
    libssl-dev \
    curl \
    libjsoncpp-dev \
    libopencv-dev \
    libhiredis-dev \
    gstreamer1.0-libav \
    gstreamer1.0-plugins-good gstreamer1.0-plugins-bad gstreamer1.0-plugins-ugly \
    libavresample-dev libavresample4 libavutil-dev libavutil56 libavcodec-dev \
    libavcodec58 libavformat-dev libavformat58 libavfilter7 libde265-dev \
    libde265-0 libx264-155 libx265-179 libvpx6 \
    libmpeg2encpp-2.1-0 libmpeg2-4 libmpg123-0 \
    nlohmann-json3-dev iputils-ping netcat-traditional \
    libboost-system-dev libboost-filesystem-dev libboost-program-options-dev && \
    rm -rf /var/lib/apt/lists/* && \
    apt autoremove && \
    apt-get clean

RUN ln -s /usr/local/cuda/targets/x86_64-linux/lib/libcublasLt.so.11 /usr/local/cuda/targets/x86_64-linux/lib/libcublasLt.so && \
    ln -s /usr/local/cuda/targets/x86_64-linux/lib/libcublas.so.11 /usr/local/cuda/targets/x86_64-linux/lib/libcublas.so && \
    ldconfig

# protobuf
COPY --from=protobuf /tmp/include-protobuf /usr/local/include
COPY --from=protobuf /tmp/lib-protobuf /usr/local/lib
COPY --from=protobuf /usr/local/bin/protoc /usr/local/bin/protoc

# civetweb
COPY --from=civetweb /usr/local/etc/civetweb.conf /usr/local/etc/civetweb.conf
COPY --from=civetweb /usr/local/share/doc/civetweb /usr/local/share/doc/civetweb
COPY --from=civetweb /tmp/include-civetweb /usr/local/include
COPY --from=civetweb /tmp/lib-civetweb /usr/local/lib

# redis plus plus
COPY --from=redis /usr/local/share/cmake/redis++ /usr/local/share/cmake/redis++
COPY --from=redis /usr/local/include/sw/redis++ /usr/local/include/sw/redis++
COPY --from=redis /tmp/lib-redis /usr/local/lib

# tensorRT
COPY --from=tensorRT /TensorRT /tmp/TensorRT
RUN cp $(find /tmp/TensorRT -name "libnvinfer_plugin.so.8.*" -print -quit) \
    $(find /usr/lib/x86_64-linux-gnu/ -name "libnvinfer_plugin.so.8.*" -print -quit) \
    && ldconfig \
    && cd /tmp \
    && rm -rf /tmp/TensorRT

# prometheus
COPY --from=prometheus /usr/local/include/prometheus /usr/local/include/prometheus
COPY --from=prometheus /usr/local/lib/cmake/prometheus-cpp/ /usr/local/lib/cmake/prometheus-cpp/
COPY --from=prometheus /tmp/lib-prometheus /usr/local/lib
COPY --from=prometheus /tmp/pkgconfig-prometheus /usr/local/lib/pkgconfig

# avro
COPY --from=avro /usr/local/bin/avrogencpp /usr/local/bin/avrogencpp
COPY --from=avro /usr/local/include/avro /usr/local/include/avro
COPY --from=avro /usr/local/include/fmt /usr/local/include/fmt
COPY --from=avro /tmp/lib-avro /usr/local/lib

COPY --from=cpr /usr/local/lib/libcpr.so.1.11.1 /usr/local/lib/libcpr.so.1.11.1
COPY --from=cpr /usr/local/lib/libcpr.so.1 /usr/local/lib/libcpr.so.1
COPY --from=cpr /usr/local/lib/libcpr.so /usr/local/lib/libcpr.so
COPY --from=cpr /usr/local/lib/cmake/cpr /usr/local/lib/cmake/cpr
COPY --from=cpr /usr/local/include/cpr /usr/local/include/cpr

COPY --from=spdlog /usr/local/include/spdlog /usr/local/include/spdlog
COPY --from=spdlog /usr/local/lib/libspdlog.so.1.15.0 /usr/local/lib/libspdlog.so.1.15.0
COPY --from=spdlog /usr/local/lib/libspdlog.so.1.15 /usr/local/lib/libspdlog.so.1.15
COPY --from=spdlog /usr/local/lib/libspdlog.so /usr/local/lib/libspdlog.so
COPY --from=spdlog /usr/local/lib/cmake/spdlog /usr/local/lib/cmake/spdlog
COPY --from=spdlog /usr/local/lib/pkgconfig/spdlog.pc /usr/local/lib/pkgconfig/spdlog.pc

COPY --from=onnxruntime /opt/onnxruntime /opt/onnxruntime

WORKDIR /opt/nvidia/deepstream/deepstream-6.3

RUN bash /opt/nvidia/deepstream/deepstream/user_additional_install.sh

RUN ldconfig

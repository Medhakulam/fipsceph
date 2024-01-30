FROM ubuntu:20.04 as boringssl-builder

COPY ./openssl.ld /openssl.ld
COPY ./build-boringssl.sh /build-boringssl.sh

RUN apt-get update -y \
  && apt-get install wget -y \
  && wget https://go.dev/dl/go1.21.6.linux-amd64.tar.gz \
  && tar -C /usr/local -xzf go1.21.6.linux-amd64.tar.gz \
  && export PATH=$PATH:/usr/local/go/bin \
  && /build-boringssl.sh

FROM ubuntu:20.04

RUN --mount=type=secret,id=pro-attach-config \
    #
    # First we update apt so we install the correct versions of packages in
    # the next step
    apt-get update \
    #
    # Here we install `pro` (ubuntu-advantage-tools) as well as ca-certificates,
    # which is required to talk to the Ubuntu Pro authentication server securely.
    && apt-get install --no-install-recommends -y ubuntu-advantage-tools ca-certificates \
    #
    # With pro installed, we attach using our attach config file from the
    # previous step
    && pro attach --attach-config /run/secrets/pro-attach-config \
    #
    ###########################################################################
    # At this point, the container has access to all Ubuntu Pro services
    # specified in the attach config file.
    ###########################################################################
    #
    && DEBIAN_FRONTEND=noninteractive apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y && \
    DEBIAN_FRONTEND=noninteractive apt-get install -yy --force-yes --no-install-recommends \
    gnupg curl apt-transport-https ca-certificates -y
USER root
EXPOSE 6789 6800 6801 6802 6803 6804 6805 80 5000 8443 9283
RUN apt install software-properties-common -y
RUN add-apt-repository -y ppa:ubuntu-toolchain-r/test
RUN apt-get update
RUN apt-get install -y gcc-11 g++-11 git vim python3 cmake ninja-build python3-pip
RUN apt-get install -y libibverbs-dev librdmacm-dev libudev-dev libblkid-dev libkeyutils-dev libldap-dev libfuse-dev pkg-config libcryptsetup-dev libaio-dev libsqlite3-dev libsnappy-dev liblz4-dev gperf libcurl4-gnutls-dev liboath-dev liblttng-ust-dev libbabeltrace-dev libthrift-dev liblua5*-dev libnl-3-dev libnl-genl-3-dev  libcap-ng-dev libicu-dev librabbitmq-dev librdkafka-dev flex libre2-dev python3.8-venv libcap-dev librocksdb-dev wget
RUN apt-get remove openssl -y
ADD fip_openssl.cnf /root/.
COPY --from=boringssl-builder /boringssl/.openssl/lib /boringssl
RUN \
    mkdir -p /root/ca && \
    cd /root/ca && \
    wget https://www.openssl.org/source/openssl-3.0.8.tar.gz --no-check-certificate && \
    tar -xzvf openssl-3.0.8.tar.gz && \
    cd /root/ca/openssl-3.0.8 && \
    ./config enable-fips && \
    make && make test && \
    make install && \
    cp /root/fip_openssl.cnf /usr/local/ssl/openssl.cnf && \
    ln -sf /usr/local/bin/openssl /usr/bin/openssl && \
    perl configdata.pm --dump && \
    ldconfig && \
    export LD_LIBRARY_PATH=/usr/local/lib64 && \
    ldconfig /usr/local/lib64 && \
    cd /root/ca && \
    rm -rf openssl-3.0.8 && \
    apt-get remove wget -y
RUN mkdir /root/legacy
ADD legacy/* /root/legacy/.
WORKDIR /
RUN apt-get update
RUN apt-get install -y kmod lvm2 gdisk smartmontools nvme-cli logrotate python3-pecan
RUN mkdir -p /usr/local/lib/rados-classes
# RUN ln -sf /boringssl/libcrypto.so /lib/x86_64-linux-gnu/libcrypto.so.1.1
# RUN ln -sf /boringssl/libssl.so /lib/x86_64-linux-gnu/libssl.so.1.1
RUN git clone https://github.com/ceph/ceph.git \
    && cd ceph/ \
    && git checkout -b v17.2.6 tags/v17.2.6 && \
    apt-get install python3-pip -y \
    && pip3 install sphinx pyyaml \
    && pip3 install cython==0.29.28 && \
    cp  /usr/local/lib64/libcrypto.so.3 /usr/lib/x86_64-linux-gnu/. && \
    cp  /usr/local/lib64/libssl.so.3 /usr/lib/x86_64-linux-gnu/. && \
    cd /usr/lib/x86_64-linux-gnu && \
    ln -sf libcrypto.so.3 libcrypto.so && \
    ln -sf libssl.so.3 libssl.so \
    && ldconfig /usr/lib/x86_64-linux-gnu && \
    export LD_LIBRARY_PATH=/usr/local/lib64 && \
    ldconfig /usr/local/lib64 && \
    apt-get update && \
    apt-get install -y librocksdb-dev python3.8-venv udev && \
    sed -i 's/CMAKE_INSTALL_LIBDIR/CMAKE_INSTALL_FULL_LIBDIR/g' /ceph/src/common/options/osd.yaml.in && \
    cd /ceph && \
    ./do_cmake.sh && \
    cp /root/legacy/* ./build/include/. && \
    rm -rf /root/legacy && \
    cd /ceph/build && \
    ninja -j 3 && \
    ninja src/ceph-volume/install && \
    ninja src/pybind/mgr/install && \
    bash -c shopt -s extglob && \
    find bin -type f -iregex '.*test.*' -delete && \
    find bin -type f -not \( -name 'ceph' -or -name 'init-ceph' -or -name 'ceph-debugpack' -or -name 'ceph-coverage' -or -name 'ceph-crash' -or -name 'ceph-post-file' \) -print0 | xargs -0 -I {} strip {} && \
    find lib -type f -not -path "lib/cython_modules" -print0 | xargs -0 -I {} strip {} && \
    cp -r bin/* /usr/bin/. && \
    rm -rf lib/*.a && \
    cp -r lib/libcls* /usr/local/lib/rados-classes/. && \
    rm -rf lib/libcls* && \
    cp -r lib/* /lib/x86_64-linux-gnu/. && \
    cd ../../ && \
    rm -rf ceph/src/pybind/mgr && \
    cp -r ceph/src/pybind/* /usr/lib/python3/dist-packages/. && \
    cp ceph/src/cephadm/cephadm /usr/sbin/. && \
    cp -r ceph/share/* /usr/local/share/ceph/. && \
    cp ceph/src/mount.fuse.ceph /sbin/. && \
    cp ceph/src/rbdmap /usr/bin/rbdmap && \
    find ceph/src/include/rados -maxdepth 1 -type l -delete && \
    cp -r ceph/src/include/rados /usr/include/rados && \
    cp -r ceph/src/include/buffer.h /usr/include/rados/. && \
    cp -r ceph/src/include/buffer_fwd.h /usr/include/rados/. && \
    cp -r ceph/src/include/crc32c.h /usr/include/rados/. && \
    cp -r ceph/src/include/inline_memory.h /usr/include/rados/. && \
    cp -r ceph/src/include/page.h /usr/include/rados/. && \
    cp -r ceph/src/include/rbd /usr/include/rbd && \
    cp -r ceph/src/include/cephfs /usr/include/cephfs && \
    rm -rf ceph && \
    rm /root/ca/openssl-3.0.8.tar.gz
WORKDIR /
RUN mkdir -p /etc/ceph
ADD rbdmap /etc/ceph/.
RUN cp -r /usr/local/lib/python3.8/dist-packages/ceph-1.0.0-py3.8.egg /usr/lib/python3/dist-packages/. \
    && rm -rf /usr/local/lib/python3.8/dist-packages/ceph-1.0.0-py3.8.egg
RUN cp -r /usr/lib/python3/dist-packages/ceph-1.0.0-py3.8.egg/ceph /usr/lib/python3/dist-packages/. \
    && rm -rf /usr/lib/python3/dist-packages/ceph-1.0.0-py3.8.egg/ceph
RUN cp -r /usr/local/lib/python3.8/dist-packages/ceph_volume-1.0.0-py3.8.egg /usr/lib/python3/dist-packages/. \
    && rm -rf /usr/local/lib/python3.8/dist-packages/ceph_volume-1.0.0-py3.8.egg
RUN cp -r /usr/lib/python3/dist-packages/ceph_volume-1.0.0-py3.8.egg/ceph_volume /usr/lib/python3/dist-packages/. \
    && rm -rf /usr/lib/python3/dist-packages/ceph_volume-1.0.0-py3.8.egg/ceph_volume
RUN cp -r /usr/lib/x86_64-linux-gnu/cython_modules/lib.3/* /usr/lib/python3/dist-packages/. \
    && rm -rf /usr/lib/x86_64-linux-gnu/cython_modules/lib.3/*
RUN pip3 install cherrypy
RUN cp -r /usr/local/lib/python3.8/dist-packages/cherrypy /usr/lib/python3/dist-packages/. \
    && rm -rf /usr/local/lib/python3.8/dist-packages/cherrypy
RUN apt-get install -y python3-natsort python3-routes python3-bcrypt python3-jsonpatch python3-jwt python3-dateutil python3-werkzeug python3-scipy
RUN mkdir -p /usr/local/lib/ceph
RUN mkdir -p /usr/local/lib/ceph/erasure-code
RUN mkdir -p /usr/local/lib/ceph/compressor
RUN mkdir -p /usr/local/lib/ceph/crypto
RUN mkdir -p /usr/local/lib/ceph/denc
RUN mkdir -p /usr/local/lib/ceph/librbd
RUN mv /lib/x86_64-linux-gnu/libec_* /usr/local/lib/ceph/erasure-code/. 
RUN mv /lib/x86_64-linux-gnu/libceph_lz4* /usr/local/lib/ceph/compressor/.
RUN mv /lib/x86_64-linux-gnu/libceph_snappy* /usr/local/lib/ceph/compressor/.
RUN mv /lib/x86_64-linux-gnu/libceph_zlib* /usr/local/lib/ceph/compressor/.
RUN mv /lib/x86_64-linux-gnu/libceph_zstd* /usr/local/lib/ceph/compressor/.
RUN mv /lib/x86_64-linux-gnu/libceph_crypto* /usr/local/lib/ceph/crypto/.
RUN mv /lib/x86_64-linux-gnu/denc* /usr/local/lib/ceph/denc/.
RUN mv /lib/x86_64-linux-gnu/libceph_librbd* /usr/local/lib/ceph/librbd/.
RUN pip3 install prettytable
RUN groupadd -g 167 ceph && useradd -u 167 -g ceph ceph
RUN groupadd -g 993 cephadm && useradd -u 993 -g cephadm cephadm
RUN groupadd -g 992 libstoragemgmt && useradd -u 992 -g libstoragemgmt libstoragemgmt
RUN groupadd -g 991 ganesha && useradd -u 991 -g ganesha ganesha
RUN groupadd -g 32 rpc && useradd -u 32 -g rpc rpc
RUN mkdir -p /var/lib/ceph
RUN mkdir -p /var/lib/cephadm
WORKDIR /var/lib/ceph
RUN bash -c 'mkdir {mon,mgr,osd,mds,bootstrap-mds,bootstrap-osd,bootstrap-rbd-mirror,crash,tmp,bootstrap-mgr,bootstrap-rbd,bootstrap-rgw,radosgw}'
WORKDIR /
RUN chown -R ceph:ceph /var/lib/ceph
RUN chown -R cephadm:cephadm /var/lib/cephadm
RUN mkdir -p /run/ceph
RUN mkdir -p /usr/local/share/ceph/mgr
ADD ceph-log /etc/logrotate.d/ceph
RUN \
     if [ -f /usr/bin/ceph-dencoder ]; then gzip -9 /usr/bin/ceph-dencoder; fi && \
    rm -f /usr/bin/ceph-dencoder
RUN apt-get remove git vim ninja-build file -y
RUN cp /lib/x86_64-linux-gnu/libcrypto.so.1.1 /lib/x86_64-linux-gnu/openssl_libcrypto.so.1.1
RUN ln -sf /boringssl/libcrypto.so /lib/x86_64-linux-gnu/libcrypto.so.1.1
RUN ln -sf /boringssl/libssl.so /lib/x86_64-linux-gnu/libssl.so.1.1
RUN ldconfig /usr/local/lib64
RUN ln -sf /lib/x86_64-linux-gnu/libcrypto.so.3 /lib/x86_64-linux-gnu/libcrypto.so

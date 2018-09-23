FROM debian:8 as builder

ARG BRANCH=1.2.0
ENV BRANCH=${BRANCH}

# BUILD_DATE and VCS_REF are immaterial, since this is a 2-stage build, but our build
# hook won't work unless we specify the args
ARG BUILD_DATE
ARG VCS_REF

# install build dependencies
# checkout the latest tag
# build and install
RUN apt-get update && \
    apt-get install -y \
      build-essential \
      gdb \
      libreadline-dev \
      python-dev \
      libpthread-stubs0-dev \
      gcc \
      g++\
      git \
      libc6-dev \
      cmake \
      libboost-all-dev && \
    git clone --branch $BRANCH https://github.com/kepldev/kepl.git /opt/kepl && \
    cd /opt/kepl && \
    mkdir build && \
    cd build && \
    export CXXFLAGS="-w -std=gnu++11" && \
    #cmake -DCMAKE_BUILD_TYPE=RelWithDebInfo .. && \
    cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_FLAGS="-fassociative-math" -DCMAKE_CXX_FLAGS="-fassociative-math" -DSTATIC=true -DDO_TESTS=OFF .. && \
    make -j$(nproc)

FROM debian:8-slim

# Now we DO need these, for the auto-labeling of the image
ARG BUILD_DATE
ARG VCS_REF

# Good docker practice, plus we get microbadger badges
LABEL org.label-schema.build-date=$BUILD_DATE \
      org.label-schema.vcs-url="https://github.com/funkypenguin/kepl.git" \
      org.label-schema.vcs-ref=$VCS_REF \
      org.label-schema.schema-version="2.2-r1"

# Zedwallet needs libreadline 
RUN apt-get update && \
    apt-get install -y \
      libreadline-dev \
     && rm -rf /var/lib/apt/lists/*

WORKDIR /usr/local/bin
COPY --from=builder /opt/kepl/build/src/kepld .
COPY --from=builder /opt/kepl/build/src/walletd .
COPY --from=builder /opt/kepl/build/src/zedwallet .
COPY --from=builder /opt/kepl/build/src/miner .
RUN mkdir -p /var/lib/kepl
WORKDIR /var/lib/kepl
ENTRYPOINT ["/usr/local/bin/kepld"]
CMD ["--no-console","--data-dir","/var/lib/kepld","--rpc-bind-ip","0.0.0.0","--rpc-bind-port","8581","--p2p-bind-port","8580"]

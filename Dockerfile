# ----------------------------------
# STAGE 1: Builder
# ----------------------------------
FROM debian:bookworm-slim AS builder

RUN apt-get update && apt-get install -y \
    git cmake make clang libsqlite3-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /build
RUN git clone --recurse-submodules https://github.com/OpenFusionProject/OpenFusion.git .

RUN mkdir build && cd build \
    && cmake .. \
    && make

# Find the binary and move it to a known spot
RUN find /build -type f -name "fusion" -exec cp {} /build/fusion-server \;

# ----------------------------------
# STAGE 2: Runtime
# ----------------------------------
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y \
    libsqlite3-0 ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -d /home/container -m container
WORKDIR /home/container

# Create the Safe Zone
RUN mkdir -p /opt/openfusion

# --- THE FIX ---
# 1. Copy the Binary
COPY --from=builder /build/fusion-server /opt/openfusion/fusion
# 2. Copy the Config
COPY --from=builder /build/config.ini /opt/openfusion/config.ini
# 3. Copy the Data (tdata)
COPY --from=builder /build/tdata /opt/openfusion/tdata
# 4. Copy the Database Schema (sql) - This fixes the "Scheme" error
COPY --from=builder /build/sql /opt/openfusion/sql
# 5. Copy the Resources (res) - Just in case
COPY --from=builder /build/res /opt/openfusion/res

# Entrypoint setup
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

USER container
ENV USER=container HOME=/home/container

CMD ["/entrypoint.sh"]
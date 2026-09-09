# Tile pipeline: turn a Protomaps vector pack into the raster pack the app ships.
#
# D-11 settled the renderer as raster, and Protomaps publishes vector, so
# something has to rasterise. That something is MapLibre Native, which is a
# compiled OpenGL renderer — it does not run on the Windows hosts this team
# uses, and its prebuilt binaries target Ubuntu 24.04 exactly. Hence an image
# rather than a line in scripts/.
#
# Build:  docker compose --profile tiles build tiles
# Run:    docker compose --profile tiles run --rm tiles \
#           node rasterise.mjs --source <url|file> --region <file.geojson>
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Node 24 rather than 22: `node:sqlite` is still behind a flag on 22, and this
# writes an MBTiles file, which is a SQLite database. One fewer moving part.
#
# **xvfb is required, despite the "headless" label.** This build's MapLibre
# Native goes through GLFW, which opens an X display even when rendering
# offscreen; without one it retries a few times and then aborts the process
# with `Failed to open X display` and a core dump. Mesa provides the software
# GL that Xvfb's virtual display renders into, since a container has no GPU.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl xz-utils \
      xvfb x11-utils libgl1-mesa-dri libglx-mesa0 \
      libegl1 libgles2 libopengl0 libgbm1 \
      libglfw3 libuv1 libicu74 libcurl4 \
      libjpeg-turbo8 libpng16-16t64 libwebp7 \
 && curl -fsSL https://deb.nodesource.com/setup_24.x | bash - \
 && apt-get install -y --no-install-recommends nodejs \
 && apt-get purge -y xz-utils \
 && apt-get autoremove -y \
 && rm -rf /var/lib/apt/lists/*

# The pmtiles CLI does two jobs here: `extract` slices a region out of the
# remote planet without downloading it, and `convert` turns the MBTiles this
# pipeline writes into the PMTiles the app reads. A single static Go binary.
ARG PMTILES_VERSION=1.31.2
RUN curl -fsSL -o /tmp/pmtiles.tar.gz \
      "https://github.com/protomaps/go-pmtiles/releases/download/v${PMTILES_VERSION}/go-pmtiles_${PMTILES_VERSION}_Linux_x86_64.tar.gz" \
 && tar -xzf /tmp/pmtiles.tar.gz -C /usr/local/bin pmtiles \
 && rm /tmp/pmtiles.tar.gz \
 && pmtiles version

WORKDIR /app/tools/tiles

# Dependencies first, so editing the script does not re-download the renderer's
# prebuilt binary on every rebuild.
COPY tools/tiles/package.json ./
RUN npm install --no-audit --no-fund --loglevel=error

COPY tools/tiles/ ./
COPY scripts/lib/ /app/scripts/lib/
COPY docker/tiles/entrypoint.sh /usr/local/bin/entrypoint.sh

# Every command runs under a virtual display. Putting it in the entrypoint
# rather than asking callers to remember `xvfb-run` means a forgotten prefix
# cannot produce the core dump described above.
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["bash"]

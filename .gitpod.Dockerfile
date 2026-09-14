FROM gitpod/workspace-full:latest

USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl ca-certificates xz-utils unzip \
    && rm -rf /var/lib/apt/lists/*

USER gitpod
ENV FLUTTER_HOME=/home/gitpod/flutter
ENV PATH=/home/gitpod/flutter/bin:/home/gitpod/flutter/bin/cache/dart-sdk/bin:$PATH

RUN curl -fL https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.44.0-stable.tar.xz \
    | tar -xJ -C /home/gitpod \
    && flutter config --enable-web \
    && flutter precache --web \
    && flutter doctor

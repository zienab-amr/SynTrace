# ==============================
# Stage 1: Build Flutter Web
# ==============================
FROM ubuntu:24.04 AS build

ARG FLUTTER_VERSION=3.44.2

ENV DEBIAN_FRONTEND=noninteractive
ENV PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Install Flutter build dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

# Install the required Flutter SDK version
RUN git clone \
    --depth 1 \
    --branch ${FLUTTER_VERSION} \
    https://github.com/flutter/flutter.git \
    /opt/flutter

RUN git config --global --add safe.directory /opt/flutter

# Prepare Flutter for web builds
RUN flutter config --enable-web \
    && flutter precache --web \
    && flutter --version

WORKDIR /app

# Restore project dependencies
COPY pubspec.yaml pubspec.lock ./

RUN flutter pub get

# Copy application source
COPY . .

# Public backend configuration
ARG API_BASE_URL=https://jackeline-cibarious-supergallantly.ngrok-free.dev/api

# Build production web application
RUN flutter build web \
    --release \
    --no-pub \
    --dart-define=API_BASE_URL=${API_BASE_URL}

# ==============================
# Stage 2: Serve Flutter Web
# ==============================
FROM nginx:stable-alpine AS runtime

COPY nginx.conf /etc/nginx/conf.d/default.conf

COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
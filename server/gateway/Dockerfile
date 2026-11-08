# Single entry point of the server: NGINX in front of the API and, when
# WEB_ENABLED=true, the web version of the application.
#
# Built from the root of the repository (see docker-compose.yml). The Flutter
# SDK is only downloaded when WEB_ENABLED=true: BuildKit skips the unused stages.
ARG WEB_ENABLED=false

FROM debian:13-slim AS web-build
ARG FLUTTER_VERSION=3.47.8
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl git unzip xz-utils \
 && git clone --depth 1 --branch "${FLUTTER_VERSION}" https://github.com/flutter/flutter.git /opt/flutter
ENV PATH="/opt/flutter/bin:${PATH}"
RUN flutter config --no-analytics --no-cli-animations \
 && flutter precache --web --no-android --no-ios --no-linux --no-windows --no-macos
WORKDIR /src/app
COPY app/pubspec.yaml app/pubspec.lock ./
RUN flutter pub get --enforce-lockfile
COPY app/ ./
# Everything is served from this image: no CDN at run time.
RUN flutter build web --release --no-web-resources-cdn --pwa-strategy=none \
 && mv build/web /out

FROM debian:13-slim AS web-true
COPY --from=web-build /out /out

FROM debian:13-slim AS web-false
RUN mkdir /out

FROM web-${WEB_ENABLED} AS web

# Run: non-root NGINX, listening on 8080.
FROM nginxinc/nginx-unprivileged:1.29-alpine
COPY --from=web /out/ /usr/share/timelog/
COPY server/gateway/configure.sh /docker-entrypoint.d/40-timelog.sh
EXPOSE 8080

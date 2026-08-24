FROM ghcr.io/cirruslabs/flutter:stable AS flutter_build

WORKDIR /app
COPY smart_parking_system/ .

ARG API_BASE_URL=/api
ARG WS_BASE_URL=

RUN flutter config --no-analytics && flutter pub get
RUN flutter build web \
    --dart-define=API_BASE_URL=${API_BASE_URL} \
    --dart-define=WS_BASE_URL=${WS_BASE_URL}

FROM nginx:1.27-alpine

COPY --from=flutter_build /app/build/web /usr/share/nginx/html
COPY admin_panel/ /usr/share/nginx/html/admin
COPY docker/nginx/nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80

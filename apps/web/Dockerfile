FROM ubuntu:24.04 AS build

RUN apt-get update && apt-get install -y \
    git curl unzip xz-utils zip libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

RUN git clone https://github.com/flutter/flutter.git \
    --branch 3.47.4 \
    --depth 1 \
    /opt/flutter

ENV PATH="/opt/flutter/bin:/opt/flutter/bin/cache/dart-sdk/bin:${PATH}"

WORKDIR /app
COPY . .

RUN flutter pub get

RUN flutter build web \
    --dart-define=NAVI_API=https://navi-api-525038995260.asia-southeast1.run.app

FROM nginx:alpine

COPY --from=build /app/build/web /usr/share/nginx/html

RUN sed -i 's/listen       80;/listen       8080;/' /etc/nginx/conf.d/default.conf

EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
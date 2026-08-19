FROM mcr.microsoft.com/dotnet/sdk:10.0-alpine@sha256:d8ee39817ca03a3757288e83c37ed73cc969a286c603b827c7cbe33add1c2d1c AS builder
WORKDIR /app

RUN apk add --no-cache git

ENV NUGET_PACKAGES=/root/.nuget/packages \
    NUGET_HTTP_CACHE_PATH=/root/.nuget/http-cache \
    NUGET_SCRATCH=/root/.nuget/scratch

FROM mcr.microsoft.com/dotnet/aspnet:10.0-alpine@sha256:c4b29bf368004ad9076c1ab9bc91fb373561e3905b4345637e14e8b8c57e3be8 AS runtime
EXPOSE 8080
WORKDIR /app

# Install tzdata for timezone support, which is needed for correct handling of dates and times in the application
# and setup the user and group
# the user will have no password, using shell /bin/false and using the group dotnet
RUN apk add --no-cache tzdata tini \
    && addgroup -g 3000 dotnet && adduser -u 1000 -G dotnet -D -s /bin/false dotnet

# update permissions of files if neccessary before becoming dotnet user
USER dotnet

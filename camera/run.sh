#!/bin/bash

# docker pull ccrisan/motioneye:master-amd64
# docker rm camera

docker run \
  --rm \
  -d \
  --name camera \
  -p 8765:8765 \
  -p 8081:8081 \
  --hostname="motioneye" \
  -v /etc/localtime:/etc/localtime:ro \
  -v /media/wojtek/storage/cameras/config:/etc/motioneye \
  -v /media/wojtek/storage/cameras/videos:/var/lib/motioneye \
  ccrisan/motioneye:master-amd64


# on server
docker run \
  --rm \
  -d \
  --name camera \
  -p 9981:8765 \
  -p 9081:8081 \
  --hostname="motioneye" \
  -v /etc/localtime:/etc/localtime:ro \
  -v /mnt/storage/cameras/config:/etc/motioneye \
  -v /mnt/storage/cameras/videos:/var/lib/motioneye \
  ccrisan/motioneye:master-amd64

# on server
docker run \
  --rm \
  -d \
  --name camera \
  -p 9981:8765 \
  -p 9081:8081 \
  --hostname="motioneye" \
  -v /etc/localtime:/etc/localtime:ro \
  -v /mnt/data/cameras/config:/etc/motioneye \
  -v /mnt/workers/cameras/videos:/var/lib/motioneye \
  ccrisan/motioneye:master-amd64


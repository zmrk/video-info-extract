FROM ubuntu:20.04

RUN apt-get update && apt-get install -y \
    inotify-tools \
    ffmpeg \
    curl

RUN mkdir -p /videos
RUN mkdir -p /info

COPY watch.sh /root/watch.sh
RUN chmod +x /root/watch.sh

ENV API_URL=""
VOLUME [ "/videos", "/info" ]

CMD ["/root/watch.sh"]
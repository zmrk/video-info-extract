FROM ubuntu:20.04

RUN apt-get update && apt-get install -y \
    inotify-tools \
    ffmpeg \
    curl

RUN mkdir -p /videos/info

COPY watch.sh /root/watch.sh
RUN chmod +x /root/watch.sh

CMD ["/root/watch.sh"]
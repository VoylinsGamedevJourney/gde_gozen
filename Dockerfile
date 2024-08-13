FROM archlinux:base

RUN pacman -Syu && \
    pacman -S --noconfirm ffmpeg git bash yasm python python-pip scons

ENV FFMPEG_PATH="/usr/bin/ffmpeg" 
ENV PATH="/usr/bin:$PATH"

WORKDIR /app
COPY . .

CMD ["bash"]


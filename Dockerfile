FROM ubuntu:wily

RUN apt-get update && apt-get install -y libcurl4-openssl-dev libsdl1.2-dev libgc-dev ca-certificates python-pip ffmpeg
RUN pip install youtube-dl

ADD main /home/nimgram/

WORKDIR /home/nimgram

ENV REDIS 127.0.0.1
ENV TOKEN 
RUN mkdir static

EXPOSE 8000
ENTRYPOINT ["./main"]
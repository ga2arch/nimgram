FROM ubuntu:wily

RUN apt-get update && apt-get install -y libcurl4-openssl-dev libsdl1.2-dev libgc-dev ca-certificates

ADD main /home/nimgram/

WORKDIR /home/nimgram

ENV REDIS 127.0.0.1
RUN mkdir static

EXPOSE 8000
ENTRYPOINT ["./main"]
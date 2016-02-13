FROM ubuntu:wily

ADD main /home/nimgram/

WORKDIR /home/nimgram

RUN mkdir static
EXPOSE 8000
ENTRYPOINT ["./main"]
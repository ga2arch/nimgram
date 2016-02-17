FROM ga2arch/nimgram-base:latest

ADD main /home/nimgram/
ADD extract.py /home/nimgram/

WORKDIR /home/nimgram

ENV REDIS 127.0.0.1
RUN mkdir static

EXPOSE 8000
ENTRYPOINT ["./main"]
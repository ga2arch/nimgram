FROM ga2arch/nimgram-base:latest

RUN pip install goose-extractor
ADD main /home/nimgram/

WORKDIR /home/nimgram

ENV REDIS 127.0.0.1
RUN mkdir static

EXPOSE 8000
ENTRYPOINT ["./main"]
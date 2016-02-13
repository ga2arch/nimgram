import types, nre, telegram, sets, options, tables, osproc
import httpclient, json, threadpool, os, locks, strutils
import redis as redis

{.experimental.}

const baseUrl = "https://hacker-news.firebaseio.com/v0/"
var dbObj: Redis
var db: ptr Redis

proc fetchStory(id: int64): string =
  let itemUrl = baseUrl & "item/" & $id & ".json"
  let resp = getContent(itemUrl)
  let p = parseJson(resp)
  result = p["title"].getStr

proc checkHN() {.thread.} =
  var cache = db.smembers("hn:cache")
  while true:
    let topStoriesUrl = baseUrl & "topstories.json"
    let resp = getContent(topStoriesUrl)
    let ids = parseJson(resp).getElems[0..20]
    let hnusers = db.smembers("hn:users")

    for i, id in ids:
      if not cache.contains($id.getNum):
        discard db.sadd("hn:cache", $id.getNum)
        for userid in hnusers:
          let threshold = db.hget(userid, "hn:threshold").parseInt
          if i < threshold:
            sendMessage(userid.parseInt, fetchStory(id.getNum))
    sleep(1000*60*3)

proc newHNMode(): Mode =
  spawn checkHN()

  let run = proc(message: Message) =
    let thresholdRegex = re"/threshold (?<num>[0-9]+)"
    let capture = message.text.match(thresholdRegex)
    if capture.isSome:
      let num = capture.get.captures["num"]
      discard db.hSet($message.user.id, "hn:threshold", num)
      message.user.sendMessage("Threshold set " & num)

  Mode(name: "hn",
       isActive: proc(user: User): bool =
                     let ismem = db[].sismember("hn:users", $user.id)
                     return ismem == 1,
       run: run,
       enable: proc(user: User) =
         discard db.hSet($user.id, "hn:threshold", "5")
         discard db.sAdd("hn:users", $user.id),

       disable: proc(user: User) =
         discard db.del($user.id)
         discard db.sRem("hn:users", $user.id))

proc download(code: string, user: User) =
  let url = "http://www.youtube.com/watch?v=" & code
  let filename =
    execProcess("youtube-dl -x --get-filename " & url).changeFileExt(".mp3")
  user.sendMessage("Downloading: " & filename)
  discard waitForExit startProcess("youtube-dl",
                                   workingDir = "static",
                                   args = @["-x", "--audio-format", "mp3", url],
                                   options = {poStdErrToStdOut, poUsePath})
  user.sendAudio(filename)

proc newYTMode(): Mode =
  Mode(name: "youtube",
       isActive: proc(user: User): bool = return true,
       enable: proc(user: User) = discard,
       disable: proc(user: User) = discard,
       run: proc(message: Message) =
         echo(message)
         let ytRegex = re"(?:youtube\.com\/\S*(?:(?:\/e(?:mbed))?\/|watch\?(?:\S*?&?v\=))|youtu\.be\/)([a-zA-Z0-9_-]{6,11})"
         let capture = message.text.find(ytRegex)
         if capture.isSome:
           try:
             download(capture.get.captures[0], message.user)
           except Exception:
             message.user.sendMessage(getCurrentExceptionMsg()))

proc init*() =
  dbObj = redis.open()
  db = addr(dbObj)

proc loadCommands*(): seq[Command] =
  var cmds: seq[Command] = @[]
  return cmds

proc loadModes*(): seq[Mode] =
  return @[newHNMode(), newYTMode()]


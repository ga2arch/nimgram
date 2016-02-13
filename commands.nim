import types, nre, telegram, sets, options, tables, osproc
import httpclient, json, threadpool, os, locks, strutils

const baseUrl = "https://hacker-news.firebaseio.com/v0/"
var hlock: Lock
var hnchats {.guard: hlock.}: Table[int64, int64]

template lock(a: Lock; body: stmt): auto =
  a.acquire
  defer: a.release
  {.locks: [a].}:
    body

proc fetchStory(id: int64): string =
  let itemUrl = baseUrl & "item/" & $id & ".json"
  let resp = getContent(itemUrl)
  let p = parseJson(resp)
  let title = p["title"].getStr
  return title

proc checkHN(hnchats: ptr Table[int64, int64]) =
  var cache = initSet[int64]()
  while true:
    let topStoriesUrl = baseUrl & "topstories.json"
    let resp = getContent(topStoriesUrl)
    let ids = parseJson(resp).getElems[0..20]
    for i, id in ids:
      if not cache.containsOrIncl(id.getNum):
        lock hlock:
          for userid, threashold in pairs(hnchats[]):
            if i <= threashold:
              sendMessage(userid, fetchStory(id.getNum))
    sleep(1000*60*3)

proc newHNMode(): Mode =
  var chatsPtr: ptr Table[int64, int64]
  lock hlock:
    hnchats = initTable[int64, int64]()
    chatsPtr = addr(hnchats)

  spawn checkHN(chatsPtr)

  let run = proc(message: Message) =
    let thresholdRegex = re"/threshold (?<num>[0-9]+)"
    let capture = message.text.match(thresholdRegex)
    if capture.isSome:
      let num = capture.get.captures["num"]
      lock hlock:
        hnchats[message.user.id] = num.parseInt
      message.user.sendMessage("Threshold set " & num)

  Mode(name: "hn",
       active: false,
       run: run,
       enable: proc(message: Message) =
         lock hlock:
           hnchats[message.user.id] = 5,
       disable: proc(message: Message) =
         lock hlock:
           hnchats.del(message.user.id))

proc download(code: string, user: User) =
  let url = "http://www.youtube.com/watch?v=" & code
  let filename =
    execProcess("youtube-dl -x --get-filename " & url).changeFileExt(".mp3")
  user.sendMessage("Downloading: " & filename)
  discard waitForExit startProcess("youtube-dl",
                                   workingDir = "static",
                                   args = @["-x", "--audio-format", "mp3", url],
                                   options = {poStdErrToStdOut, poUsePath})
  user.sendMessage("Downloaded")

proc newYTMode(): Mode =
  Mode(name: "youtube",
       active: true,
       enable: proc(message: Message) = discard,
       disable: proc(message: Message) = discard,
       run: proc(message: Message) =
         echo(message)
         let ytRegex = re"(?:youtube\.com\/\S*(?:(?:\/e(?:mbed))?\/|watch\?(?:\S*?&?v\=))|youtu\.be\/)([a-zA-Z0-9_-]{6,11})"
         let capture = message.text.find(ytRegex)
         if capture.isSome:
           try:
             download(capture.get.captures[0], message.user)
           except:
             message.user.sendMessage("Error"))

proc loadCommands*(): seq[Command] =
  var cmds: seq[Command] = @[]
  return cmds

proc loadModes*(): seq[Mode] =
  return @[newHNMode(), newYTMode()]


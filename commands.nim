import types, nre, telegram, sets, options, tables, osproc
import httpclient, json, threadpool, os, locks, strutils
import redis as redis

const baseUrl = "https://hacker-news.firebaseio.com/v0/"

proc next(user: User, cont: proc(message: Message)) =
  let next = Next(run: cont)
  channel.send(Rpc(kind: RpcKind.Continuation,
                   user: user,
                   next: next))

proc fetchStory(id: int64): string =
  let
    itemUrl = baseUrl & "item/" & $id & ".json"
    resp = getContent(itemUrl)
    p = parseJson(resp)

  let
    title = p["title"].getStr
    url = p["url"].getStr
    id = $p["id"].getNum

  result = title &
    "\n\n" & url &
    "\n\n" & "https://news.ycombinator.com/item?id=" & id

proc checkHN() =
  var db = redis.open(host = getEnv("REDIS"))
  while true:
    let
      topStoriesUrl = baseUrl & "topstories.json"
      resp          = getContent(topStoriesUrl)
      ids           = parseJson(resp).getElems[0..20]
      hnusers       = db.smembers("hn:users")

    for i, id in ids:
      for userid in hnusers:
        let sentKey = userid & ":hn:sent"
        if db.sismember(sentKey, $id.getNum) == 0:
          let threshold = db.hget(userid, "hn:threshold").parseInt
          if i < threshold:
            discard db.sadd(sentKey, $id.getNum)
            var story: string
            if db.sismember("hn:cache", $id.getNum) == 1:
              story = db.get("hn:story:" & $id.getNum)
            else:
              story = fetchStory(id.getNum)
              discard db.sadd("hn:cache", $id.getNum)
              db.setk("hn:story:" & $id.getNum, story)

            sendMessage(userid.parseInt, story)

    sleep(1000*60*3)

proc newHNMode(): Mode =
  var db = redis.open(host = getEnv("REDIS"))
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
                     let ismem = db.sismember("hn:users", $user.id)
                     return ismem == 1,
       run: run,
       enable: proc(user: User) =
         discard db.hSet($user.id, "hn:threshold", "5")
         discard db.sAdd("hn:users", $user.id),

       disable: proc(user: User) =
         discard db.del($user.id & ":hn:sent")
         discard db.del($user.id)
         discard db.sRem("hn:users", $user.id))

proc download(code: string, user: User) =
  let url = "http://www.youtube.com/watch?v=" & code
  let resp = execProcess("youtube-dl --get-filename " &
    r"--output static/%\(title\)s.%\(ext\)s " & url)
  if resp.startsWith("ERROR"):
    user.sendMessage(resp)
    return

  let filename = resp.changeFileExt(".mp3")
  user.sendMessage("Downloading: " & filename.extractFilename)
  discard execProcess("youtube-dl -x --audio-format mp3 " &
    url & r" --output static/%\(title\)s.%\(ext\)s --no-playlist")
  user.sendAudio(filename)
  removeFile(filename)

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

proc newPingCommand(): Command =
  Command(regex: re"/ping",
          run: proc(message: Message, rmatch: RegexMatch) =
            message.user.sendMessage("PONG")
            next(message.user, proc(message: Message) =
                                 message.user.sendMessage("You sent " & message.text))
  )

proc newRemindCommand(): Command =
  let waiter = proc(user: User, text: string, time: int) =
    sleep(time)
    user.sendMessage(text)

  Command(regex: re"/remind (?<interval>[0-9]+)(?<unit>[s_m_h]) (?<text>.*)",
          run: proc(message: Message, rmatch: RegexMatch) =
            let
              interval = rmatch.captures["interval"].parseInt
              unit     = rmatch.captures["unit"]
              text     = rmatch.captures["text"]

            var time: int = 0
            case unit
            of "s": time = 1000
            of "m": time = 1000 * 60
            of "h": time = 1000 * 60 * 60
            else: return

            message.user.sendMessage("Remind set")
            time = time * interval
            spawn waiter(message.user, text, time))

proc loadCommands*(): seq[Command] =
  return @[newPingCommand(), newRemindCommand()]

proc loadModes*(): seq[Mode] =
  return @[newHNMode(), newYTMode()]


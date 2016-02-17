import types, nre, telegram, sets, options, tables, osproc
import httpclient, json, threadpool, os, locks, strutils
import redis as redis

const baseUrl = "https://hacker-news.firebaseio.com/v0/"

proc next(user: User, cont: proc(message: Message)) =
  let next = Next(run: cont)
  channel.send(Rpc(kind: RpcKind.Continuation,
                   user: user,
                   next: next))

proc extract(url: string): string =
  let
    resp = execProcess("python extract.py " & url)
    js   = parseJson(resp)
    meta = js["meta"].getStr
    text = js["text"].getStr

  if meta.len == 0:
    return text[0..150] & "..."
  else:
    return meta

proc fetchStory(id: int64): string =
  let
    itemUrl = baseUrl & "item/" & $id & ".json"
    resp = getContent(itemUrl)
    p = parseJson(resp)

  let
    title = p["title"].getStr
    url = p["url"].getStr
    id = $p["id"].getNum
    commentsUrl = "https://news.ycombinator.com/item?id=" & id
    meta = extract(url)

  result = """[$1]($2)
  
$4
  
[comments]($3)""" % [title, url, commentsUrl, meta]

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
      discard db.hSet($message.chat.id, "hn:threshold", num)
      message.chat.sendMessage("Threshold set " & num)

  Mode(name: "hn",
       isActive: proc(chat: Chat): bool =
                     let ismem = db.sismember("hn:users", $chat.id)
                     return ismem == 1,
       run: run,
       enable: proc(chat: Chat) =
         discard db.hSet($chat.id, "hn:threshold", "5")
         discard db.sAdd("hn:users", $chat.id),

       disable: proc(chat: Chat) =
         discard db.del($chat.id & ":hn:sent")
         discard db.del($chat.id)
         discard db.sRem("hn:users", $chat.id))

proc download(code: string, chat: Chat) =
  let url = "http://www.youtube.com/watch?v=" & code
  let resp = execProcess("youtube-dl --get-filename " &
    r"--output static/%\(title\)s.%\(ext\)s " & url)
  if resp.startsWith("ERROR"):
    chat.sendMessage(resp)
    return

  let filename = resp.changeFileExt(".mp3")
  chat.sendMessage("Downloading: " & filename.extractFilename)
  discard execProcess("youtube-dl -x --audio-format mp3 " &
    url & r" --output static/%\(title\)s.%\(ext\)s --no-playlist")
  chat.sendAudio(filename)
  removeFile(filename)

proc newYTMode(): Mode =
  Mode(name: "youtube",
       isActive: proc(chat: Chat): bool = return true,
       enable: proc(chat: Chat) = discard,
       disable: proc(chat: Chat) = discard,
       run: proc(message: Message) =
         let ytRegex = re"(?:youtube\.com\/\S*(?:(?:\/e(?:mbed))?\/|watch\?(?:\S*?&?v\=))|youtu\.be\/)([a-zA-Z0-9_-]{6,11})"
         let capture = message.text.find(ytRegex)
         if capture.isSome:
           try:
             download(capture.get.captures[0], message.chat)
           except Exception:
             message.chat.sendMessage(getCurrentExceptionMsg()))

proc newPingCommand(): Command =
  Command(regex: re"/ping",
          run: proc(message: Message, rmatch: RegexMatch) =
            message.chat.sendMessage("PONG"))

proc newRemindCommand(): Command =
  let waiter = proc(chat: Chat, text: string, time: int) =
    sleep(time)
    chat.sendMessage(text)

  Command(regex: re"/remind (?<interval>[0-9]+)(?<unit>[s_m_h]) (?<text>.*)",
          help: "/remind <time><s/m/h> <text>",
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
            spawn waiter(message.chat, text, time))

proc newHelpCommand(commands: seq[Command]): Command =
  Command(regex: re"/help",
          run: proc(message: Message, _: RegexMatch) =
            var helpMsg = ""
            for cmd in commands:
              if cmd.help != nil:
                 helpMsg = helpMsg & "\n" & cmd.help
            if helpMsg.len > 0:
              message.chat.sendMessage(helpMsg))

proc newTF2Command(): Command =
  let
    apiKey = getEnv("STEAM")
    apiUrl = "http://api.steampowered.com/ISteamUser/GetPlayerSummaries/v0002/?key=" &
      apiKey & "&steamids="
    nierro = "76561198043794079"
    simpatia = "76561198005312787"

  Command(regex: re"/tf2 (?<id>.*)",
          help: "/tf2 <userid> #Checks if the user is playing tf2",
          run: proc(message: Message, rmatch: RegexMatch) =
            var playerid = rmatch.captures["id"]
            case playerid
            of "nierro": playerid = nierro
            of "simpatia": playerid = simpatia
            else: discard

            let
              url  = apiUrl & playerid
              resp = getContent(url)
              p    = parseJson(resp)
              data = p["response"]["players"][0]
            if data.hasKey("gameid") and data["gameid"].getStr == "440":
              message.chat.sendMessage(data["personaname"].getStr &
                " is playing TF2!!!")
            else:
              message.chat.sendMessage(data["personaname"].getStr &
                " is not playing."))

proc loadCommands*(): seq[Command] =
  var cmds = @[newPingCommand(), newRemindCommand(), newTF2Command()]
  cmds.add(newHelpCommand(cmds))
  return cmds

proc loadModes*(): seq[Mode] =
  return @[newHNMode(), newYTMode()]

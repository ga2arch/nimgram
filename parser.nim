import json, types

proc parseChat(data: JsonNode): Chat =
  let f = data["message"]["chat"]
  Chat(id: f["id"].num)

proc parseFrom(data: JsonNode): User =
  let f = data["message"]["from"]
  User(id: f["id"].num, name: f["first_name"].str)

proc parseMessage*(data: string): Message =
  let p     = parseJson(data)
  let user  = parseFrom(p)
  let chat  = parseChat(p)
  let m     = p["message"]
  Message(id: m["message_id"].num,
          text: m["text"].str,
          user: user,
          chat: chat)

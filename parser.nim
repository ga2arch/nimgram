import json, types, options

proc getChat(data: JsonNode): Chat =
  let f = data["chat"]
  Chat(id: f["id"].num)

proc getUser(data: JsonNode): Option[User] =
  if data.hasKey("from"):
    let f = data["from"]
    some(User(id: f["id"].num, name: f["first_name"].str))
  else:
    none(User)

proc parseMessage*(data: string): Option[Message] =
  let js = parseJson(data)

  if js.hasKey("message"):
    let
      m = js["message"]
      user = m.getUser()
      chat = m.getChat()

    some(Message(id: m["message_id"].num,
            text: m["text"].str,
            user: user,
            chat: chat))
  else:
    none(Message)

import httpclient, types, os, options


proc call(api: string, multipart: MultipartData) =
  let
    token    = getEnv("TOKEN")
    endpoint = "https://api.telegram.org/bot" & token & "/"
    url      = endpoint & api
  try:
    discard postContent(url, multipart=multipart)
  except Exception:
    echo(getCurrentExceptionMsg())

proc sendMessage*(id: int64,
                  text: string,
                  disableLinkPrev: bool = true,
                  parseMode: string = "Markdown") =
  var data = newMultipartData()
  data["chat_id"] = $id
  data["text"] = text
  data["parse_mode"] = parseMode
  data["disable_web_page_preview"] = $disableLinkPrev
  call("sendMessage", data)

proc sendMessage*(user: Option[User], text: string) =
  if user.isSome:
    sendMessage(user.get.id, text)

proc sendMessage*(user: User, text: string) =
  sendMessage(user.id, text)

proc sendMessage*(chat: Chat, text: string) =
  sendMessage(chat.id, text)

proc sendAudio*(id: int64, path: string) =
  var data = newMultipartData()
  data["chat_id"] = $id
  data.addFiles({"audio": path})
  call("sendAudio", data)

proc sendAudio*(user: User, path: string) =
  sendAudio(user.id, path)

proc sendAudio*(chat: Chat, path: string) =
  sendAudio(chat.id, path)

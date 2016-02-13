import httpclient, types, os


proc call(api: string, multipart: MultipartData) =
  let
    token    = getEnv("TOKEN")
    endpoint = "https://api.telegram.org/bot" & token & "/"
    url      = endpoint & api
  try:
    discard postContent(url, multipart=multipart)
  except Exception:
    echo(getCurrentExceptionMsg())

proc sendMessage*(id: int64, text: string) =
  var data = newMultipartData()
  data["chat_id"] = $id
  data["text"] = text
  call("sendMessage", data)

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

import httpclient, types, os

const token = getEnv("TOKEN")
const endpoint = "https://api.telegram.org/bot" & token & "/"

proc call(api: string, multipart: MultipartData): string =
  var url = endpoint & api
  try:
    echo(postContent(url, multipart=multipart))
  except Exception:
    echo(getCurrentExceptionMsg())

proc sendMessage*(id: int64, text: string) =
  var data = newMultipartData()
  data["chat_id"] = $id
  data["text"] = text
  discard call("sendMessage", data)

proc sendMessage*(user: User, text: string) =
  sendMessage(user.id, text)

proc sendMessage*(chat: Chat, text: string) =
  sendMessage(chat.id, text)

proc sendAudio*(id: int64, path: string) =
  var data = newMultipartData()
  data["chat_id"] = $id
  data.addFiles({"audio": path})
  discard call("sendAudio", data)

proc sendAudio*(user: User, path: string) =
  sendAudio(user.id, path)

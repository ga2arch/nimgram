import httpclient, types, os

const token = getEnv("token")
const endpoint = "https://api.telegram.org/bot" & token & "/"

proc call(api: string, multipart: MultipartData): string =
  var url = endpoint & api
  try:
    return postContent(url, multipart=multipart)
  except:
    echo("Unknow exception")

proc sendMessage*(id: int64, text: string) =
  var data = newMultipartData()
  data["chat_id"] = $id
  data["text"] = text
  discard call("sendMessage", data)

proc sendMessage*(user: User, text: string) =
  sendMessage(user.id, text)

proc sendMessage*(chat: Chat, text: string) =
  sendMessage(chat.id, text)

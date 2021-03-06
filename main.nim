import asynchttpserver, asyncdispatch, json, nre, options, queues
import types, telegram, parser, commands, redis, os, threadpool, tables

{.experimental.}

type
  Config = object
    commands: seq[Command]
    modes: seq[Mode]

var config {.threadvar.}: Config

proc handleMessage(message: Message,
                   continuations: TableRef[int64, Queue[Next]]) =
  echo($message.chat & ": " & message.text)
  if continuations.hasKey(message.chat.id):
    var q = addr continuations[message.chat.id]
    if q.len > 0:
      q.dequeue().run(message)
      return

  for cmd in config.commands:
    let rmatch = message.text.match(cmd.regex)
    if rmatch.isSome:
      cmd.run(message, rmatch.get)
      return

  for mode in config.modes:
    let on  = re("/" & mode.name & " on")
    let off = re("/" & mode.name & " off")

    if mode.isActive(message.chat):
      if message.text.match(off).isSome:
        mode.disable(message.chat)
        message.user.sendMessage(mode.name & " off")
      else:
        mode.run(message)
    else:
      if message.text.match(on).isSome:
        mode.enable(message.chat)
        message.user.sendMessage(mode.name & " on")

proc handler() {.gcsafe.} =
  config = Config(commands: loadCommands(),
                  modes: loadModes())
  var continuations = newTable[int64, Queue[Next]]()
  while true:
    var rpc = channel.recv()
    case rpc.kind
    of RpcKind.Telegram:
      try:
        handleMessage(rpc.message, continuations)
      except: discard
    of RpcKind.Continuation:
      if not continuations.hasKey(rpc.user.id):
        continuations[rpc.user.id] = initQueue[Next]()
      continuations[rpc.user.id].enqueue(rpc.next)

proc cb(req: Request) {.async.} =
  let m = parseMessage(req.body)
  if m.isSome:
    channel.send(Rpc(kind: RpcKind.Telegram, message: m.get()))
  await req.respond(Http200, "")

proc main() =
  channel.open()
  var server = newAsyncHttpServer()
  spawn handler()
  waitFor server.serve(Port(8000), cb)

main()

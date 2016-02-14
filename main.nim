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
  echo(message)
  if continuations.hasKey(message.user.id):
    var q = addr continuations[message.user.id]
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

    if mode.isActive(message.user):
      if message.text.match(off).isSome:
        mode.disable(message.user)
        message.user.sendMessage(mode.name & " off")
      else:
        mode.run(message)
    else:
      if message.text.match(on).isSome:
        mode.enable(message.user)
        message.user.sendMessage(mode.name & " on")

proc handler() {.gcsafe.} =
  config = Config(commands: loadCommands(),
                  modes: loadModes())
  var continuations = newTable[int64, Queue[Next]]()
  while true:
    var rpc = channel.recv()
    echo(rpc.kind)
    case rpc.kind
    of RpcKind.Telegram: handleMessage(rpc.message, continuations)
    of RpcKind.Continuation:
      if not continuations.hasKey(rpc.user.id):
        continuations[rpc.user.id] = initQueue[Next]()
      continuations[rpc.user.id].enqueue(rpc.next)

proc cb(req: Request) {.async.} =
  try:
    channel.send(Rpc(kind: RpcKind.Telegram, message: parseMessage(req.body)))
  except:
    discard
  await req.respond(Http200, "")

proc main() =
  channel.open()
  var server = newAsyncHttpServer()
  spawn handler()
  waitFor server.serve(Port(8000), cb)

main()

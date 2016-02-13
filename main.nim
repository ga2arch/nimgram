import asynchttpserver, asyncdispatch, json, nre, options
import types, telegram, parser, commands, redis, os

type
  Config = object
    commands: seq[Command]
    modes: seq[Mode]

var config {.threadvar.}: Config

proc handleMessage(data: string) =
  let message = parseMessage(data)
  echo(message)
  for cmd in config.commands:
    if message.text.match(cmd.regex).isSome:
      cmd.run(message)
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

proc cb(req: Request) {.async.} =
  try: handleMessage(req.body)
  except: discard 
  await req.respond(Http200, "")

proc main() =
  var server = newAsyncHttpServer()
  commands.init()
  config = Config(commands: loadCommands(),
                  modes: loadModes())

  waitFor server.serve(Port(8000), cb)

main()

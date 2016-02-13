import asynchttpserver, asyncdispatch, json, nre, options
import types, telegram, parser, commands

type
  Config = object
    commands: seq[Command]
    modes: seq[Mode]

var config {.threadvar.}: Config

proc handleMessage(data: string) =
  let message = parseMessage(data)
  for cmd in config.commands:
    if message.text.match(cmd.regex).isSome:
      cmd.run(message)
      return

  for mode in config.modes:
    let on  = re("/" & mode.name & " on")
    let off = re("/" & mode.name & " off")

    if mode.active:
      if message.text.match(off).isSome:
        mode.disable(message)
        mode.active = false
        message.user.sendMessage(mode.name & " off")
      else:
        mode.run(message)
    else:
      if message.text.match(on).isSome:
        mode.enable(message)
        mode.active = true
        message.user.sendMessage(mode.name & " on")

proc cb(req: Request) {.async.} =
  handleMessage(req.body)
  await req.respond(Http200, "")

proc main() =
  var server = newAsyncHttpServer()
  config = Config(commands: loadCommands(),
                  modes: loadModes())

  waitFor server.serve(Port(8000), cb)

main()

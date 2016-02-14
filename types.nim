import nre, tables, queues

type
  User* = object
    id*: int64
    name*: string

  Chat* = object
    id*: int64

  Message* = object
    id*: int64
    text*: string
    user*: User
    chat*: Chat

type
  Command* = ref object of RootObj
    regex*: Regex
    help*: string
    run*: proc(message: Message, rmatch: RegexMatch)

  Mode* = ref object of RootObj
    name*: string
    help*: string
    enable*: proc(user: User)
    disable*: proc(user: User)
    run*: proc(message: Message)
    isActive*: proc(user: User): bool

type
  Next* = object
    run*: proc(message: Message)

type
  RpcKind* = enum Telegram, Continuation
  Rpc* = object
    case kind*: RpcKind
    of Telegram:
      message*: Message
    of Continuation:
      user*: User
      next*: Next

var channel*: Channel[Rpc]


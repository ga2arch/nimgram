import nre

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
    run*: proc(message: Message)

  Mode* = ref object of RootObj
    name*: string
    enable*: proc(user: User)
    disable*: proc(user: User)
    run*: proc(message: Message)
    isActive*: proc(user: User): bool

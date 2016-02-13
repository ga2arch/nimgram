import nre

type
  RpcCommand* = enum
    rcAdd, rcDel, rcGet, rcResp

  StoreRpc* = object
    action*: RpcCommand
    args*: tuple[key: int64, value: int64]

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
    enable*: proc(message: Message)
    disable*: proc(message: Message)
    run*: proc(message: Message)
    active*: bool

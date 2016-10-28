#
#
#                   libch4t 
#             (c) Copyright 2016 
#          David Krause, Tobias Freitag
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#
## Definition of data structures and procedures we need in the whole project.

import sequtils
import asyncnet
import tables
import sets

type
  TIrcCommands * = enum
    TPong = "PONG",
    TPing = "PING",
    TJoin = "JOIN",
    TUser = "USER",
    T001 = "001",
    T352 = "352", ## answer to who
    T315 = "315", ## end who list
    T353 = "353", ## answer names
    T366 = "366", ## end names list
    T301 = "301", ## Away reply for sender
    TNick = "NICK",
    TWho = "WHO",
    TNames = "NAMES",
    TPrivmsg = "PRIVMSG",
    TMode = "MODE",
    T375 = "375", ## start server modt
    T372 = "372", ## a line of modt
    T376 = "376" ## end of modt :End of /MOTD command.
    TError = "ERROR",
    TMotd = "MOTD",
    TPart = "PART",
    TNotice = "NOTICE",
    TUserhost = "USERHOST",
    TAway = "AWAY",
    TWall = "WALL", ## IRC? 
    # TWall = "ALL", # this is not irc ...
    TByeBye = "BYEBYE", ## not IRC
    TCap = "CAP", ## wtf is CAP????
    TDump = "DUMP", ## returns structures, not IRC
    TKick = "KICK", ## removes client from room
    TKickHard = "KICKHARD", ## not IRC removes client from server
    TQuit = "QUIT", 
    TDebug = "DEBUG", ## like dump but only printing to stdout, not IRC
    TWhois = "WHOIS", ## get info about a user
    
    # List answers
    TList = "LIST" ## lists all or some channels/rooms
    T321 = "321" ## start LIST list
    T322 = "322" ## line of LIST cmd
    T323 = "323" ## end of LIST 

    # Lusers answers
    TLusers = "LUSERS",
    T251 = "251", ## start of LUSERS
    T252 = "252", ##
    T253 = "253", ##
    T254 = "254", ##
    T255 = "255", ##

  # who is set on [server -> client] and [server -> server ] communication only!
  IrcLineIn * = object of RootObj
    command*: TIrcCommands
    params*: seq[string]
    trailer*: string
    raw*: string
    who*: string

  IrcLineOut * = object of RootObj
    prefix*: string
    command*: TIrcCommands
    params*: seq[string]
    trailer*: string

  Client * = object of RootObj 
    socket*: AsyncSocket
    user*: string
    nick*: string
    away*: string # user is the server username, nick is the visible name

  Room *  = object of RootObj 
    name*: string
    clients*: HashSet[string]
    mode*: seq[string] # clients is a sequence of usernames now!!

  Clients * = TableRef[string, Client]
  Rooms * = TableRef[string, Room]

var 
    clients * {.threadvar.}: TableRef[string, Client]
    rooms * {.threadvar.}: TableRef[string,Room]

clients = newTable[string, Client]() # string = client name
rooms = newTable[string, Room]()

proc newClient*(socket: AsyncSocket, user = "", nick = "", away = ""): Client =
   Client(socket: socket, user: user, nick: nick, away: away)

proc newIrcLineIn*(command: TIrcCommands, params: seq[string], trailer: string, raw: string, who: string): IrcLineIn =
    IrcLineIn(command: command, params: params,trailer: trailer, raw: raw, who: who)

proc newIrcLineIn*(): IrcLineIn = 
    result = IrcLineIn()
    result.command= TError
    result.params= @[]
    result.trailer= ""
    result.raw= ""
    result.who= ""

proc newIrcLineOut*(prefix: string, command: TIrcCommands, params: seq[string], trailer: string): IrcLineOut =
    IrcLineOut(prefix: prefix, command: command, params: params, trailer: trailer)

proc newRoom(name: string, clients: HashSet[string], mode: seq[string]): Room =
    Room(name: name, clients: clients, mode: mode)

proc newRoom*(name: string): Room = 
    newRoom(name, initSet[string](), @[])
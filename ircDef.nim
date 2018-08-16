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
import config # we do not really need this here..?

type
  TIrcCommands * = enum
    TPong = "PONG", ##
    TPing = "PING", ##
    TJoin = "JOIN", ##
    TUser = "USER", ##
    T001 = "001", ##
    T352 = "352", ## answer to who
    T315 = "315", ## end who list
    T353 = "353", ## answer names
    T366 = "366", ## end names list
    T301 = "301", ## Away reply for sender
    TNick = "NICK", ##
    TWho = "WHO", ##
    TNames = "NAMES", ##
    TPrivmsg = "PRIVMSG", ##
    TMode = "MODE", ##
    T375 = "375", ## start server modt
    T372 = "372", ## a line of modt
    T376 = "376" ## end of modt :End of /MOTD command.
    TError = "ERROR", ##
    TMotd = "MOTD", ##
    TPart = "PART", ##
    TNotice = "NOTICE", ##
    TUserhost = "USERHOST", ##
    TAway = "AWAY", ##
    TWall = "WALL", ## IRC? 
    # TWall = "ALL", # this is not irc ...
    TByeBye = "BYEBYE", ## not IRC
    TCap = "CAP", ## wtf is CAP????
    TDump = "DUMP", ## returns structures, not IRC
    TKick = "KICK", ## removes client from room
    TKickHard = "KICKHARD", ## not IRC removes client from server
    TQuit = "QUIT", ##
    TDebug = "DEBUG", ## like dump but only printing to stdout, not IRC
    TWhois = "WHOIS", ## get info about a user
    TPass = "PASS", ## connection password
    
    # List answers
    TList = "LIST" ## lists all or some channels/rooms
    T321 = "321" ## start LIST list
    T322 = "322" ## line of LIST cmd
    T323 = "323" ## end of LIST 

    # Lusers answers
    TLusers = "LUSERS", ## 
    T251 = "251", ## start of LUSERS
    T252 = "252", ##
    T253 = "253", ##
    T254 = "254", ##
    T255 = "255", ##

  TRoomModes * = enum
    ## Modes of a room (NOT of a user in a room), some can be set by a room operator
    ## Some have to be set by the server-config/server-operator
    RoomInvisible = "i" ## removes this room from every LIST , WHO, NAMES etc command
    RoomInviteOnly = "I" ## user cannot join this room unless they are invited
    RoomNoOperator = "n" ## nobody can be room operator in this room, only server ops have cow powers
    RoomNoVoice = "-v" ## nobody (except ops) can speak to this room

  TUserModes * = enum
    ## The server wide user modes
    ServerUserVoice = "v" ## user has "voice" on the server, so user can write to channels
    ServerUserOper = "o" ## user is a server operator
    ServerUserInvisible = "i" ## the user is completely invisible on this server, no WHO, NAMES
  
  TClientRoomModes * = enum
    ## The modes a client has in a room
    ClientRoomOper = "o" ## client is a channel/room operator
    ClientRoomVoice = "v" ## client has voice in a room, so client can write to a room
    ClientRoomBanned = "b" ## client is banned from a room
    ClientRoomInvisible = "i" ## client is invisible in a room, so client is not listed in a WHO, NAMES, etc command

  # who is set on [server -> client] and [server -> server ] communication only!
  IrcLineIn * = object of RootObj
    ## We parse every line of text we receive from a client as an IrcLineIn object
    command*: TIrcCommands ## a valid IRC command
    params*: seq[string] ## params to the command
    trailer*: string ## everything after the ":"
    raw*: string ## the raw line the client has sent us
    who*: string ## wo has sent us the line (client don't fill this normally, but servers do)

  IrcLineOut * = object of RootObj
    ## When we answer to a client we use an IrcLineOut object
    prefix*: string 
    command*: TIrcCommands
    params*: seq[string]
    trailer*: string

  Client * = ref object of RootObj 
    socket*: AsyncSocket
    user*: string
    nick*: string
    away*: string # user is the server username, nick is the visible name
    connectionPassword*: string # the password the client has used for its connection
    modes*: HashSet[TUserModes]  # these are the serverwide user mods; 
                            # eg if the user is a server operator
                            # or if the user is allowed to write to a room etc
                            # a mod is like: 
                            #   "o"  # user is server operator
                            #   "i"  # user is invisible (ip gets shadowed) # we have no other mode atm
                            #   "v"  # user has voice on this server
                            #   ....
  Room *  = object of RootObj ## An IRC room/channel
    name*: string ## name of a room like "#lobby" or "&oldstuff"
    clients*: HashSet[string] ## the usernames of connected clients (we have to look them up from `clients` )
    modes*: HashSet[TRoomModes] ## modes this rooms has (is it visible, are user allow to join withouth invite etc)

  Clients * = TableRef[string, Client] 
  Rooms * = TableRef[string, Room] 


  IrcServer* = object
    clients*: TableRef[string, Client] # table of connected clients
    socket*: AsyncSocket 
    
proc newIrcServer*(): IrcServer =
  result = IrcServer()
  result.clients = newTable[string, Client]() 

var 
    # clients * {.threadvar.}: TableRef[string, Client] # our thread local table of connected clients, 
    #                                                       ## every client ends in here
    rooms * {.threadvar.}: TableRef[string,Room] ## our thread local table of created rooms
    clientRoomMods * {.threadvar.}: TableRef[(string,string), HashSet[TClientRoomModes]] ## key: (username, roomname) , val: "o" or "v"


rooms = newTable[string, Room]() 



proc newClient*(socket: AsyncSocket, user = "", nick = "", away = "", modes = initSet[TUserModes]()): Client =
   Client(socket: socket, user: user, nick: nick, away: away, modes: modes)

proc newIrcLineIn*(command: TIrcCommands, params: seq[string], trailer: string, raw: string, who: string): IrcLineIn =
    IrcLineIn(command: command, params: params, trailer: trailer, raw: raw, who: who)

proc newIrcLineIn*(): IrcLineIn = 
    result = IrcLineIn()
    result.command= TError
    result.params= @[]
    result.trailer= ""
    result.raw= ""
    result.who= ""

proc newIrcLineOut*(prefix: string, command: TIrcCommands, params: seq[string], trailer: string): IrcLineOut =
    IrcLineOut(prefix: prefix, command: command, params: params, trailer: trailer)

proc newRoom(name: string, clients: HashSet[string], modes: HashSet[TRoomModes]): Room =
    Room(name: name, clients: clients, modes: modes)

proc newRoom*(name: string): Room = 
    newRoom(name, initSet[string](), initSet[TRoomModes]())
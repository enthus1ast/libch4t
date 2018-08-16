#
#
#                   libch4t 
#             (c) Copyright 2016 
#          David Krause, Tobias Freitag
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#
## Helper functions
import tables
import ircDef
import sets
import ircParsing
import strutils

proc isOperator*(client: Client): bool = 
  ## TODO
  return true

proc authenticated*(client: Client): bool = 
  # if the client is authenticated
  if client.user.validUserName() and client.nick.validUserName():
    return true
  else:
    return false

proc isUsernameUsed*(ircServer: IrcServer, user: string): bool =
  ## Checks if username is already in use
  ## TODO when a username has no 'nick' then it is not 'in use' ??
  for client in ircServer.clients.values:
    if client.user == user and client.nick != "": ## when a user has not set a username then it is "not in use" # todo? When is a user logged in?
      echo "user [" & user & "] is already in use" # , $client.user
      return true
  return false  

proc isNicknameUsed*(ircServer: IrcServer, nick: string): bool = 
  ## Checks if nickname is already in use
  echo "called isNicknameUsed with ", nick
  for client in ircServer.clients.values:
    if client.nick == nick and client.user != "": ## when a user has not set a username then it is "not in use" # todo? When is a user logged in?
      echo "nickname [" & nick & "] is already in use"  # by ", client
      return true
  return false

proc getClientByNick*(ircServer: IrcServer, nick: string ): Client =
  # einaml returnd die scheisse Client
  for client in ircServer.clients.values:
    if client.nick == nick:
      return client
  return newClient(nil,"","","") # TODO what should we return if no user was found?

proc getRoomsByNick*(ircServer: IrcServer, nick: string): seq[Room] =
  var username = ircServer.getClientByNick(nick).user
  result = @[]
  for room in ircServer.rooms.values:
    if room.clients.contains(username):
      result.add(room)

proc getParticipatingUsersByNick*(ircServer: IrcServer, nick: string): HashSet[string] = 
  ## returns a sequenze of clients wich has partizipated with the given nick
  ## eg. that are in the same room etc.
  ## we remove every duplicates from the result.
  ## We need this function for eg.: telling every client a user has renamed 
  result = initSet[string]()
  var client = ircServer.getClientByNick(nick)
  for room in ircServer.rooms.values:
    echo room.clients
    if room.clients.contains(client.user):
      ## user has logged into this room, 
      ## so we have to collect every client that has connected to this room that 
      ## this one user has changed his username.
      for username in room.clients:
        result.incl(username)
  
  # now we exclude our self.
  result.excl(ircServer.getClientByNick(nick).user)


proc isAway*(client: Client): bool =
  return client.away.len > 0      

proc isParamList*(ircLineIn: IrcLineIn, param: int = 0): bool =
  if ircLineIn.params.len > param:
    if ircLineIn.params[param].contains(","):
      return true
  return false

proc getParamList*(ircLineIn: IrcLineIn, param: int = 0): seq[string] =
  ## returns the list parts of param n
  result = @[]
  if ircLineIn.isParamList(param):
    result = ircLineIn.params[param].split(",")

# Modes helper
proc hasRoomMode*(ircServer: IrcServer, room: string, mode: TRoomModes): bool =
  ## return true if the room has the given mode
  if not ircServer.rooms.contains(room):
    return false

  if ircServer.rooms[room].modes.contains(mode):
    return true
  else:
    return false

proc setRoomMode*(ircServer: IrcServer, room: string, mode: TRoomModes) =
  ## sets a mode to a room
  if not ircServer.rooms.contains(room):
    return
  ircServer.rooms[room].modes.incl(mode)
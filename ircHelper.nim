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

proc isUsernameUsed*(clients: Clients, user: string): bool =
  ## Checks if username is already in use
  ## TODO when a username has no 'nick' then it is not 'in use' ??
  for client in clients.values:
    if client.user == user and client.nick != "": ## when a user has not set a username then it is "not in use" # todo? When is a user logged in?
      echo "user [" & user & "] is already in use by ", client
      return true
  return false  

proc isNicknameUsed*(clients: Clients, nick: string): bool = 
  ## Checks if nickname is already in use
  echo "called isNicknameUsed with ", nick
  for client in clients.values:
    if client.nick == nick and client.user != "": ## when a user has not set a username then it is "not in use" # todo? When is a user logged in?
      echo "nickname [" & nick & "] is already in use by ", client
      return true
  return false

proc getClientByNick*(clients: TableRef[string, Client], nick: string ): Client =
  # einaml returnd die scheisse Client
  for client in clients.values:
    if client.nick == nick:
      return client
  return newClient(nil,"","","") # TODO what should we return if no user was found?

proc getRoomsByNick*(rooms: TableRef[string, Room], nick: string): seq[Room] =
  var username = clients.getClientByNick(nick).user
  result = @[]
  for room in rooms.values:
    if room.clients.contains(username):
      result.add(room)

proc getParticipatingUsersByNick*(rooms: TableRef[string, Room], nick: string): HashSet[string] = 
  ## returns a sequenze of clients wich has partizipated with the given nick
  ## eg. that are in the same room etc.
  ## we remove every duplicates from the result.
  ## We need this function for eg.: telling every client a user has renamed 
  result = initSet[string]()
  var client = clients.getClientByNick(nick)
  for room in rooms.values:
    echo room.clients
    if room.clients.contains(client.user):
      ## user has logged into this room, 
      ## so we have to collect every client that has connected to this room that 
      ## this one user has changed his username.
      for username in room.clients:
        result.incl(username)
  
  # now we exclude our self.
  result.excl(clients.getClientByNick(nick).user)


proc isAway*(client: Client): bool =
  return client.away.len > 0      

proc isParamList*(ircLineIn: IrcLineIn, param: int = 0): bool =
  if ircLineIn.params.len > param:
    if ircLineIn.params[param].contains(","):
      return true
  return false

proc getParamList*(ircLineIn: IrcLineIn,param: int = 0): seq[string] =
  ## returns the list parts of param n
  result = @[]
  if ircLineIn.isParamList(param):
    result = ircLineIn.params[param].split(",")


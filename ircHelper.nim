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

proc isUsernameUsed*(clients: Clients, user: string): bool =
  ## Checks if username is already in use
  return clients.contains(user)

proc isNicknameUsed*(clients: Clients, nick: string): bool = 
  ## Checks if nickname is already in use
  for client in clients.values:
    if client.nick == nick:
      return true
    return false  


proc getClientByNick*(clients: TableRef[string, Client], nick: string ): Client =
  # einaml returnd die scheisse Client
  for client in clients.values:
    if client.nick == nick:
      return client      

proc getRoomsByNick*(rooms: TableRef[string, Room], nick: string): seq[Room] =
  var username = clients.getClientByNick(nick).user
  result = @[]
  for room in rooms.values:
    if room.clients.contains(username):
      result.add(room)
      continue    

proc isAway*(client: Client): bool =
  return client.away.len > 0      
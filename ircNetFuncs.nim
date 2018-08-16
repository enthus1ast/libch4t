#
#
#                   libch4t 
#             (c) Copyright 2016 
#          David Krause, Tobias Freitag
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#
## Procs for the actual network communication

import ircDef
import ircParsing
import asyncnet, asyncdispatch
import config
import strutils
import tables
import sets
import sequtils

proc sendToClient*(client: Client, msg: string): Future[bool] {.async.} =
    if client.socket.isClosed():
      return false
    try:
      await client.socket.send( msg )
    except:
      echo "Send to client breaks.."
      return false
    return true      

proc recvFromClient*(client: Client): Future[IrcLineIn] {.async.} = 
  result.command = TError # error until we set something else
  try:
    var lineRawFut = client.socket.recvLine()
    var lineRaw = await lineRawFut
    result = parseIncoming(lineRaw)
  except:
    echo("client socket died unexpected at recvLine")

proc sendToRoom*(ircServer: IrcServer, room: Room, msg: string) =
  ## sends a message to a room, if excludeUser is a valid user do not send msg 
  ## to this user
  for username in room.clients:
    if ircServer.clients.contains(username):
      var client = ircServer.clients[username]
      asyncCheck client.sendToClient(msg)
    else:
      echo "there is a user in a room which is not in clients list.... Bug?"

proc sendMotd*(ircServer: IrcServer, client: Client, modt: string) =
  # sends a modt to the client
  var outp: string = ""
  outp.add(forgeAnswer(newIrcLineOut(SERVER_NAME,T375,@[client.nick],"Message of the day")))
  for line in modt.split("\n"):
    outp.add(forgeAnswer(newIrcLineOut(SERVER_NAME, T372, @[client.nick], "-" & line)))
  outp.add(forgeAnswer(newIrcLineOut(SERVER_NAME, T376, @[client.nick], "End of /MOTD command.")))
  asyncCheck client.sendToClient(outp)


proc pingClient*(ircServer: IrcServer, client: Client): Future[bool] {.async.}  =
  var line: IrcLineIn

  try:
    var gotten = await client.sendToClient(forgeAnswer(newIrcLineOut("",TPing,@[],PING_MSG)))
    if gotten == false:
      return false
  except:
    echo "exception in pingClient"
    return false

  try:
    line = await client.recvFromClient()
  except:
    echo "exception in ping client "
    return false

    if line.raw == "":
      return false

  if line.command == TPong:
    if line.trailer == PING_MSG:
      echo "ping anwered CORRECT (ping in trailer)"
      return true
    elif line.params.len > 0 and line.params[0] == PING_MSG:
      echo "ping anwered CORRECT (ping in line.params[0])"
      return true
    else:
      echo "ping anwered FALSE (got pong but wrong answer)"
      return false
  else:
    echo "ping anwered FALSE (got NO pong.)"
    return false    
    

proc sendTNames*(ircServer: IrcServer, client: Client, roomsToJoin: seq[string], lineByLine: bool = true) =
  ### LINE by LINE
  var answer: string = ""
  for room in roomsToJoin:
    if rooms.contains(room):
      if lineByLine:
        # for each user we send another line.
        for username in rooms[room].clients:
          var joinedClient = ircServer.clients[username]
          answer.add( forgeAnswer(newIrcLineOut(SERVER_NAME,T353,@[client.nick.strip(),"@",room],joinedClient.nick)) )
      else:
        var userLine: string = ""
        userline.add(client.nick & " ") # some irc clients want its own username as the first one
        for username in rooms[room].clients:
          let joinedClient = ircServer.clients[username] 
          if joinedClient.nick == client.nick: continue # skip ourself, we have been added above
          userLine.add(joinedClient.nick & " ") # BUG 
        userLine = userline.strip(trailing = true) # better not " " to last itm it in the first place TODO
        answer.add( forgeAnswer(newIrcLineOut(SERVER_NAME,T353,@[client.nick,"@",room],userLine)) )
        answer.add( forgeAnswer(newIrcLineOut(SERVER_NAME,T366,@[client.nick,room],"End of /NAMES list")) )
  if answer != "": # if we have something to answer
    discard client.sendToClient(answer)

proc sendTNames*(ircServer: IrcServer, client: Client, roomname: string, lineByLine: bool = false) =
  ircServer.sendTNames(client, roomname.split(","), lineByLine)


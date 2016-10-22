#
#
#                   libch4t 
#             (c) Copyright 2016 
#          David Krause, Tobias Freitag
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#
## This is the IRC Transport of libch4t.
## ATM its just a irc server 

import asyncnet, asyncdispatch, strutils, sequtils, tables
import ircDef
import config
import ircParsing
import logging
import ircNetFuncs
import ircHandler
import ircAuth
import ircHelper
import sets

proc isOperator(client: Client): bool = 
  ## TODO
  return true


proc authenticated(client: Client): bool = 
  # if the client is authenticated
  if client.user.validUserName() and client.nick.validUserName():
    return true
  else:
    return false


proc processClient(address: string, socket: AsyncSocket): Future[bool] {.async.} =
  var 
    client: Client = newClient(socket) # we create an client even if not authenticated yet
    ircLineIn: IrcLineIn
    line: string = ""

  client = await handleIrcAuth(client) # this will fill in the user/nick
  if client is void:
    return 
  clients[client.user] = client 

  while true:
    try:
      line = await client.socket.recvLine()
      echo "> ", line
    except:
      break 

    try:
      if line == "":
        echo("client leaves break out of main loop: ", client)
        
        # tell every room the client was joined that he has left
        for room in rooms.getRoomsByNick(client.nick):
          rooms.sendToRoom(room.name, forgeAnswer( newIrcLineOut(client.nick,TPart,@[room.name],"client disconnected! 61")))
        break

      ircLineIn = parseIncoming(line)

      if ircLineIn.command == TError:
        discard client.sendToClient( forgeAnswer(newIrcLineOut(SERVER_NAME,TError,@[],"Could not parse line")) )
        echo("Could not parse line: " & line)
        echo(getCurrentExceptionMsg())
        continue
    except:
      echo("Could not parse line (EXCEPION): " & line)
      echo(getCurrentExceptionMsg())
      continue

    if ircLineIn.command == TQuit:
      echo "client will quit removeing socket for: " , client
      client.socket.close()
      break

    ## Handles for every msg type.
    # client.hanTUser(ircLineIn) # TODO
    client.hanTNick(ircLineIn) # TODO
    if client.authenticated():
      client.hanTDebug(ircLineIn)
      client.hanTPing(ircLineIn)
      client.hanTPong(ircLineIn)
      client.hanTJoin(ircLineIn)
      client.hanTPart(ircLineIn)
      client.hanTNames(ircLineIn)
      client.hanTPrivmsg(ircLineIn)
      # client.hanTUserhost(ircLineIn)
      client.hanTAway(ircLineIn)
      # client.hanTCap(ircLineIn)
      # client.hanTDump(ircLineIn)
      # client.hanTWho(ircLineIn)
      client.hanTMotd(ircLineIn)

      ## Handles for operator only
      if client.isOperator():
      #  client.hanTByeBye(ircLineIn)
      #  client.hanTKick(rooms,ircLineIn)
      #  client.hanTKickHard(ircLineIn)
      #  client.hanTWall(ircLineIn)
        discard

    clients[client.user] = client # Updates the clients list


  # Remove client from every room its connected
  var roomsToDelete: seq[string] = @[]
  for room in rooms.values:
    if room.clients.contains(client.user):
      rooms[room.name].clients.excl(client.user)
      rooms.sendToRoom(room.name, forgeAnswer( newIrcLineOut(SERVER_NAME, TQuit, @[room.name, client.nick], "Client disconnected 114")) )
      if rooms[room.name].clients.len == 0:
        # room is empty remove it
        echo "room is empty remove it 117 ", room
        roomsToDelete.add(room.name)

  for roomname in roomsToDelete:
    rooms.del(roomname)



  # Remove client from list when they disconnect.
  for i,c in clients:
    if c == client:
      echo "[info] removing ", client
      try:
        clients.del i
      except:
        # debug("could not remove client $1 from clients" % [client.user] )
        debug("could not remove client from clients" )
      break

proc serveClient {.async.} =
  var server = newAsyncSocket()
  server.setSockOpt(OptReuseAddr, true)
  let port = Port(IRC_PORT)
  let iface  = IRC_IFACE
  server.bindAddr(port,address=iface)
  server.listen()
  while true:
    try:
      let socketClient = await server.acceptAddr()
      echo("Connection on client port from: ", socketClient.address)
      # echo await processClient(socketClient.address,socketClient.client)
      asyncCheck processClient(socketClient.address,socketClient.client)
    except:
      echo("Accept addr is fuckd")


asyncCheck serveClient()
runForever()
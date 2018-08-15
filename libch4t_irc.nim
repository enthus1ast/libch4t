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

proc processClient(address: string, socket: AsyncSocket): Future[bool] {.async.} =
  var 
    client: Client = newClient(socket) # we create an client even if not authenticated yet
    ircLineIn: IrcLineIn
    line: string = ""

  if (await handleIrcAuth(client)) == false: # this will fill in the user/nick
    if not client.socket.isClosed(): client.socket.close()
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
        echo("client leaves break out of main loop: ", repr client)
        
        # # tell every room the client was joined that he has left
        # for room in rooms.getRoomsByNick(client.nick):
        #   sendToRoom(room, forgeAnswer( newIrcLineOut(client.nick,TPart,@[room.name],"client disconnected! 61")))
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
      echo "client will quit removeing socket for: " , repr client
      client.socket.close()
      break

    ## Handles for every msg type.
    # client.hanTUser(ircLineIn) # TODO
    client.hanTNick(ircLineIn) # TODO
    if client.authenticated():
      client.hanTPing(ircLineIn)
      client.hanTPong(ircLineIn)
      client.hanTJoin(ircLineIn)
      client.hanTPart(ircLineIn)
      client.hanTNames(ircLineIn)
      client.hanTPrivmsg(ircLineIn)
      # client.hanTUserhost(ircLineIn)
      client.hanTAway(ircLineIn)
      # client.hanTCap(ircLineIn)
      client.hanTWho(ircLineIn)
      client.hanTMotd(ircLineIn)
      client.hanTLusers(ircLineIn)
      client.hanTList(ircLineIn)
      
      ## Handles for operator only
      if client.isOperator():
        client.hanTDump(ircLineIn)
        client.hanTDebug(ircLineIn)
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
      sendToRoom(room, forgeAnswer( newIrcLineOut(client.nick, TPart, @[room.name, client.nick], "Client disconnected (TPart) 116")) )
      if rooms[room.name].clients.len == 0:
        echo "room is empty remove it 117 ", room
        roomsToDelete.add(room.name)

  for roomname in roomsToDelete:
    rooms.del(roomname)

  # Remove client from list when they disconnect.
  for i,c in clients:
    if c == client:
      echo "[info] removing ", repr client
      try:
        clients.del i
      except:
        debug("could not remove client from clients" )
      break

proc serveClient {.async.} =
  var server = newAsyncSocket()
  server.setSockOpt(OptReuseAddr, true)
  let port = Port(IRC_PORT)
  let iface  = IRC_IFACE
  server.bindAddr(port,address=iface)
  server.listen()

  echo "##################################################"
  echo "### libch4t irc transport started up on ", IRC_PORT
  echo "##################################################\n"

  while true:
    try:
      let socketClient = await server.acceptAddr()
      echo("Connection on client port from: ", socketClient.address)
      asyncCheck processClient(socketClient.address,socketClient.client)
    except:
      echo("Accept addr is fuckd")

when not defined release:
  parsingSelftest()

asyncCheck serveClient()
runForever()
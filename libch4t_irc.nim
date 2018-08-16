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

import asyncnet, asyncdispatch, strutils, sequtils, tables, net, os
import ircDef
import config
import ircParsing
import logging
import ircNetFuncs
import ircHandler
import ircAuth
import ircHelper
import sets

proc processClient(ircServer: IrcServer, address: string, socket: AsyncSocket): Future[bool] {.async.} =
  var 
    client: Client = newClient(socket) # we create an client even if not authenticated yet
    ircLineIn: IrcLineIn
    line: string = ""

  if (await ircServer.handleIrcAuth(client)) == false: # this will fill in the user/nick
    if not client.socket.isClosed(): 
      # client.socket.
      try :
        client.socket.close()
      except SslError:
        echo "SSL error catched??"
    return

  ircServer.clients[client.user] = client 

  while true:
    try:
      line = await client.socket.recvLine()
      echo "> ", line
    except:
      break 

    try:
      if line == "":
        echo("client leaves break out of main loop: ", client.nick)
        
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
      echo "client will quit removeing socket for: " , client.nick
      client.socket.close()
      break

    ## Handles for every msg type.
    # client.hanTUser(ircLineIn) # TODO
    ircServer.hanTNick(client, ircLineIn) # TODO
    if client.authenticated():
      ircServer.hanTPing(client, ircLineIn)
      ircServer.hanTPong(client, ircLineIn)
      ircServer.hanTJoin(client, ircLineIn)
      ircServer.hanTPart(client, ircLineIn)
      ircServer.hanTNames(client, ircLineIn)
      ircServer.hanTPrivmsg(client, ircLineIn)
      # ircServer.hanTUserhost(client, ircLineIn)
      ircServer.hanTAway(client, ircLineIn)
      # ircServer.hanTCap(client, ircLineIn)
      ircServer.hanTWho(client, ircLineIn)
      ircServer.hanTMotd(client, ircLineIn)
      ircServer.hanTLusers(client, ircLineIn)
      ircServer.hanTList(client, ircLineIn)
      
      ## Handles for operator only
      if client.isOperator():
        ircServer.hanTDump(client, ircLineIn)
        ircServer.hanTDebug(client, ircLineIn)
      #  client.hanTByeBye(ircLineIn)
      #  client.hanTKick(rooms,ircLineIn)
      #  client.hanTKickHard(ircLineIn)
      #  client.hanTWall(ircLineIn)
        discard

    ircServer.clients[client.user] = client # Updates the clients list

  # Remove client from every room its connected
  var roomsToDelete: seq[string] = @[]
  for room in ircServer.rooms.values:
    if room.clients.contains(client.user):
      ircServer.rooms[room.name].clients.excl(client.user)
      ircServer.sendToRoom(room, forgeAnswer( newIrcLineOut(client.nick, TPart, @[room.name, client.nick], "Client disconnected (TPart) 116")) )
      if ircServer.rooms[room.name].clients.len == 0:
        echo "room is empty remove it 117 ", room
        roomsToDelete.add(room.name)

  for roomname in roomsToDelete:
    ircServer.rooms.del(roomname)

  # Remove client from list when they disconnect.
  for i,c in ircServer.clients:
    if c == client:
      echo "[info] removing ", client.nick
      try:
        ircServer.clients.del i
      except:
        debug("could not remove client from clients" )
      break

proc wrapServerSocket(sock: AsyncSocket, protoVersion = protTLSv1) =
  let path = SSL_CERT_FILE.absolutePath(getAppDir())
  var ctx = newContext(protoVersion, CVerifyNone ,certFile = path, keyFile = path)
  # ctx.wrapSocket(sock)
  ctx.wrapConnectedSocket(sock, handshakeAsServer)


proc serveClient(ircServer: IrcServer) {.async.} =
  var server = newAsyncSocket()
  server.setSockOpt(OptReuseAddr, true)
  let port = Port(IRC_PORT)
  let iface  = IRC_IFACE
  server.bindAddr(port,address=iface)
  server.listen()
  if SSL_ENABLED:
    server.wrapServerSocket()

  
  echo "##################################################"
  echo "### libch4t irc transport started up on ", IRC_PORT
  echo "##################################################\n"

  while true:
    try:
      let socketClient = await server.acceptAddr()
      if SSL_ENABLED:
        wrapServerSocket(socketClient.client)
      echo("Connection on client port from: ", socketClient.address)
      asyncCheck ircServer.processClient(socketClient.address,socketClient.client)
    except:
      echo("Accept addr is fuckd")

when not defined release:
  parsingSelftest()

when isMainModule:
  var ircServer = newIrcServer()
  asyncCheck ircServer.serveClient()
  runForever()
#
#
#                   libch4t 
#             (c) Copyright 2016 
#          David Krause, Tobias Freitag
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#


import asyncnet, asyncdispatch, strutils, sequtils, tables
import ch4tdef
import config
import ircParsing
import logging
import netFuncs
import ircHandler
import ircAuth
import helper
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
  var client: Client = newClient(socket) # we create an client even if not authenticated yet
  # try:
  client = await handleIrcAuth(client) # this will fill in the user/nick
  if client is void:
    return 
  # except:
    # echo "Exception in handleIrcAuth catched in processClient"
    # return false

  echo "nick in PROCESS CLIENT: ", client
  # if client.nick == "" or client.user == "":
  #   return
  clients[client.user] = client

  var ircLineIn: IrcLineIn
  var line: string = ""

  while true:
    try:
      line = await client.socket.recvLine()
      echo line
    except:
      break 

    try:
      if line == "":
        # client leaves
        echo("client leaves, break out of main loop...52")
        # tell every channel the client was joined that he has left
        # clients.del(client.user) # wenn user nicht deklariert ist?
        # for room in rooms.getRoomsByNick(client.nick):
        #   echo room
        #   for username in room.clients:
        #     var connectedClient = clients[username]
        #     discard connectedClient.sendToClient( forgeAnswer((client.nick,TPart,@[room.name] ,"client disconnected!")))
        #  # room.send( forgeAnswer((SERVER_NAME, TPart, )) )
        break

      echo "> ", line
      ircLineIn = parseIncoming(line)

      if ircLineIn.command == TError:
        # if we the parser decided that this is an error
        # discard client.sendToClient( forgeAnswer((SERVER_NAME,TError,@[],"Could not parse line")) )
        echo("Could not parse line 609: " & line)
        # error(getCurrentException().name)
        echo(getCurrentExceptionMsg())
        continue
    except:
      # if the parser thrown an exception while parsing.
      # TODO dump error to logfile
      # error("Could not parse line 616: " & line)
      # error(getCurrentException().name)
      # error(getCurrentException().msg)
      echo(getCurrentExceptionMsg())
      continue

    if ircLineIn.command == TQuit:
      echo "client will quit.."
      client.socket.close()
      echo client
      break

    ## Handles for every msg type.
    client.hanTUser(ircLineIn) # TODO
    # client.hanTNick(ircLineIn) # TODO know buggy

    if client.authenticated():
      client.hanTDebug(ircLineIn)
      client.hanTPing(ircLineIn)
      client.hanTPong(ircLineIn)
      client.hanTJoin(ircLineIn)
      client.hanTPart(ircLineIn)
      # client.hanTNames(ircLineIn)
      client.hanTPrivmsg(ircLineIn)
      # client.hanTUserhost(ircLineIn)
      # client.hanTAway(ircLineIn)
      # client.hanTCap(ircLineIn)
      # client.hanTDump(ircLineIn)
      # client.hanTWho(ircLineIn)
      # client.hanTMotd(ircLineIn)


      ## Handles for operator only
      if client.isOperator():
      #  client.hanTByeBye(ircLineIn)
      #  client.hanTKick(rooms,ircLineIn)
      #  client.hanTKickHard(ircLineIn)
      #  client.hanTWall(ircLineIn)
        discard

    clients[client.user] = client # Updates the clients list

  # Remove client from list when they disconnect.
  for i,c in clients:
    if c == client:
      echo "[info] removing ", client
      try:
        echo clients
        clients.del i
      except:
        # debug("could not remove client $1 from clients" % [client.user] )
        debug("could not remove client from clients" )
      break

  # Then remove client from every room its connected
  for room in rooms.values:
    if room.clients.contains(client.user):
      rooms[room.name].clients.excl(client.user)
      rooms.sendToRoom(room.name, forgeAnswer( newIrcLineOut(SERVER_NAME, TQuit, @[room.name, client.nick], "Client disconnected")) )




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
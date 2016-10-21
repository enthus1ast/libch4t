#
#
#                   libch4t 
#             (c) Copyright 2016 
#          David Krause, Tobias Freitag
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#


import ch4tdef
import ircParsing
import asyncnet, asyncdispatch
import netFuncs
import config
import ircHandler
import helper

proc handleIrcAuth*(aClient: Client): Future[Client] {.async.} =
  ## TODO # some code here belongs to the main loop
  ## This checks if the user has been authenticated
  ## by tUser and tNick
  ## then it greets the user with 001 and returns true
  # var line: string
  var ircLineIn: IrcLineIn
  var client: Client = aClient
  var line: string = ""
  var pingGood: bool = false
  
  while true:
    try:
      line = await client.socket.recvLine()
    except:
      echo "socket revc line breaks in handleIrcAuth, breaking"
      break

    if line == "":
      echo "line is empty in handleIrcAuth, breaking"
      break

    ircLineIn = parseIncoming(line)
    if ircLineIn.command == TError:
      asyncCheck client.sendToClient(forgeAnswer(newIrcLineOut(SERVER_NAME,TError,@[],"Could not parse line")))
      echo("Could not parse line 33: " & line)
      continue # when the user has a typo 

    echo line
    hanTUser(client,ircLineIn)
    hanTNick(client,ircLineIn)
    if client.nick != "" and client.user != "" :
      # only the first ping is mandatory atm.
      # TODO
      
      if await client.pingClient():
          echo "ping was answered good"
          pingGood = true
          # break
      else:
          echo "ping was answered false"
          pingGood = false
          client.socket.close()
          # break
    
      if pingGood == true:
        
        let answer = forgeAnswer(newIrcLineOut(SERVER_NAME,T001,@[client.nick],"Welcome to libch4t irc server, this is a toy please dont't break it"))
        echo "<",answer
        discard await client.sendToClient(answer)

        #:wilhelm.freenode.net NOTICE * :*** Checking Ident
        discard await client.sendToClient(forgeAnswer(newIrcLineOut("NickServ", TNotice, @[client.nick],"Welcome to libch4ts irc transport")))
        discard await client.sendToClient(forgeAnswer(newIrcLineOut("NickServ", TNotice, @[client.nick],"visit "&SERVER_URL&"")))

        echo("Client authenticated successfully: ", client)
        discard client.sendToClient(forgeAnswer(newIrcLineOut(client.nick, TMode, @[client.nick],"+i")))
        client.sendMotd(MOTD)
        return client
  return client # we have to return in any case.
#
#
#                   libch4t 
#             (c) Copyright 2016 
#          David Krause, Tobias Freitag
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#
## The IRC Commands this server should handle

import ircDef
import ircHelper
import sets
import tables
import strutils
import ircParsing
import ircNetFuncs
import config

proc hanTAway*(client: var Client, line: IrcLineIn) =
  ## Set the away msg of a user
  var awayMessage: string
  if line.command == TAway:
    if line.trailer.len > 0: # Mark as away
      awayMessage = line.trailer
    elif line.params.len > 0: # Mark as away
      awayMessage = line.params[0]
    else: # Mark as comeback
      awayMessage = ""
      echo("- Client $1 become available!" % [client.user,])
    client.away = awayMessage
    echo("- Client $1 is away: $2" % [client.user, client.away])


proc hanTNames*(client: Client, line: IrcLineIn ) =
  if line.command == TNames: # or line.command == TWho:
    if line.params.len > 0:
      client.sendTNames(line.params[0])


proc hanTMotd*(client: Client, line: IrcLineIn) =
  if line.command == TMotd:
    client.sendMotd(MOTD)


proc hanTUser*(client: var Client, line: IrcLineIn) =
  if line.command == TUser:
    if line.params.len > 0:
      # TODO here we should check if the user is already logged in and if its registered
      # we should additionally check the password
      var user = line.params[0]
      if  (user != "") and (user.validUserName() == true) and (not clients.isUsernameUsed(user)):
        client.user = user
        # echo("GOT VALID USER FROM: " & $client)
      else:
        echo("GOT INVALID USER / user already in use FROM: " & $client)


proc hanTNick*(client: var Client, line: IrcLineIn) =
  ## TODO should change username in clients and rooms
  ## atm this is only working for the login
  if line.command == TNick:
    # TODO here we should check if the user is already logged in and if its registered
    # we should additionally check the password
    var nick: string = ""
    if line.params.len > 0:
      nick = line.params[0] #.strip()
    elif line.trailer != "":
      nick = line.trailer
    else:
      echo("got no user from ", client)
      return

    if (nick != "") and (nick.validUserName()) and (not clients.isNicknameUsed(nick)):
      echo "user ", client, " changed nickname to :" , nick
      var oldnickname = client.nick
      client.nick = nick
      clients[client.user] = client

      # we inform our own client that we have sucessfully changed the nickname
      discard client.sendToClient(forgeAnswer(newIrcLineOut(oldnickname, TNick, @[], client.nick )))

      # now we inform every user that should know about our namechange that we have changed names.
      for usernameToAnswer in rooms.getParticipatingUsersByNick(client.nick):
        var foundClient = clients[usernameToAnswer]
        discard foundClient.sendToClient(forgeAnswer(newIrcLineOut(oldnickname, TNick, @[], client.nick )))
    else:
      echo("GOT INVALID NICK / nickname in use FROM: " & $client)      


proc hanTPing*(client: Client, line: IrcLineIn) =
  # ping
  # ping 1234
  # ping :123
  # ping 1234 :5678
  if line.command == TPing:
    if line.params.len == 0 and line.trailer == "":
      # ping
      discard client.sendToClient(forgeAnswer(newIrcLineOut(SERVER_NAME, TPong, @[], ""))) # pong
    elif line.params.len == 0 and line.trailer != "":
      # ping :1234
      discard client.sendToClient(forgeAnswer(newIrcLineOut(SERVER_NAME, TPong, @[], line.trailer)))
    elif line.params.len != 0 and line.trailer == "":
      # ping 1234
      discard client.sendToClient(forgeAnswer(newIrcLineOut(SERVER_NAME, TPong, @[], join(line.params," ") )))
    elif (line.params.len() > 0 and line.trailer.len == 0) or (line.params.len == 0 and line.trailer.len > 0) or (line.params.len > 0 and line.trailer.len > 0):
      # discard client.sendToClient(forgeAnswer((SERVER_NAME, TPong, @[], answer)))
      discard #TODO debug


proc hanTPong*(client: Client, line: IrcLineIn) =
  # if line.toUpper.startsWith(TPong):
  if line.command == TPong:
    # We always want to choose the `first` one,
    # even if there was another trailer etc attached.
    var pingChallenge: string
    if line.params.len > 0:
      pingChallenge = line.params[0]
    elif line.trailer != "":
      pingChallenge = line.trailer
    else:
      pingChallenge = ""
    # echo("got PONG from: " & $client & " with challenge: " & pingChallenge )        


proc hanTJoin*(client: Client, line: IrcLineIn) =
  var 
      roomnamesToJoin: seq[string] = @[]

  if line.command != TJoin:
    return

  if line.isParamList():
    ## eg: JOIN #kl,#ai
    for part in line.getParamList():
      if part.validRoomName():
        roomnamesToJoin.add(part)
  elif line.params.len > 0:
    ## eg: JOIN #kl #ai
    for param in line.params:
      if param.validRoomName():
        roomnamesToJoin.add(param)

  for roomToJoin in roomnamesToJoin:
    if not roomToJoin.validRoomName():
      echo(client, " has tried to join invalid roomname: " , roomToJoin)
      continue
    echo "going to let join $1 to room $2" % [client.nick, roomToJoin]
    if rooms.contains(roomToJoin):
      echo "there is a room named ", roomToJoin
      var roomObj = rooms[roomToJoin]
      roomObj.clients.incl(client.user)
      rooms[roomToJoin] = roomObj # we update the room table
    else:
      echo "creating room ", roomToJoin
      rooms.add(roomToJoin, newRoom(roomToJoin))
      rooms[roomToJoin].clients.incl(client.user)

    # tell everyone we're just joined
    # by sending userlist to everybody        
    sendToRoom(rooms[roomToJoin], forgeAnswer(newIrcLineOut(client.nick, TJoin, @[roomToJoin],"" )))
    
    # we initially send the names list to clients.
    # let them update their user list
    client.sendTNames(roomToJoin)


proc hanTPart*(client: Client, line: IrcLineIn) =
  # disconnect from a channel
  if line.command != TPart:
    return 

  var roomsToLeave: seq[string] = @[]
  
  if line.params.len > 0:
    # if '*' we leave all rooms 
    if line.params[0] == "*":
      for room in rooms.getRoomsByNick(client.nick):
        roomsToLeave.add(room.name)    
    else:
      for room in line.params[0].split(","):
        if room.validRoomName() and rooms.contains(room):
          roomsToLeave.add(room) 
        else:
          echo("No such room: ", room)
    for room in roomsToLeave:
      try:  
        if rooms[room].clients.contains(client.user):
          sendToRoom(rooms[room], forgeAnswer( newIrcLineOut(client.nick,TPart,@[room],line.trailer)))
          rooms.mget(room).clients.excl(client.user)

        if rooms[room].clients.len == 0:
          echo "room is empty remove it 161 ", room
          rooms.del(room)          
      except:
        echo("User ", client.user , " is not in room ", room)     


proc hanTPrivmsg*(client:Client, line: IrcLineIn) =
  if line.command == TPrivmsg:
    var newTrailer = line.trailer

    # some clients forget the ":" iF only one word is given
    if line.params.len > 1:
      newTrailer = line.params[1] & newTrailer

    if line.params.len > 0: # we have to check if we have enough parameters
      if line.params[0].startswith("#") or line.params[0].startswith("&"):
        let roomToSend = line.params[0]
        # we send to a room historically a room in irc could start with '#' or '&''
  
        if rooms.contains(roomToSend):
          if rooms[roomToSend].clients.contains(client.user): 
            # check if a user has joined the room (only then allowed to write)
            for connectedClient in rooms[roomToSend].clients:
              let answer = forgeAnswer(newIrcLineOut(client.nick,TPrivmsg,@[roomToSend], newTrailer))
              if connectedClient != client.user: #exlude ourself
                echo $TPrivmsg, " to " , connectedClient , " -> " , answer.strip()
                discard clients[connectedClient].sendToClient(answer)
      else:
        # this is a private message to a user
        var clientToAnswer = clients.getClientByNick(line.params[0])
        if clientToAnswer.nick == line.params[0]:
          # Send private message to receiver
          let answer = forgeAnswer(newIrcLineOut(client.nick, TPrivmsg, @[clientToAnswer.nick], newTrailer))
          discard clientToAnswer.sendToClient(answer)
          if clientToAnswer.isAway == true:
            # Send receivers away message to sender
            let isAwayAnswer = forgeAnswer(newIrcLineOut(clientToAnswer.nick, TPrivmsg, @[clientToAnswer.nick], clientToAnswer.away))
            discard client.sendToClient(isAwayAnswer)
          else:
            echo "Client is available: ", client
        else:
          echo("Nick:", line.params[0], " not found")


proc hanTWho*(client: Client, line: IrcLineIn) =
  if line.command == TWho:
    # TODO here we should check if the user is already logged in or joined a channel
    # and if its registered
    # we should additionally check the password
    if line.params.len > 0:
      for room in line.params[0].split(","):
        if validRoomName(room):
          if rooms.contains(room):
            for clientName in rooms[room].clients:
              var joinedClient = clients[clientName]
              var answer = forgeAnswer(newIrcLineOut(SERVER_NAME,T352,@[client.nick,room,joinedClient.nick, "shadowedDNS", SERVER_NAME, joinedClient.nick, ""],"0 dummyuser"))
              answer = answer.removeDoubleWhite()
              discard client.sendToClient(answer)
            let answer = forgeAnswer(newIrcLineOut(SERVER_NAME,T315,@[client.nick,room],"End of /WHO list"))
            discard client.sendToClient(answer)

proc hanTLusers*(client: Client, line: IrcLineIn) = 
  ## TODO
  if line.command == TLusers:
    var output: string = ""
    output.add forgeAnswer(newIrcLineOut(SERVER_NAME, T251, @[client.nick], "There are $1 users and $2 invisible on $3 servers" % ["0", $clients.len, "1"]))
    output.add forgeAnswer(newIrcLineOut(SERVER_NAME, T252, @[client.nick, "0"], "operator(s) online"))
    output.add forgeAnswer(newIrcLineOut(SERVER_NAME, T253, @[client.nick,"0"], "unknown connection(s)"))
    output.add forgeAnswer(newIrcLineOut(SERVER_NAME, T254, @[client.nick,$rooms.len()], "channels formed"))
    output.add forgeAnswer(newIrcLineOut(SERVER_NAME, T255, @[client.nick], "I have $1 clients and $2 servers" % [$clients.len,"1"]))
    discard client.sendToClient(output)

proc hanTList*(client: Client, line: IrcLineIn) = 
  ## returns a list of all rooms if no param given
  ## if params given list only them 
  if line.command != TList:
    return 

  var 
      roomNamesToList: seq[string] = @[]
      output: string = ""
      room: Room

  if line.isParamList():
    ## param is like: #foo,#baa
    roomNamesToList = line.getParamList()
  elif line.params.len > 0:
    ## param is like so: #foo #baa
    for param in line.params:
      roomNamesToList.add(param)
  elif line.params.len == 0:
    ## no params are given so we list every known room.
    for room in rooms.values:
        roomNamesToList.add(room.name)    

  ## Build the answer
  output.add(forgeAnswer(newIrcLineOut(SERVER_NAME,T321,@[client.nick,"Channel","Users"],"Name")))
  for roomName in roomNamesToList:
    if roomName in rooms:
      room = rooms[roomName]
      output.add(forgeAnswer(newIrcLineOut(SERVER_NAME,T322,@[client.nick, room.name,$room.clients.len], "ROOM TOPIC IS NOT IMPLEMENTED")))
  output.add(forgeAnswer(newIrcLineOut(SERVER_NAME,T323,@[client.nick],"End of /LIST")))          
  discard client.sendToClient(output)


proc genDebugStr(): string =
    result = ""
    result.add "-\n-\n-\n"
    result.add "Connected Clients\n"
    result.add "#################\n"
    for i,each in clients:
      result.add "[$1] $2\n" % [i, $each] 
    
    result.add "\n"
    result.add "Rooms\n"
    result.add "#####\n"
    for room in rooms.values:
      result.add ("Roomname: " & room.name & " " & $room.clients.len  & "\n")
      for cl in room.clients:
        # result.add "-- cl: " & cl & "[" & clients[cl].nick  & "]" & "\n"
        result.add "-- cl: "  & cl & "  " & $clients[cl] & "\n"

proc hanTDump*(client: Client, line: IrcLineIn) =
  if line.command == TDump:
    for part in genDebugStr().split("\n"):
      discard client.sendToClient( forgeAnswer(newIrcLineOut(SERVER_NAME, TPrivmsg, @[client.nick], part )) )  


proc hanTDebug*(client: Client, line: IrcLineIn) =
  if line.command == TDebug:
    echo genDebugStr()


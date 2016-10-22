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
      if user.validUserName() and not clients.isUsernameUsed(user):
        client.user = user
        # echo("GOT VALID USER FROM: " & $client)
      else:
        echo("GOT INVALID USER / user already in use FROM: " & $client)


proc hanTNick*(client: var Client, line: IrcLineIn) =
  ## TODO should change username in clients and rooms
  ## atm this is only working for the loging
  if line.command == TNick:
    # TODO here we should check if the user is already logged in and if its registered
    # we should additionally check the password
    if line.params.len > 0:
      var nick = line.params[0] #.strip()
      if nick.validUserName() and not clients.isNicknameUsed(nick):
        client.nick = nick
        # echo("GOT VALID NICK FROM: " & $client)
      else:
        echo("GOT INVALID NICK / nickname in use FROM: " & $client)
        # discard client.socket.send("invalid nick") # invalid nick        


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
  if line.command == TJoin and line.params.len > 0:
    for roomToJoin in line.params[0].split(","):
      if not roomToJoin.validRoomName():
        echo(client, " has tried to join invalid roomname: " , roomToJoin)
        continue
      echo "going to let join $1 to room $2" % [client.nick, roomToJoin]
      if rooms.contains(roomToJoin):
        echo "there is a room named ", roomToJoin
        var roomObj = rooms[roomToJoin]
        roomObj.clients.incl(client.user)

        # Tell the client he has joined
        discard client.sendToClient(forgeAnswer(newIrcLineOut(client.nick & "!" & SERVER_NAME,TJoin,@[roomToJoin],"")))
        
        rooms[roomToJoin] = roomObj
      else:
        echo "creating room ", roomToJoin
        rooms.add(roomToJoin, newRoom(roomToJoin))
        rooms[roomToJoin].clients.incl(client.user)
        discard client.sendToClient(forgeAnswer(newIrcLineOut(client.nick & "!" & SERVER_NAME, TJoin, @[roomToJoin], "")))

      # tell everyone we're just joined
      # by sending userlist to everybody        
      rooms.sendToRoom(roomToJoin, forgeAnswer(newIrcLineOut(client.nick, TJoin, @[roomToJoin],"" )))
      
      # we initially send the names list to clients.
      # let them update their user list
      client.sendTNames(roomToJoin)


proc hanTPart*(client: Client, line: IrcLineIn) =
  # disconnect from a channel
  if line.command == TPart:
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
          rooms.mget(room).clients.excl(client.user)
          rooms.sendToRoom(room, forgeAnswer( newIrcLineOut(client.nick,TPart,@[room],line.trailer)))
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



proc hanTDebug*(client: Client, line: IrcLineIn) =
  if line.command == TDebug:
    echo ""
    echo "Connected Clients"
    echo "#################"
    for i,each in clients:
      echo "[$1] $2" % [i, $each] 
    
    echo ""
    echo "Rooms"
    echo "#####"
    for room in rooms.values:
      echo "Roomname: ", room.name, " ", room.clients.len
      for cl in room.clients:
        echo "-- cl: ", cl

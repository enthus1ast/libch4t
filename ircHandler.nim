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
import helper
import sets
import tables
import strutils
import ircParsing
import netfuncs

template hanTUser*(client: Client, line: IrcLineIn) =
  ## USER enthus1ast * irc.freenode.net :ent
  # result = client
  if line.command == TUser:
    echo("GOT USER REQUEST")
    if line.params.len > 0:
      # TODO here we should check if the user is already logged in and if its registered
      # we should additionally check the password
      var user = line.params[0]
      if user.validUserName() and not clients.isUsernameUsed(user):
        client.user = user
        echo("GOT VALID USER FROM: " & $client)
      else:
        echo("GOT INVALID USER / user already in use FROM: " & $client)

template hanTNick*(client: Client, line: IrcLineIn) =
  ## TODO should change username in clients and rooms
  ## atm this is only working for the loging
  ## NICK enthus1ast
  # result = client
  if line.command == TNick:
    echo("GOT NICK REQUEST")
    # TODO here we should check if the user is already logged in and if its registered
    # we should additionally check the password
    if line.params.len > 0:
      var nick = line.params[0] #.strip()
      if nick.validUserName() and not clients.isNicknameUsed(nick):
        # result.nick = nick
        client.nick = nick
        echo("GOT VALID NICK FROM: " & $client)
      else:
        echo("GOT INVALID NICK / nickname in use FROM: " & $client)
        # discard client.socket.send("invalid nick") # invalid nick        


template hanTPing*(client: Client, line: IrcLineIn) =
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
      # let answer = (line.raw.strip())[len($TPing)..^1]
      # discard client.sendToClient(forgeAnswer((SERVER_NAME, TPong, @[], answer)))
      discard #TODO debug

template hanTPong*(client: Client, line: IrcLineIn) =
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
    echo("got PONG from: " & $client & " with challenge: " & pingChallenge )        


template hanTJoin*(client: Client, line: IrcLineIn) =
  if line.command == TJoin and line.params.len > 0:
    for roomToJoin in line.params[0].split(","):
      if not roomToJoin.validRoomName():
        info(client, " has tried to join invalid roomname: " , roomToJoin)
        continue
      debug "going to let join $1 to room $2" % [client.nick, roomToJoin]
      if rooms.contains(roomToJoin):
        debug "there is a room named ", roomToJoin
        var roomObj = rooms[roomToJoin]
        roomObj.clients.incl(client.user)
        # Tell the client he has joined
        discard client.sendToClient(forgeAnswer(newIrcLineOut(client.nick & "!" & SERVER_NAME,TJoin,@[roomToJoin],"")))
        # tell everyone we're just joined
        # by sending userlist to everybody
        rooms[roomToJoin] = roomObj
      else:
        debug "creating room ", roomToJoin
        rooms.add(roomToJoin, newRoom(roomToJoin))
        # discard rooms[roomToJoin].clients.mgetOrPut(client.user, cast[ref Client](addr(client)))
        rooms[roomToJoin].clients.incl(client.user)
        discard client.sendToClient(forgeAnswer(newIrcLineOut(client.nick & "!" & SERVER_NAME, TJoin, @[roomToJoin], "")))
      # Was wir nachm join machen
      # discard client.pingClient()
      rooms.sendToRoom(roomToJoin, forgeAnswer(newIrcLineOut(client.nick, TJoin, @[roomToJoin],"" )))
    # we initially send the names list to clients.
    # let them update their user list
    client.sendTNames(line.params[0])


proc hanTPart*(client: Client, line: IrcLineIn) =
  # disconnects from a channel
  # part #lobby
  # part #linux
  # :HJJJJJ!~jkjkjkjkd@p5DC54B1A.dip0.t-ipconnect.de PART #linux
  if line.command == TPart:
    var roomsToLeave: seq[string] = @[]
    echo $TPart
    if line.params.len > 0:
      # if '*' we leave all rooms 
      if line.params[0] == "*":
        for room in rooms.getRoomsByNick(client.nick):
          echo room
          roomsToLeave.add(room.name)    
      else:
        for room in line.params[0].split(","):
          if room.validRoomName() and rooms.contains(room):
            roomsToLeave.add(room) 
            # gets send directly to all
            # :WiZ!jto@tolsun.oulu.fi PART #playzone :I lost
          else:
            echo("No such room: ", room)
      for room in roomsToLeave:
        try:  
          # rooms.mget(room).clients.del(client.user)
          rooms.sendToRoom(room, forgeAnswer( newIrcLineOut(client.nick,TPart,@[room],line.trailer)))
          rooms.mget(room).clients.excl(client.user)
        except:
          echo("User ", client.user , " is not in room ", room)     


proc hanTPrivmsg*(client:Client, line: IrcLineIn) =
  # privmsg #lobby :was geht ab
  # privmsg sn0re :moin sn0re!

  if line.command == TPrivmsg:
    echo("GOT PRIVMSG FROM:" & $client)
    echo("`-> " & line.raw)

    # some clients forget the ":" in only one word is given
    var newTrailer = line.trailer
    if line.params.len > 1:
      newTrailer = line.params[1] & newTrailer

    # if line.params[0].validRoomName():  # 
    if line.params[0].startswith("#") or line.params[0].startswith("&"):
      echo "THIS IS  MESSAGE TO A ROOM"
      let roomToSend = line.params[0]
      # we send to a room historically a room in irc could start with '#' or '&''

      if rooms.contains(roomToSend):
        echo "rooms contains a room named", roomToSend 
        if rooms[roomToSend].clients.contains(client.user): 
          echo "user ", client, " is in room ", roomToSend
          # check if a user has joined the room (only then allowed to write)
          for connectedClient in rooms[roomToSend].clients:
            let answer = forgeAnswer(newIrcLineOut(client.nick,TPrivmsg,@[roomToSend], newTrailer))
            if connectedClient != client.user: #exlude ourself
              echo $TPrivmsg, " to " , connectedClient , " -> " , answer
              # asyncaCheck connectedClient.sendToClient(answer)
              discard clients[connectedClient].sendToClient(answer)

      # if rooms.getOrDefault(line.params[0]).clients.contains(client.user):
      #   for connectedClient in getConnectedClients(line.params[0]):
      #     let answer = forgeAnswer((client.nick,TPrivmsg,@[line.params[0]], newTrailer))
      #     if connectedClient[] != client:
      #       # exclude ourself
      #       echo $TPrivmsg, " to " , connectedClient[] , " -> " , answer
      #       discard connectedClient.sendToClient(answer)
    else:
      # PRIVMSG mynickname :Hi whats up?
      # this is a private message to a user
      echo "THIS IS  MESSAGE TO A CLIENT"
      var clientToAnswer = clients.getClientByNick(line.params[0])
      echo line.params[0]
      if clientToAnswer.nick == line.params[0]:
        # Send private message to receiver
        let answer = forgeAnswer(newIrcLineOut(client.nick, TPrivmsg, @[clientToAnswer.nick], newTrailer))
        discard clientToAnswer.sendToClient(answer)
        echo("MSG TO USER/NICK: " & answer)
        echo("TEST (AWAY MSG): " & clientToAnswer.away)
        if clientToAnswer.isAway == true:
          # Send receivers away message to sender
          let isAwayAnswer = forgeAnswer(newIrcLineOut(clientToAnswer.nick, TPrivmsg, @[clientToAnswer.nick], clientToAnswer.away)) #TODO: Use T301!!
          discard client.sendToClient(isAwayAnswer)
          echo("MSG (AWAY) FROM $1 to $2: $3" % [clientToAnswer.nick, client.nick, clientToAnswer.away])
        else:
          echo "####################"
          echo "CLIENT IS NOT AWAY"
          echo "####################"
      else:
        echo("Nick:", line.params[0], " not found")



template hanTDebug*(client: Client, line: IrcLineIn) =
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

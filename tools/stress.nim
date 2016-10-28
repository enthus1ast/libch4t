#
#
#                   libch4t 
#             (c) Copyright 2016 
#          David Krause, Tobias Freitag
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#
## This will stress libch4t
import net
import strutils


const IRC_SERVER = "127.0.0.1"
# const IRC_SERVER = "192.168.2.155"
const IRC_PORT = 6667


template login(socket: Socket, user,nick: string, pong:bool = true) = 
  echo "login with: ", user, " ", nick, " ", pong
  socket.send("USER " & user & "\n")  
  socket.send("NICK " & nick & "\n")
  
  if pong:
    # var line: string = ""
    # socket.readLine(line)
    # if "PING" in line:
    socket.send("PONG :t\n")  

template aFewHalfLogins() = 
  echo "aFewHalfLogins"
  for each in 1..10:
    var socket = newSocket()
    socket.connect(IRC_SERVER, Port(IRC_PORT))
    socket.send("USER " & "ufoo" & $each & "\n")  
    socket.send("NICK " & "nfoo" & $each )
    write(stdout,"\c" & $each)
    socket.close()
  echo ""


template join(room: string) =
  socket.send("JOIN " &  $each & "\n")  

template spam(str: string, count: int = 1_000) =
  echo "spamming[$1] $2 " % [$count, str]
  for each in 0..count:
    write(stdout,"\c" & $each)
    socket.send(str)

template spam(arr: seq[string], count: int = 1_000) =
  for i in 0..count:
    for elem in arr:
      spam(elem,1)

template confirm(levelname: string ="") = 
  echo "passed? press enter for next level... " & levelname
  discard readLine(stdin)

template aFewJoins(count: int = 1_000) = 
  var line = ""
  for each in 0..count:
    line = "JOIN #spam$1\n" % [$each]
    write(stdout,"\c" & $each)
    socket.send(line)    

template aFewUsers(count: int = 10_000) =
  var sockets: seq[Socket] = @[]
  for each in 0..count:
    var socket = newSocket()
    socket.connect(IRC_SERVER, Port(IRC_PORT))
    socket.login("stress" & $each, "stress" & $each)
    sockets.add(socket)
  confirm("LET " & $count & " JOIN #lobby !! (this is blowing up libch4t atm...)")
  for each in sockets:
    each.send("JOIN #lobby\n")

aFewHalfLogins()
confirm()

var socket = newSocket()
socket.connect(IRC_SERVER, Port(IRC_PORT))
socket.login("foo", "baa",true)
confirm()
spam("privmsg baa :stress\n")
confirm()
spam("\n")
confirm()
spam(" ")
confirm()
spam("USER a\n")
confirm()
spam(@["join #kl\n","part #kl\n"])
confirm()
spam(@["part #kl\n","join #kl\n","privmsg #kl :stress\n"])
confirm("aFewJoins")
aFewJoins()
confirm("pings")
spam("ping\n")
confirm("a few users")
aFewUsers()

echo "done, hopefully libch4t is still running ;) press key"
discard readLine(stdin)

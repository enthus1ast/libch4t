#
#
#             libch4t - nrv irc bot
#        (c) Copyright 2016 David Krause
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#
##
## "Learning" IRC chatbot to test libch4t_irc
## 


import random
import net
import strutils
import sequtils
import "../ircParsing"
import "../ch4tdef"

const
  BOTNAME = "nrv"

var oners = newSeq[string]()
oners.add("Weist du was wir machen könnten? $1")
oners.add("Ey $1")
oners.add("$1 NEIN DU!1!!")

var noners = newSeq[string]()

noners ="""
Klaus sagt das auch immer
Nein du
ok
t
bist du repulsive?
: )
haha

""".split("\n")

var namers = newSeq[string]()
namers.add("$1 weißt du was?")

proc readLineDump(): seq[string] =
  var files:File
  discard files.open("linedump.txt")
  result = files.readAll().split("\n")

proc connectToIrc(socket: Socket, host: string, port: int, channels = @["#lobby"]): Socket =  
  socket.connect(host, Port(port))
  echo "Connected..."  
  if socket.trySend("USER " & BOTNAME & "\n" ) and socket.trySend("NICK " & BOTNAME & "\n" ):
    var pingChallenge: string = ""
    socket.readLine(pingChallenge,2000)
    var ircLine = parseIncoming( pingChallenge )
    discard socket.trySend( $TPong & " :" & ircLine.trailer & "\n")
    # socket.readLine(line,2000)
    # echo line
    for room in channels:
      discard socket.trySend("PART " & room & "\n") # we quit at first
      discard socket.trySend("JOIN " & room & "\n")
  return socket

proc suchWasRaus(s: string): string =
  var finds: seq[string] = @[]
  for each in noners:
    for spart in s.split(" "):
      if spart in each:
        if s != each:
          finds.add(s)
  if finds.len > 0:
    return random(finds)
  else:
    return ""

var nsaLines: seq[string] = @[]
var sock = newSocket().connectToIrc("127.0.0.1",6667)
var line: string = ""
var ircLine: IrcLineIn

noners = noners & readLineDump()

var dumpFile: File
discard dumpFile.open("linedump.txt",fmAppend)
# proc sendNoner():
while true:
  try:
    sock.readLine(line,random(1000..20_000))
    if line == "":
      break
    # sock.readLine(line,1000)
    ircLine = parseIncoming(line)
    echo(">",line)
    if ircLine.command == TPrivmsg:
      dumpFile.writeLine(ircLine.trailer)
      dumpFile.flushFile()

      if ircLine.trailer == "":
        continue

      elif ircLine.trailer == "t":
        discard sock.trySend( "privmsg $1 :$2\n" % ["#lobby","t"])

      elif ircLine.trailer == "tt":
        discard sock.trySend( "privmsg $1 :$2\n" % ["hahahah"])        

      elif "repulsive" in ircLine.trailer.toLower():
        discard sock.trySend( "privmsg $1 :$2\n" % ["#lobby",["ja","nein"].random()] )
        discard sock.trySend( "privmsg $1 :$2\n" % ["#lobby",["ok","bist du Repulsive?"].random()] )

      elif ircLine.trailer.strip().endswith("?"):
        echo (":: endswith ?")
        discard sock.trySend( "privmsg $1 :$2\n" % ["#lobby",["ja","nein","ka","später vielleicht","mhh","weiss nicht"].random()] )

      elif "oder" in ircLine.trailer:
        var possible = newSeq[string]()
        for each in noners:
          if "oder" in each:
            possible.add(each)
        discard sock.trySend( "privmsg $1 :$2\n" % ["#lobby",possible.random()])

      else:
        if [true,false].random():
          discard sock.trySend( "privmsg $1 :$2\n" % ["#lobby",noners.random()] )
        # discard sock.trySend( "privmsg $1 :$2\n" % ["#lobby",suchWasRaus(ircLine.trailer)])
      
      # In any case save for later babbeling...  
      noners.add(ircLine.trailer)
      noners = deduplicate(noners)

    
  except:
    discard sock.trySend( "privmsg $1 :$2\n" % ["#lobby",noners.random()] )
    discard
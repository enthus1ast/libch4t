#
#
#                   libch4t 
#             (c) Copyright 2016 
#          David Krause, Tobias Freitag
#
#    See the file "copying.txt", included in this
#    distribution, for details about the copyright.
#


import logging
import ch4tdef 
import strutils
import config


proc removeDoubleWhite * (s: string): string {.exportc.} =
  # replaces double whitespaces from string with ONE
  result = s
  while result.contains("  "):
    result = result.replace("  ", " ")


proc validMode * (modestr: string): bool =
  if modestr.len == 1:
    return true
  else:
    return false

proc validRoomName * (s: string): bool =
  result = (s != "" and (s.startsWith("#") or s.startsWith("&")) and s.len < MAX_ROOMNAME_LEN and not s.contains(" ") and not s.contains(",") and not s.contains('\x07'))
  debug("ROOMNAME [$1] valid [$2]" % [s,$result])

proc validUserName * (s: string): bool =
  result = true
  # TODO check for ASCII
  # TODO white listening instead of blacklisting!!
  if s.len == 0 or s.len > MAX_USERNAME_LEN:
    error("username to long: ", s)
    result = false
  if s[0] in "1234567890+-" and result:
    error("username has invalid chars[1]: ", s)
    result = false
  if ";" in s or "," in s or ":" in s and result:
    error("username has invalid chars[2]: ", s)
    result = false
  debug("USERNAME [$1] valid [$2]" % [s, $result])

proc parseIncoming * (rawline: string): IrcLineIn =
  # this parses the client to server line,
  # example:
  # PRIVMSG #kl :hallo
  # PING :12345
  debug("INCOMING: " & rawline)
  var line: string = rawline
  var headerPart: string
  var lineParts : seq[string]
  result = IrcLineIn() # initialize the result
  line = line.strip() # TODO should we do this?
  if line == "":
    result.command=TError
    debug("Could not parse line: line empty")
    return 
  if line.startswith(":"):
    # this is a server to server OR
    # server to client 
    # communication, someone told us who has written the msg.
    # line = line[1..^1] # remove leading ':'
    line = line.strip(leading=true,trailing=false,{':'})
    var who: string
    try:
      who = line.split(" ")[0]
    except:
      who = ""
    if who.validUserName() or who.validRoomName():
      result.who = who
      line = line[result.who.len+1..^1] # consume the word + trailing whitespace
    else: 
      result.command = TError
      debug("Could not parse line: No valid room/username in `who` ")
      return 
  else:
    # nobody told us who has written the msg.
    # but server has send it to us
    # this is [client -> server]
    result.who = ""
  if line.contains(" :"): # Read trailer
    result.trailer = line.split(" :", 1)[1]
    headerPart = line.split(" :", 1)[0]
  else:
    result.trailer = ""
    headerPart = line
  lineParts = headerPart.removeDoubleWhite().strip().split(" ")
  result.command = lineParts[0].parseEnum(TError)
  result.params = lineParts[1..^1]
  result.raw = rawline

proc forgeAnswer * (ircLine: IrcLineOut): string =
  ## This generates an irc line
  result = ""
  if ircLine.prefix != "":
    result.add(":" & ircLine.prefix & " ")
  result.add "$2 $3" % [ircLine.prefix, $ircLine.command, join(ircLine.params, " ").removeDoubleWhite().strip()]
  result = result.strip()
  if ircLine.trailer != "":
    result.add(" :")
    result.add(ircLine.trailer)
  result.add("\n")
  debug("FORGED (ANSWER): " & result.strip() )

proc `$` * ( ircLine: IrcLineOut): string = 
  return forgeAnswer(ircLine)


proc parsingSelftest * () =
  ## Test the parsing functions
  assert validRoomName("#validRoom") == true
  assert validRoomName("&validRoom") == true
  assert validRoomName("missingprefix") == false
  assert validRoomName('a'.repeat(299)) == false
  assert validRoomName("#inval,id") == false
  assert validRoomName("inval,id") == false
  assert validRoomName("inval id") == false
  assert validRoomName("inval" & '\x07' & "id") == false
  assert validRoomName("") == false

  # a-z A-Z 0-9 _ - \ [ ] { } ^ ` |
  #(with 0-9 only allowed second on  
  assert validUserName("sn0re") == true
  assert validUserName( "a".repeat(MAX_USERNAME_LEN + 1)) == false # over 9 chars
  assert validUserName("petr:pan") == false
  assert validUserName("petr;pan") == false
  assert validUserName("0hallo") == false # number on first char
  assert validUserName("_sn[]r3_") == true
  assert validUserName("-sn[]r3_") == false # minus at first char
  assert validUserName("+sn[]r3_") == false # plus at first char (check that)
  assert validUserName("|JPETER-PC/jpeter") == true
  assert validUserName("[E]|JPETER-PC/jpeter") == true
  # assert validUserName("über") == false  # check unicode
  # assert validUserName("aße*r") == false # check unicode

  assert "a  a".removeDoubleWhite() == "a a"
  assert "  a  a".removeDoubleWhite() == " a a"
  assert "  ".removeDoubleWhite() == " "
  assert " ".removeDoubleWhite() == " "
  assert "  b  ".removeDoubleWhite() == " b "
  assert "   ".removeDoubleWhite() == " " # 3 to 1
  assert "".removeDoubleWhite() == ""
  assert " ".removeDoubleWhite() == " " # 1 to 1



  assert parseIncoming("PRIVMSG #klangfragment :moin") == 
    newIrcLineIn(TPrivmsg, @["#klangfragment"], "moin", "PRIVMSG #klangfragment :moin","")

  assert parseIncoming("PRIVMSG #klangfragment :über stöckchen stießen") == 
    newIrcLineIn(TPrivmsg, @["#klangfragment"], "über stöckchen stießen", "PRIVMSG #klangfragment :über stöckchen stießen","")

  assert parseIncoming("PRIVMSG #klangfragment ::)") == 
    newIrcLineIn(TPrivmsg, @["#klangfragment"], ":)","PRIVMSG #klangfragment ::)","")

  assert parseIncoming("PRIVMSG peter ::)") == 
    newIrcLineIn(TPrivmsg, @["peter"], ":)","PRIVMSG peter ::)","")

  # assert parseIncoming("PRIVMSG aaasad","")

  assert parseIncoming("JOIN #lobby") == 
    newIrcLineIn(TJoin, @["#lobby"], "","JOIN #lobby","")

  assert parseIncoming("JOIN #lobby,#coden,#lol") == 
    newIrcLineIn(TJoin, @["#lobby,#coden,#lol"], "","JOIN #lobby,#coden,#lol","")
   
   # beides valide pings
  assert parseIncoming("PING 12345") == 
    newIrcLineIn(TPing, @["12345"],"","PING 12345","")

  echo parseIncoming("PING :ping ugga fugga")
  assert parseIncoming("PING :ping ugga fugga") == 
    newIrcLineIn(TPing, @[],"ping ugga fugga","PING :ping ugga fugga","")

  assert parseIncoming("PING  :ping ugga fugga") == 
    newIrcLineIn(TPing, @[],"ping ugga fugga","PING  :ping ugga fugga","")
  
  # echo parseIncoming(":enthus1ast PRIVMSG #lobby :Hallo lobby!")
  
  #### Server answers:
  # msg from a nick
  assert parseIncoming(":enthus1ast PRIVMSG #lobby :Hallo lobby!") == 
   newIrcLineIn(TPrivmsg, @["#lobby"],"Hallo lobby!",":enthus1ast PRIVMSG #lobby :Hallo lobby!","enthus1ast")

  # msg from a room
  assert parseIncoming(":#lobby PRIVMSG #lobby :Hallo lobby!") == 
   newIrcLineIn(TPrivmsg, @["#lobby"],"Hallo lobby!",":#lobby PRIVMSG #lobby :Hallo lobby!","#lobby")

  # Command: USER
  #   Parameters: <username> <hostname> <servername> <realname>
  # USER guest tolmoon tolsun :Ronnie Reagan
  assert parseIncoming("USER guest") == 
    newIrcLineIn(TUser, @["guest"],"","USER guest","")

  assert parseIncoming("user guest") == 
    newIrcLineIn(TUser, @["guest"],"","user guest","")

  assert parseIncoming("user guest :Peter Pan") == 
    newIrcLineIn(TUser, @["guest"],"Peter Pan","user guest :Peter Pan","")

  assert parseIncoming("USER guest tolmoon") == 
    newIrcLineIn(TUser, @["guest", "tolmoon"],"","USER guest tolmoon","")

  assert parseIncoming("USER guest tolmoon tolsun") == 
    newIrcLineIn(TUser, @["guest", "tolmoon", "tolsun"],"","USER guest tolmoon tolsun","")

  assert parseIncoming("USER guest tolmoon tolsun :Ronnie Reagan") == 
    newIrcLineIn(TUser, @["guest", "tolmoon", "tolsun"],"Ronnie Reagan","USER guest tolmoon tolsun :Ronnie Reagan","")

  assert parseIncoming("user guest tolmoon tolsun :Ronnie Reagan") == 
    newIrcLineIn(TUser, @["guest", "tolmoon", "tolsun"],"Ronnie Reagan","user guest tolmoon tolsun :Ronnie Reagan","")

  assert parseIncoming("NICK foofoo") == 
    newIrcLineIn(TNick, @["foofoo"],"","NICK foofoo","")

  assert parseIncoming("nick foofoo") == 
    newIrcLineIn(TNick, @["foofoo"],"","nick foofoo","")

  assert parseIncoming("NAMES #kl") == 
    newIrcLineIn(TNames, @["#kl"],"","NAMES #kl","")

  assert parseIncoming("NAMES bernhard") == 
    newIrcLineIn(TNames, @["bernhard"],"","NAMES bernhard","")

  # is das so super? 
  assert parseIncoming("NAMES #kl,#lobby") == 
    newIrcLineIn(TNames, @["#kl,#lobby"],"","NAMES #kl,#lobby","")

  # echo parseIncoming("NAMES #kl, #lobby")
  # assert parseIncoming("NAMES #kl, #lobby") == newIrcLineIn(Terror, @[],"") # parameter mit komma und lerzeilen sind verfickt,g("NAMES #kl, #lobby"?
  # parameter mit komma und lerzeilen sind verfickt?
  assert parseIncoming("NAMES #kl, #lobby") == 
    newIrcLineIn(TNames, @["#kl,","#lobby"],"","NAMES #kl, #lobby","")

  assert parseIncoming("ping 20:23:48") == 
    newIrcLineIn(TPing, @["20:23:48"],"","ping 20:23:48","")
    

  # in quakenet ist das ein error
  # assert parseIncoming("NAMES #kl #lobby") == (TNames, @["#kl","#lobby"],"") # is das so super? 

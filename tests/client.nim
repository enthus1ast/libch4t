import irc, asyncdispatch, strutils

proc onIrcEvent(client: AsyncIrc, event: IrcEvent) {.async.} =
  case event.typ
  of EvConnected:
    discard
  of EvDisconnected, EvTimeout:
    await client.reconnect()
  of EvMsg:
    if event.cmd == MPrivMsg:
      var msg = event.params[event.params.high]
      if msg == "!test": await client.privmsg(event.origin, "hello")
      if msg == "!lag":
        await client.privmsg(event.origin, formatFloat(client.getLag))
      if msg == "!excessFlood":
        for i in 0..10:
          await client.privmsg(event.origin, "TEST" & $i)
      if msg == "!users":
        await client.privmsg(event.origin, "Users: " &
            client.getUserList(event.origin).join("A-A"))
    echo(event.raw)

var client = newAsyncIrc("hobana.freenode.net", nick="TestBot1234",
# var client = newAsyncIrc("127.0.0.1", nick="TestBot1234", user="TestBotUSR",
                 joinChans = @["#testaaaaaaa"], callback = onIrcEvent)
asyncCheck client.run()

runForever()
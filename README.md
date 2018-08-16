# libch4t
IRC server in nim


# Get your IRC server:

edit:
    
    config.nim

compile:
  
    nim c -d:release libch4t_irc.nim

run:
  
    libch4t_irc
    
to get a simple irc server in nim

# features
- SSL (preview)
- user/nick 'login'
- PASS (connection password)
- NICK change nick
- JOIN
- PART
- WHO
- NAMES
- PRIVMSG
- PING / PONG
- AWAY
- DUMP # sends some debug info to caller
- DEBUG # echo debug info
- MOTD
- LUSERS
- LIST  # room topics are not yet implemented due the lack of modes

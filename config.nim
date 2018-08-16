import sets

const
  SERVER_NAME* = "ch4t.code0.xyz"
  SERVER_URL* = "http://" & SERVER_NAME
  LOGFILE* = "ch4t.log"
  MAX_USERNAME_LEN* = 200
  MAX_ROOMNAME_LEN* = 200

  SERVER_PASSWORD_ENABLED* = true
  SERVER_PASSWORD* = "passw0rd"
  
  IRC_PORT * = 6667
  IRC_IFACE * = "0.0.0.0"

  SSL_ENABLED * = false
  SSL_CERT_FILE* = "keys/mycert.pem"

  PING_MSG * = "t"


  # This binds the tcp socket to a websocket.
  # So just speak IRC to the websocket to 
  # Connect to libch4t.
  # TODO import the upstream wsToTcp proxy somehow
  WEBSOCKET * = false # compile websocket support
  WEBSOCKET_PORT * = 7787

  # every created rooms gets an default mode.
  # DEFAULT_ROOM_MODES * : HashSet[] = toSet(["i"])

  MOTD * = """ 
      
                                                                                
                   hhhhhhh                    444444444           tttt          
       lib         h:::::h                   4::::::::4        ttt:::t          
                   h:::::h                  4:::::::::4        t:::::t          
                   h:::::h                 4::::44::::4        t:::::t          
    cccccccccccccccch::::h hhhhh          4::::4 4::::4  ttttttt:::::ttttttt    
  cc:::::::::::::::ch::::hh:::::hhh      4::::4  4::::4  t:::::::::::::::::t    
 c:::::::::::::::::ch::::::::::::::hh   4::::4   4::::4  t:::::::::::::::::t    
c:::::::cccccc:::::ch:::::::hhh::::::h 4::::444444::::444tttttt:::::::tttttt    
c::::::c     ccccccch::::::h   h::::::h4::::::::::::::::4      t:::::t          
c:::::c             h:::::h     h:::::h4444444444:::::444      t:::::t          
c:::::c             h:::::h     h:::::h          4::::4        t:::::t          
c::::::c     ccccccch:::::h     h:::::h          4::::4        t:::::t    tttttt
c:::::::cccccc:::::ch:::::h     h:::::h          4::::4        t::::::tttt:::::t
 c:::::::::::::::::ch:::::h     h:::::h        44::::::44      tt::::::::::::::t
  cc:::::::::::::::ch:::::h     h:::::h        4::::::::4        tt:::::::::::tt
    cccccccccccccccchhhhhhh     hhhhhhh        4444444444          ttttttttttt  
                                                                                

                        Ich bin der Geist der stets verneint! /
                         Und das mit Recht; denn alles was entsteht /
                         Ist werth daß es zu Grunde geht; /
                         Drum besser wär’s daß nichts entstünde. /
                         So ist denn alles was ihr Sünde, /
                          Zerstörung, kurz das Böse nennt, /
                          Mein eigentliches Element. — Mephistopheles; 

                                Zitat aus: Johann Wolfgang von Goethe – Faust. Eine Tragödie.
                        

            ""libch4t is an experimental chat library that
            tries to provide access to one chat realm from different protocols.""

        What it should be when it's finished:

          An multi protocol chat server library, that lets
          you and your friends chat with each other.
          They can use whatever protocol/application
          they like to connect to this chat realm.

          [+] irc
          [ ] jabber
          [ ] http (long polling)
          [ ] http (rest api)
          [+] websocket (irc transport)
          [ ] email
          [ ] shared library api call
          [ ] psyc http://about.psyc.eu/ | 


        What it is at the moment:

          [+] mediocre irc server (in pure nim)
          [+] websocket to tcp transport `wsToTcp`
          [+] http page with websocket transport to irc
            -> Chat over IRC and over HTTP/WEBSOCKET.
          [/] stable api, atm its just a toy.

        """
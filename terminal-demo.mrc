; ============================================================================
;  terminal-demo.mrc - a tiny ANSI telnet server for testing (and fun)
;
;  Run it with a second mslrt:   mslrt terminal-demo.mrc
;  Then in the MSL OS Terminal:  telnet 127.0.0.1 2323
;
;  It speaks just enough telnet (IAC WILL ECHO / SGA) and ANSI colour to
;  exercise the MSL OS terminal emulator end to end.
; ============================================================================

alias -l ans { return $+($chr(27),[,$1,m) }

on *:START:{
  if (!$sock(mosdemo)) { socklisten mosdemo 2323 }
  echo -s terminal-demo: listening on 127.0.0.1:2323
  echo -s terminal-demo: connect from MSL OS with: telnet 127.0.0.1 2323
}

on *:SOCKLISTEN:mosdemo:{
  if ($sock(democonn)) { sockclose democonn }
  sockaccept democonn
  ; offer to echo (client stops local echo) and suppress go-ahead
  sockwrite -a democonn $+($chr(255),$chr(251),$chr(1))
  sockwrite -a democonn $+($chr(255),$chr(251),$chr(3))
  sockwrite -a democonn $+($chr(27),[2J)
  var %art1 = $+($ans(1;36),$chr(32),__  __ ,$chr(32),___ ,$chr(32),___ ,$chr(32),___ ,$chr(32),___ ,$chr(32),$chr(32),___ ,$ans(0))
  var %art2 = $+($ans(1;36), MSL OS - demo telnet server ,$ans(0))
  sockwrite -n democonn %art1
  sockwrite -n democonn %art2
  sockwrite -a democonn $crlf
  sockwrite -an democonn $ans(1;33) $+ MSL OS demo telnet server $ans(0) $+ . Type $ans(32) $+ help $ans(0) $+ for commands, $ans(32) $+ quit $ans(0) $+ to hang up.
  sockwrite -a democonn $crlf
}

on *:SOCKREAD:democonn:{
  if ($sockerr > 0) { return }
  sockread -f %demoline
  if ($sockbr == 0) { return }
  ; ignore the client's IAC negotiation replies (lines starting with 0xFF)
  if ($asc($mid(%demoline,1,1)) == 255) { return }
  var %c = $gettok(%demoline,1,32)
  if (%c == $null) {
    sockwrite -a democonn $chr(13) $+ $chr(10)
    return
  }
  if (%c == quit) || (%c == exit) {
    sockwrite -an democonn bye!
    sockclose democonn
    return
  }
  if (%c == help) {
    sockwrite -an democonn commands: help, clear, colours, banner, joke, quit
    return
  }
  if (%c == clear) {
    sockwrite -a democonn $+($chr(27),[2J)
    sockwrite -an democonn screen cleared.
    return
  }
  if (%c == colours) {
    var %i = 30
    while (%i <= 37) {
      sockwrite -an democonn $ans(1; $+ %i) $+ this is colour code $upper($str(x,2)) $+ %i $ans(0)
      inc %i
    }
    sockwrite -an democonn $ans(1;90) $+ ...and the bright ones (90-97) $ans(0)
    return
  }
  if (%c == banner) {
    sockwrite -a democonn $+($chr(27),[2J)
    sockwrite -an democonn $ans(1;35) $+ one more time, with feeling $ans(0)
    return
  }
  if (%c == joke) {
    sockwrite -an democonn $ans(33) $+ An IRC script walks into a bar. The bar says: sorry, we do not serve your kind here. The script replies: that is fine, I will /part. $ans(0)
    return
  }
  sockwrite -an democonn $ans(36) $+ you said: $ans(0) $+ %demoline
}

on *:SOCKCLOSE:democonn:{
  echo -s terminal-demo: client disconnected
}

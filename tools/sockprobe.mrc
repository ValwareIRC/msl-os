; ============================================================================
;  sockprobe.mrc - isolated SOCKREAD / &binvar probe, no MSL OS involved.
;  One process plays both server (port 2324) and client, and logs everything
;  its SOCKREAD handler sees to the status window. Self-exits after 7s.
; ============================================================================
alias -l plog { echo -s PROBE $1- }

on *:START: {
  hmake -s probe 10
  plog bvar-missing-test= [ $bvar(&p.acc,0) ]
  socklisten probe_srv 2324
  .timerprobe1 1 1 probe.connect
  .timerprobe2 1 6 probe.report
  .timerprobe3 1 7 exit
}

alias probe.connect {
  plog connecting
  sockopen probe_cli 127.0.0.1 2324
}

on *:SOCKLISTEN:probe_srv: {
  sockaccept probe_acc
  ; exactly the byte pattern the demo server sends: IAC WILL ECHO / WILL SGA,
  ; ESC[2J, two coloured lines with CRLF, one blank line
  sockwrite -a probe_acc $+($chr(255),$chr(251),$chr(1))
  sockwrite -a probe_acc $+($chr(255),$chr(251),$chr(3))
  sockwrite -a probe_acc $+($chr(27),[2J)
  sockwrite -an probe_acc $+($chr(27),[1;36m,hello bold cyan line,$chr(27),[0m)
  sockwrite -an probe_acc $+($chr(27),[33myellow plain line,$chr(27),[0m)
  sockwrite -a probe_acc $crlf
  plog server sent banner
}

on *:SOCKOPEN:probe_cli: {
  if ($sockerr > 0) { plog open-err $sockerr | return }
  plog opened
}

on *:SOCKREAD:probe_cli: {
  if ($sockerr > 0) { plog read-ev-sockerr= $sockerr | return }
  hinc probe fires
  plog read-ev fire= $hget(probe,fires) rq= $sock(probe_cli).rq rcvd= $sock(probe_cli).rcvd
  var %got = 1
  while (%got) {
    sockread -f &p.r
    plog loop br= $sockbr rlen= $bvar(&p.r,0) rq= $sock(probe_cli).rq
    if ($sockbr == 0) { %got = 0 }
    else {
      var %base = $calc( $bvar(&p.acc,0) + 1)
      bcopy &p.acc %base &p.r 1 $sockbr
    }
  }
  plog acc= $bvar(&p.acc,0)
}

alias probe.report {
  plog REPORT acc= $bvar(&p.acc,0) rcvd= $sock(probe_cli).rcvd rq= $sock(probe_cli).rq
  var %i = 1
  var %out
  while (%i <= $bvar(&p.acc,0)) && (%i <= 48) {
    %out = %out $bvar(&p.acc,%i)
    inc %i
  }
  plog BYTES %out
}

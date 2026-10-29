; ============================================================================
;  MSL OS 1.0 - a desktop operating system written in mIRC script (mSL)
;  for the standalone msl-runtime (https://github.com/ValwareIRC/msl-runtime)
;
;  Run:      mslrt msl-os.mrc
;  Or type:  /mo         (boots, or focuses the desktop)
;            /mo.quit    (shuts down and saves)
;
;  Everything is drawn in one picture window (@MSLOS) with a tiny window
;  manager: draggable app windows, a taskbar, a start menu, desktop icons
;  and context menus. Dialogs (Notepad, file picker, Settings, Run) are real
;  mSL dialogs. The Terminal is a picture window with an editbox that speaks
;  telnet / raw TCP / TLS and renders ANSI colour.
;
;  Hash tables:  mcfg (settings+state, saved)   mfs (virtual filesystem, saved)
;                mwm (window manager)           mreg (click regions)
;                mst (per-window app state)     mt  (terminal)
;
;  mslrt notes baked into this script:
;   - identifier-style aliases are undotted (mo_x); only words that start
;     with % or $ are evaluated, so $calc args keep vars word-initial:
;     "$calc(( %x - 1 ) / 2)" not "$calc((%x - 1) / 2)"
;   - $calc cannot parse "x % %var"; use $mo_mod(x,y)
; ============================================================================

; ---------------------------------------------------------------- boot ----

alias mo {
  if ($window(@MSLOS)) { window -a @MSLOS | return }
  mo.boot
}

alias mo.boot {
  mo.init
  var %dw = $window(-1).w
  var %dh = $window(-1).h
  if (%dw < 2) { %dw = 1280 }
  if (%dh < 2) { %dh = 800 }
  ; fill the screen: the native window adds a title bar, so leave room for it
  var %w = %dw - 16
  var %h = %dh - 60
  if (%w < 680) { %w = 680 }
  if (%h < 480) { %h = 480 }
  window -pk0 @MSLOS -1 -1 %w %h
  renwin @MSLOS @MSLOS MSL OS 1.0
  unset %mo.*
  hadd mcfg boot $ctime
  ; boot screen: logo, name, and a progress bar drawn by mo.boot.step
  var %bg = $mo_c(bg2)
  drawrect -rfn @MSLOS %bg 1 0 0 %w %h
  var %lx = $int( $calc( %w / 2 - 33))
  var %ly = $int( $calc( %h / 2 - 150))
  drawrect -rfdn @MSLOS $mo_c(accent2) 1 %lx %ly 30 30 8 8
  drawrect -rfdn @MSLOS $mo_c(accent2) 1 $calc( %lx + 36) %ly 30 30 8 8
  drawrect -rfdn @MSLOS $mo_c(accent) 1 %lx $calc( %ly + 36) 30 30 8 8
  drawrect -rfdn @MSLOS $mo_c(accent) 1 $calc( %lx + 36) $calc( %ly + 36) 30 30 8 8
  drawtext -rn @MSLOS $rgb(244,246,250) "Segoe UI Light" 30 $int( $calc( %w / 2 - $width(MSL OS,Segoe UI Light,30) / 2)) $calc( %h / 2 - 60) MSL OS
  var %sub = an operating system in a picture window
  drawtext -rn @MSLOS $mo_mix(%bg,$rgb(255,255,255),0.55) "Segoe UI" 10 $int( $calc( %w / 2 - $width(%sub,Segoe UI,10) / 2)) $calc( %h / 2 - 8) %sub
  hadd mcfg bootp 0
  .timermo.boot -m 0 90 mo.boot.step
}

alias mo.boot.step {
  if ($window(@MSLOS) == $null) { .timermo.boot off | return }
  var %p = $hget(mcfg,bootp) + 1
  hadd mcfg bootp %p
  var %w = $window(@MSLOS).bw
  var %h = $window(@MSLOS).bh
  var %bw = 240
  var %bx = $int( $calc(( %w - %bw ) / 2))
  var %by = $calc( %h / 2 + 44)
  if (%p > 22) {
    .timermo.boot off
    hadd mcfg bootp 0
    mo.desktop.start
    return
  }
  ; build the wallpaper and icons while the bar is showing
  if (%p == 12) { mo.wall.build | mo.ico.cache }
  var %labels = Starting MSL OS|Checking virtual filesystem|Loading settings|Starting window manager|Preparing desktop|Welcome
  var %t = %p - 1
  var %lbl = $gettok(%labels,$int( $calc( 1 + %t * 5 / 21)),124)
  var %bg = $mo_c(bg2)
  drawrect -rfdn @MSLOS $mo_mix(%bg,$rgb(255,255,255),0.12) 1 %bx %by %bw 4 3 3
  drawrect -rfdn @MSLOS $mo_c(accent2) 1 %bx %by $mo_max(4,$int( $calc( %bw * %p / 22))) 4 3 3
  if (%lbl) {
    drawrect -rfn @MSLOS %bg 1 0 $calc( %by + 14) %w 20
    var %l = %lbl $+ ...
    drawtext -rn @MSLOS $mo_mix(%bg,$rgb(255,255,255),0.5) "Segoe UI" 9 $int( $calc( %w / 2 - $width(%l,Segoe UI,9) / 2)) $calc( %by + 16) %l
  }
  drawdot @MSLOS
}

alias mo.desktop.start {
  mo.render
  .timermo.tick -m 0 500 mo.tick
  mo.wm.open welcome
}

; ------------------------------------------------------------ lifecycle ----

on *:START:mo.boot

on *:LOAD: {
  echo -s MSL OS loaded. Type /mo to boot it.
}

on *:UNLOAD: {
  .timermo.tick off
  .timermo.boot off
  if ($hget(mfs)) { mo.save }
}

on *:EXIT: {
  if ($hget(mfs)) { mo.save }
}

alias mo.save {
  if ($hget(mfs)) { hsave -o mfs mslos\fs.dat }
  if ($hget(mcfg)) { hsave -o mcfg mslos\cfg.dat }
}

alias mo.quit {
  if ($input(Shut down MSL OS?,y,,Shut down MSL OS) != $true) return
  .timermo.tick off
  .timermo.boot off
  .timermo.sdw off
  mo.save
  if ($sock(mosterm)) { sockclose mosterm }
  var %w = $window(@MSLOS).bw
  var %h = $window(@MSLOS).bh
  drawrect -rfn @MSLOS $rgb(8,10,14) 1 0 0 %w %h
  drawtext -orn @MSLOS $rgb(240,240,245) "Segoe UI" 20 $calc( %w / 2 - $width(It is now safe to close mslrt.,Segoe UI,20,b1) / 2) $calc( %h / 2 - 20) It is now safe to close mslrt.
  drawdot @MSLOS
  .timermo.sdw 1 1400 mo.quit.final
}

alias mo.quit.final {
  if ($dialog(mo_np)) { dialog -x mo_np }
  if ($dialog(mo_pick)) { dialog -x mo_pick }
  if ($dialog(mo_set)) { dialog -x mo_set }
  if ($dialog(mo_run)) { dialog -x mo_run }
  if ($window(@MSLTERM)) { window -c @MSLTERM }
  if ($window(@MSLWALL)) { window -c @MSLWALL }
  if ($window(@MSLOS)) { window -c @MSLOS }
  echo -s MSL OS: shut down. Files saved under mslos\.
}

; ---------------------------------------------------------------- init ----

alias mo.init {
  if (!$hget(mcfg)) { hmake mcfg 100 }
  if (!$hget(mfs)) { hmake mfs 200 }
  if (!$hget(mwm)) { hmake mwm 50 }
  if (!$hget(mreg)) { hmake mreg 200 }
  if (!$hget(mst)) { hmake mst 100 }
  if (!$hget(mt)) { hmake mt 60 }
  mkdir mslos
  if (!$hget(mcfg,theme)) { hadd mcfg theme teal }
  if ($findfile(mslos,fs.dat,1)) { hload mfs mslos\fs.dat }
  if ($findfile(mslos,cfg.dat,1)) { hload mcfg mslos\cfg.dat }
  mo.theme.init
  mo.fs.init
}

; -------------------------------------------------------------- themes ----

alias mo.theme.init {
  ; key=r.g.b pairs. bg1/bg2 wallpaper gradient, glow1/glow2 wallpaper glows,
  ; surface (window body), surface2 (title bars, toolbars), border, text, text2
  ; (secondary text), sel (selection), hover, tb/tbt/tbb (taskbar, its text, its
  ; hover and lines), accent/accent2
  mo.th teal bg1=16.94.112 bg2=7.24.38 glow1=45.212.191 glow2=59.130.246 accent=13.148.136 accent2=45.190.175 surface=252.252.253 surface2=243.245.247 border=221.225.230 text=26.32.40 text2=99.110.123 sel=208.239.234 hover=232.236.240 tb=17.24.31 tbt=236.241.245 tbb=47.58.70
  mo.th midnight bg1=46.38.110 bg2=9.9.28 glow1=168.85.247 glow2=59.130.246 accent=99.102.241 accent2=139.142.255 surface=252.252.255 surface2=243.243.249 border=224.224.237 text=24.24.42 text2=100.100.128 sel=224.226.255 hover=234.234.246 tb=16.16.32 tbt=236.236.252 tbb=48.48.82
  mo.th terracotta bg1=158.78.52 bg2=38.16.12 glow1=251.146.60 glow2=219.39.119 accent=211.92.56 accent2=240.135.95 surface=253.251.249 surface2=246.241.237 border=233.224.218 text=42.28.22 text2=122.104.95 sel=252.226.213 hover=242.235.230 tb=30.19.15 tbt=247.239.233 tbb=74.54.46
  mo.th moss bg1=58.104.62 bg2=12.26.16 glow1=163.230.53 glow2=20.184.166 accent=77.145.60 accent2=122.190.88 surface=251.252.249 surface2=241.245.239 border=221.228.216 text=24.34.22 text2=98.112.94 sel=222.241.211 hover=234.239.230 tb=17.26.17 tbt=236.243.233 tbb=50.64.48
  ; older names the apps still use
  var %i = 1
  while (%i <= 4) {
    var %t = $gettok(teal midnight terracotta moss,%i,32)
    hadd mcfg $+(th.,%t,.winbg) $hget(mcfg,$+(th.,%t,.surface))
    hadd mcfg $+(th.,%t,.wnb) $hget(mcfg,$+(th.,%t,.border))
    hadd mcfg $+(th.,%t,.menu) $hget(mcfg,$+(th.,%t,.surface2))
    hadd mcfg $+(th.,%t,.menub) $hget(mcfg,$+(th.,%t,.border))
    hadd mcfg $+(th.,%t,.menut) $hget(mcfg,$+(th.,%t,.text))
    hadd mcfg $+(th.,%t,.title) $hget(mcfg,$+(th.,%t,.accent))
    hadd mcfg $+(th.,%t,.title2) $hget(mcfg,$+(th.,%t,.text2))
    hadd mcfg $+(th.,%t,.titlet) 255 255 255
    inc %i
  }
}

alias mo.th {
  ; $1 = theme, $2- = key=r.g.b
  var %n = $numtok($2-,32)
  var %i = 1
  while (%i <= %n) {
    var %kv = $gettok($2-,%i,32)
    hadd mcfg $+(th.,$1,.,$gettok(%kv,1,61)) $replace($gettok(%kv,2,61),.,$chr(32))
    inc %i
  }
}

; mo_c(key) = current theme colour as an $rgb() value
alias mo_c {
  var %v = $hget(mcfg,$+(th.,$hget(mcfg,theme),.,$1))
  if (%v == $null) { return $rgb(128,128,128) }
  return $rgb($gettok(%v,1,32),$gettok(%v,2,32),$gettok(%v,3,32))
}

; colours are $rgb() values. $mo_mix(a,b,t) blends from a toward b (t = 0..1)
alias mo_mix {
  var %a = $rgb($1)
  var %b = $rgb($2)
  var %t = $3
  var %r = $int( $calc( $gettok(%a,1,44) + ( $gettok(%b,1,44) - $gettok(%a,1,44) ) * %t + 0.5))
  var %g = $int( $calc( $gettok(%a,2,44) + ( $gettok(%b,2,44) - $gettok(%a,2,44) ) * %t + 0.5))
  var %bl = $int( $calc( $gettok(%a,3,44) + ( $gettok(%b,3,44) - $gettok(%a,3,44) ) * %t + 0.5))
  return $rgb(%r,%g,%bl)
}

; Segoe Fluent Icons glyph: $1=colour $2=size $3=x $4=y $5=codepoint
alias mo.glyph {
  drawtext -rn @MSLOS $1 "Segoe Fluent Icons" $2 $3 $4 $chr($5)
}

; the same, centred in a box: $1=colour $2=size $3=x $4=y $5=w $6=h $7=codepoint
alias mo.glyphc {
  var %g = $chr($7)
  var %gx = $int( $calc( $3 + ( $5 - $width(%g,Segoe Fluent Icons,$2) ) / 2))
  var %gy = $int( $calc( $4 + ( $6 - $height(%g,Segoe Fluent Icons,$2) ) / 2))
  drawtext -rn @MSLOS $1 "Segoe Fluent Icons" $2 %gx %gy %g
}

; text centred vertically in a row: $1=colour $2=font (no spaces: ui|semi|light) $3=size $4=x $5=y $6=h $7-=text
alias mo.text {
  var %f = Segoe UI
  if ($2 == semi) { %f = Segoe UI Semibold }
  if ($2 == light) { %f = Segoe UI Light }
  var %ty = $int( $calc( $5 + ( $6 - $height($7-,%f,$3) ) / 2))
  drawtext -rn @MSLOS $1 $+(",%f,") $3 $4 %ty $7-
}

; layered soft shadow around x y w h. Each ring darkens what is already
; drawn there, sampled per segment, so it works over the wallpaper and over
; other windows alike. $1=x $2=y $3=w $4=h
alias mo.shadow {
  var %x = $1
  var %y = $calc( $2 + 3)
  var %w = $3
  var %h = $4
  var %bw = $window(@MSLOS).bw
  var %bh = $window(@MSLOS).bh
  var %alphas = 0.26 0.22 0.18 0.15 0.12 0.09 0.07 0.05 0.035 0.022 0.012 0.005
  ; top and bottom edges, in 48px segments
  var %sx = $calc( %x - 12)
  while (%sx < $calc( %x + %w + 12)) {
    var %sw = $mo_min(48,$calc( %x + %w + 12 - %sx))
    var %e = 1
    while (%e <= 2) {
      var %ey = $iif(%e == 1,$calc( %y - 6),$calc( %y + %h + 6))
      var %under = $getdot(@MSLOS,$mo_max(0,$mo_min($calc( %sx + %sw / 2),$calc( %bw - 1))),$mo_max(0,$mo_min(%ey,$calc( %bh - 1))))
      if (%under != $null) {
        var %k = 1
        while (%k <= 12) {
          var %ly = $iif(%e == 1,$calc( %y - %k),$calc( %y + %h + %k - 1))
          var %lx1 = $mo_max(%sx,$calc( %x - %k))
          var %lx2 = $mo_min($calc( %sx + %sw - 1),$calc( %x + %w + %k - 1))
          if (%lx2 >= %lx1) { drawline -rn @MSLOS $mo_mix(%under,0,$gettok(%alphas,%k,32)) 1 %lx1 %ly %lx2 %ly }
          inc %k
        }
      }
      inc %e
    }
    inc %sx 48
  }
  ; left and right edges, in 24px segments
  var %sy = %y
  while (%sy < $calc( %y + %h)) {
    var %sh = $mo_min(24,$calc( %y + %h - %sy))
    var %e = 1
    while (%e <= 2) {
      var %ex = $iif(%e == 1,$calc( %x - 6),$calc( %x + %w + 6))
      var %under = $getdot(@MSLOS,$mo_max(0,$mo_min(%ex,$calc( %bw - 1))),$mo_max(0,$mo_min($calc( %sy + %sh / 2),$calc( %bh - 1))))
      if (%under != $null) {
        var %k = 1
        while (%k <= 12) {
          var %lx = $iif(%e == 1,$calc( %x - %k),$calc( %x + %w + %k - 1))
          drawline -rn @MSLOS $mo_mix(%under,0,$gettok(%alphas,%k,32)) 1 %lx %sy %lx $calc( %sy + %sh - 1)
          inc %k
        }
      }
      inc %e
    }
    inc %sy 24
  }
}

; rounds the corners of a drawn box: paints the pixels outside an 8px arc
; with the colours sampled at each corner before the box was drawn, then the
; arc itself in the border colour.
; $1=x $2=y $3=w $4=h $5=border $6-9=colours under the tl tr bl br corners
alias mo.corners {
  var %spans = 5 3 2 1 1
  var %i = 1
  while (%i <= 5) {
    var %s = $gettok(%spans,%i,32)
    var %ty = $calc( $2 + %i - 1)
    var %by = $calc( $2 + $4 - %i)
    var %rx = $calc( $1 + $3 - 1)
    drawline -rn @MSLOS $6 1 $1 %ty $calc( $1 + %s - 1) %ty
    drawline -rn @MSLOS $7 1 $calc( %rx - %s + 1) %ty %rx %ty
    drawline -rn @MSLOS $8 1 $1 %by $calc( $1 + %s - 1) %by
    drawline -rn @MSLOS $9 1 $calc( %rx - %s + 1) %by %rx %by
    drawdot -rn @MSLOS $5 1 $calc( $1 + %s) %ty
    drawdot -rn @MSLOS $5 1 $calc( %rx - %s) %ty
    drawdot -rn @MSLOS $5 1 $calc( $1 + %s) %by
    drawdot -rn @MSLOS $5 1 $calc( %rx - %s) %by
    inc %i
  }
}

; colour under a point of @MSLOS (for mo.corners)
alias mo_under {
  var %v = $getdot(@MSLOS,$mo_max(0,$mo_min($1,$calc( $window(@MSLOS).bw - 1))),$mo_max(0,$mo_min($2,$calc( $window(@MSLOS).bh - 1))))
  return $iif(%v == $null,0,%v)
}

; -------------------------------------------------------------- helpers ----

alias mo_min {
  if ($1 < $2) { return $1 }
  return $2
}

; modulo: $calc cannot parse "x % %var" in mslrt, so do it by subtraction
alias mo_mod {
  var %v = $1
  while (%v >= $2) { dec %v $2 }
  if (%v < 0) { %v = 0 }
  return %v
}

alias mo_max {
  if ($1 > $2) { return $1 }
  return $2
}

; clip text to a pixel width, appending ".."
alias mo_clip {
  var %t = $1
  if ($width(%t,Segoe UI,$4) <= $2) { return %t }
  while ($width(%t $+ ..,Segoe UI,$4) > $2) {
    %t = $left(%t,$calc( $len(%t) - 1))
    if ($len(%t) <= 1) { break }
  }
  return %t $+ ..
}

; draw text preserving leading/multiple spaces: walks the string and draws
; words, advancing x by the width of each space run. returns new x.
alias mo_spaced {
  ; $1=@win $2=x $3=y $4=color $5=font $6=size $7=text
  var %t = $7-
  var %i = 1
  var %n = $len(%t)
  var %x = $2
  var %buf = $null
  var %sp = 0
  while (%i <= %n) {
    var %ch = $mid(%t,%i,1)
    if (%ch == $chr(32)) {
      if (%buf != $null) {
        drawtext -rn $1 $4 $5-6 %x $3 %buf
        inc %x $width(%buf,$5,$6)
        %buf = $null
      }
      inc %sp
    }
    else {
      if (%sp) {
        inc %x $width($str($chr(32),%sp),$5,$6)
        %sp = 0
      }
      %buf = %buf $+ %ch
    }
    inc %i
  }
  if (%buf != $null) {
    drawtext -rn $1 $4 $5-6 %x $3 %buf
    inc %x $width(%buf,$5,$6)
  }
  return %x
}

; ------------------------------------------------------------ wallpaper ----

alias mo.wall {
  ; the wallpaper is cached in the hidden window @MSLWALL
  mo.wall.build
  drawcopy -n @MSLWALL 0 0 $window(@MSLOS).bw $window(@MSLOS).bh @MSLOS 0 0
}

alias mo.wall.build {
  var %w = $window(@MSLOS).bw
  var %h = $window(@MSLOS).bh
  if (%w < 2) { %w = $window(@MSLOS).w }
  if (%h < 2) { %h = $window(@MSLOS).h }
  if ($window(@MSLWALL) == $null) {
    window -hp @MSLWALL 0 0 %w %h
    hdel mcfg wallw
    hdel mcfg wallh
  }
  if ($hget(mcfg,wallw) != %w) || ($hget(mcfg,wallh) != %h) || ($hget(mcfg,wallth) != $hget(mcfg,theme)) || ($hget(mcfg,wallv) != 3) {
    drawsize @MSLWALL %w %h
    hadd mcfg wallw %w
    hadd mcfg wallh %h
    hadd mcfg wallth $hget(mcfg,theme)
    hadd mcfg wallv 3
    mo.wall.paint %w %h
  }
}

; the wallpaper is computed pixel by pixel at 1/8 size (a vertical gradient
; plus two soft radial glows) and scaled up with smoothing, which leaves no
; banding. $1=w $2=h
alias mo.wall.paint {
  var %sw = $calc( $int( $calc( $1 / 8)) + 2)
  var %sh = $calc( $int( $calc( $2 / 8)) + 2)
  if (!$window(@MSLWS)) { window -hp @MSLWS 0 0 %sw %sh }
  drawsize @MSLWS %sw %sh
  tokenize 32 $mo_c(bg1) $mo_c(bg2) $mo_c(glow1) $mo_c(glow2)
  var %a = $rgb($1)
  var %b = $rgb($2)
  var %g1 = $rgb($3)
  var %g2 = $rgb($4)
  var %ar = $gettok(%a,1,44)
  var %ag = $gettok(%a,2,44)
  var %ab = $gettok(%a,3,44)
  var %br = $gettok(%b,1,44)
  var %bg = $gettok(%b,2,44)
  var %bb = $gettok(%b,3,44)
  var %g1r = $gettok(%g1,1,44)
  var %g1g = $gettok(%g1,2,44)
  var %g1b = $gettok(%g1,3,44)
  var %g2r = $gettok(%g2,1,44)
  var %g2g = $gettok(%g2,2,44)
  var %g2b = $gettok(%g2,3,44)
  ; glow centres and radii in small-buffer pixels
  var %c1x = $calc( %sw * 0.16)
  var %c1y = $calc( %sh * 0.16)
  var %r1 = $calc( %sh * 1.00)
  var %c2x = $calc( %sw * 0.90)
  var %c2y = $calc( %sh * 0.92)
  var %r2 = $calc( %sh * 0.95)
  var %y = 0
  while (%y < %sh) {
    var %t = $calc( %y / ( %sh - 1 ))
    var %rr = $calc( %ar + ( %br - %ar ) * %t)
    var %rg = $calc( %ag + ( %bg - %ag ) * %t)
    var %rb = $calc( %ab + ( %bb - %ab ) * %t)
    var %dy1 = $calc( ( %y - %c1y ) * ( %y - %c1y ))
    var %dy2 = $calc( ( %y - %c2y ) * ( %y - %c2y ))
    var %x = 0
    while (%x < %sw) {
      var %r = %rr
      var %g = %rg
      var %bl = %rb
      var %d = $calc( ( ( %x - %c1x ) * ( %x - %c1x ) + %dy1 ) / ( %r1 * %r1 ))
      if (%d < 1) {
        var %k = $calc( 0.55 * ( 1 - %d ) * ( 1 - %d ))
        %r = $calc( %r + ( %g1r - %r ) * %k)
        %g = $calc( %g + ( %g1g - %g ) * %k)
        %bl = $calc( %bl + ( %g1b - %bl ) * %k)
      }
      %d = $calc( ( ( %x - %c2x ) * ( %x - %c2x ) + %dy2 ) / ( %r2 * %r2 ))
      if (%d < 1) {
        var %k = $calc( 0.45 * ( 1 - %d ) * ( 1 - %d ))
        %r = $calc( %r + ( %g2r - %r ) * %k)
        %g = $calc( %g + ( %g2g - %g ) * %k)
        %bl = $calc( %bl + ( %g2b - %bl ) * %k)
      }
      drawdot -rn @MSLWS $rgb($int(%r),$int(%g),$int(%bl)) 1 %x %y
      inc %x
    }
    inc %y
  }
  drawcopy -mn @MSLWS 0 0 %sw %sh @MSLWALL -4 -4 $calc( %sw * 8) $calc( %sh * 8)
}


; -------------------------------------------------------------- regions ----
; every render records clickable rectangles. an entry is:
;   x y w h <c|d> <action...>      c = click, d = double-click
; layers: d desktop, t taskbar, s start menu, m context menu, w<id> windows

alias mo.hit.reset {
  hadd mreg $+(h,$1) 0
}

alias mo.hit {
  ; $1=layer $2=x $3=y $4=w $5=h $6=mode $7-=action
  var %n = $hget(mreg,$+(h,$1))
  if (%n == $null) { %n = 0 }
  inc %n
  hadd mreg $+(h,$1) %n
  hadd mreg $+(h,$1,.,%n) $2-
}

alias mo_hit_test {
  ; $1=layer $2=x $3=y $4=mode  -> action or $null
  ; tokenize below replaces $1-, so keep the arguments in variables first
  var %hl = $1
  var %hx = $2
  var %hy = $3
  var %hm = $4
  var %n = $hget(mreg,$+(h,%hl))
  var %i = 1
  if (%n == $null) { return $null }
  while (%i <= %n) {
    var %h = $hget(mreg,$+(h,%hl,.,%i))
    if (%h != $null) {
      tokenize 32 %h
      if ($inrect(%hx,%hy,$1,$2,$3,$4)) && ($5 == %hm) { return $6- }
    }
    inc %i
  }
  return $null
}

; ------------------------------------------------------------ window mgmt ----
; mwm items: n (counter), z (space-delimited window ids, top last),
; w<id>.app/.title/.x/.y/.w/.h/.st   st = norm | min | max

alias mo_tb_h { return 48 }

; height of a window's title bar
alias mo_cap_h { return 34 }

alias mo.wm.open {
  ; $1 = app id, $2- = args. returns window id.
  var %app = $1
  var %z = $hget(mwm,z)
  var %i = 1
  while (%i <= $numtok(%z,32)) {
    var %id = $gettok(%z,%i,32)
    if ($hget(mwm,$+(w,%id,.app)) == %app) {
      mo.wm.focus %id
      if ($hget(mwm,$+(w,%id,.st)) == min) { hadd mwm $+(w,%id,.st) norm }
      mo.render
      return %id
    }
    inc %i
  }
  var %id = $calc( $hget(mwm,n) + 1)
  hadd mwm n %id
  var %cnt = $calc( $numtok(%z,32) + 1)
  var %x = $calc( 220 + $mo_mod(%cnt,6) * 32)
  var %y = $calc( 36 + $mo_mod(%cnt,6) * 32)
  var %dw = $iif($window(@MSLOS).bw,$ifmatch,1024)
  var %dh = $iif($window(@MSLOS).bh,$ifmatch,700)
  var %aw = 520
  var %ah = 360
  var %title = Window
  if (%app == explorer) { %aw = 780 | %ah = 500 | %title = File Explorer }
  if (%app == browser) { %aw = 820 | %ah = 560 | %title = Web Browser }
  if (%app == paint) { %aw = 620 | %ah = 470 | %title = Paint }
  if (%app == viewer) { %aw = 420 | %ah = 380 | %title = Image Viewer }
  if (%app == welcome) { %aw = 500 | %ah = 360 | %x = $int( $calc(( %dw - 500 ) / 2)) | %y = $int( $calc(( %dh - $mo_tb_h - 360 ) / 2)) | %title = Welcome to MSL OS }
  %aw = $mo_min(%aw,$calc( %dw - 40))
  %ah = $mo_min(%ah,$calc( %dh - 90))
  if ($calc( %x + %aw) > $calc( %dw - 8)) { %x = $calc( %dw - %aw - 8) }
  if ($calc( %y + %ah) > $calc( %dh - 44)) { %y = $calc( %dh - %ah - 44) }
  hadd mwm $+(w,%id,.app) %app
  hadd mwm $+(w,%id,.title) %title
  hadd mwm $+(w,%id,.x) %x
  hadd mwm $+(w,%id,.y) %y
  hadd mwm $+(w,%id,.w) %aw
  hadd mwm $+(w,%id,.h) %ah
  hadd mwm $+(w,%id,.st) norm
  hadd mwm z %z %id
  var %c = mo.app. $+ %app $+ .open %id $2-
  %c
  mo.render
  return %id
}

alias mo.wm.focus {
  var %id = $1
  var %z = $hget(mwm,z)
  %z = $remtok(%z,%id,1,32)
  hadd mwm z %z %id
}

alias mo.wm.close {
  var %id = $1
  var %app = $hget(mwm,$+(w,%id,.app))
  var %c = mo.app. $+ %app $+ .close %id
  %c
  var %z = $remtok($hget(mwm,z),%id,1,32)
  hadd mwm z %z
  hdel -w mwm $+(w,%id,.*)
  hdel -w mst $+(x,%id,.*)
  mo.render
}

alias mo_wm_at {
  ; window id at x y (topmost first), or 0
  var %z = $hget(mwm,z)
  var %i = $numtok(%z,32)
  while (%i >= 1) {
    var %id = $gettok(%z,%i,32)
    if ($hget(mwm,$+(w,%id,.st)) != min) {
      if ($inrect($1,$2,$hget(mwm,$+(w,%id,.x)),$hget(mwm,$+(w,%id,.y)),$hget(mwm,$+(w,%id,.w)),$hget(mwm,$+(w,%id,.h)))) { return %id }
    }
    dec %i
  }
  return 0
}

alias mo_wm_focused {
  return $gettok($hget(mwm,z),-1,32)
}

alias mo.wm.taskclick {
  var %id = $1
  if ($hget(mwm,$+(w,%id,.st)) == min) {
    hadd mwm $+(w,%id,.st) norm
    mo.wm.focus %id
  }
  elseif ($mo_wm_focused == %id) {
    hadd mwm $+(w,%id,.st) min
  }
  else {
    mo.wm.focus %id
  }
  mo.render
}

alias mo.wm.btn {
  ; $1=id $2=min|max|close
  var %id = $1
  if ($2 == close) { mo.wm.close %id | return }
  if ($2 == min) { hadd mwm $+(w,%id,.st) min | mo.render | return }
  if ($2 == max) {
    if ($hget(mwm,$+(w,%id,.st)) == max) { hadd mwm $+(w,%id,.st) norm }
    else { hadd mwm $+(w,%id,.st) max }
    mo.wm.focus %id
    mo.render
  }
}

; ------------------------------------------------------------- rendering ----

alias mo.render {
  if ($window(@MSLOS) == $null) { return }
  mo.hit.reset d
  mo.hit.reset t
  var %w = $window(@MSLOS).bw
  var %h = $window(@MSLOS).bh
  if (%w < 2) { return }
  mo.wall
  ; desktop icons
  mo.desk.draw %w %h
  ; windows, bottom to top
  var %z = $hget(mwm,z)
  var %i = 1
  while (%i <= $numtok(%z,32)) {
    var %id = $gettok(%z,%i,32)
    if ($hget(mwm,$+(w,%id,.st)) != min) { mo.wm.drawframe %id }
    inc %i
  }
  mo.taskbar.draw %w %h
  if (%mostart) { mo.start.draw %w %h }
  if (%momenu != $null) { mo.menu.draw %w %h }
  drawdot @MSLOS
}

alias mo.wm.drawframe {
  var %id = $1
  var %x = $hget(mwm,$+(w,%id,.x))
  var %y = $hget(mwm,$+(w,%id,.y))
  var %w = $hget(mwm,$+(w,%id,.w))
  var %h = $hget(mwm,$+(w,%id,.h))
  var %app = $hget(mwm,$+(w,%id,.app))
  var %st = $hget(mwm,$+(w,%id,.st))
  var %cap = $mo_cap_h
  ; desktop size (variable names are case-insensitive, so not %W/%H)
  var %dw = $window(@MSLOS).bw
  var %dh = $calc( $window(@MSLOS).bh - $mo_tb_h)
  var %max = $iif(%st == max,1,0)
  if (%max) { %x = 0 | %y = 0 | %w = %dw | %h = %dh }
  else {
    if ($calc( %x + %w) > %dw) { %w = $mo_max(240,$calc( %dw - %x)) }
    if ($calc( %y + %h) > %dh) { %h = $mo_max(160,$calc( %dh - %y)) }
  }
  var %focus = $iif($mo_wm_focused == %id,1,0)
  mo.hit.reset $+(w,%id)
  if (!%max) {
    mo.shadow %x %y %w %h
    ; what lies under the corners, for rounding them afterwards
    var %u1 = $mo_mix($mo_under(%x,%y),0,0.10)
    var %u2 = $mo_mix($mo_under($calc( %x + %w - 1),%y),0,0.10)
    var %u3 = $mo_mix($mo_under(%x,$calc( %y + %h - 1)),0,0.24)
    var %u4 = $mo_mix($mo_under($calc( %x + %w - 1),$calc( %y + %h - 1)),0,0.24)
  }
  drawrect -rfn @MSLOS $mo_c(surface) 1 %x %y %w %h
  drawrect -rfn @MSLOS $mo_c(surface2) 1 %x %y %w %cap
  ; content
  var %c = mo.app. $+ %app $+ .draw %id %x $calc( %y + %cap) %w $calc( %h - %cap)
  %c
  ; caption: icon, title, buttons
  mo.icon16 %app $calc( %x + 12) $calc( %y + 9)
  mo.text $iif(%focus,$mo_c(text),$mo_c(text2)) ui 9 $calc( %x + 38) %y %cap $mo_clip($hget(mwm,$+(w,%id,.title)),$calc( %w - 190),9)
  var %bx = $calc( %x + %w - 138)
  mo.frame.btn %id %bx %y min
  mo.frame.btn %id $calc( %bx + 46) %y $iif(%max,restore,max)
  mo.frame.btn %id $calc( %bx + 92) %y close
  if (!%max) {
    var %bc = $mo_c(border)
    if (%focus) { %bc = $mo_mix(%bc,$mo_c(text),0.22) }
    drawrect -rn @MSLOS %bc 1 %x %y %w %h
    mo.corners %x %y %w %h %bc %u1 %u2 %u3 %u4
  }
}

; small 22x18 title-bar button with a glyph
; a 46px caption button: $1=winid $2=x $3=y $4=min|max|restore|close
alias mo.frame.btn {
  var %kind = $4
  var %act = mo.wm.btn $1 $iif(%kind == restore,max,%kind)
  var %cap = $mo_cap_h
  var %fg = $mo_c(text)
  if (%mohov == %act) {
    if (%kind == close) {
      drawrect -rfn @MSLOS $rgb(196,43,28) 1 $2 $3 46 %cap
      %fg = $rgb(255,255,255)
    }
    else { drawrect -rfn @MSLOS $mo_mix($mo_c(surface2),$mo_c(text),0.09) 1 $2 $3 46 %cap }
  }
  var %g = 59579
  if (%kind == min) { %g = 59681 }
  if (%kind == max) { %g = 59682 }
  if (%kind == restore) { %g = 59683 }
  mo.glyphc %fg 7 $2 $3 46 %cap %g
  mo.hit $+(w,$1) $2 $3 46 %cap c %act
}

; ---------------------------------------------------------- desktop icons ----
; system icons + files living in C:\Users\Guest\Desktop\
; selection is stored in %modsel (the item name)

alias mo_desk_entries {
  ; returns "name|label|icon|action" items separated by $lf
  var %out = mycomputer|My Computer|computer|mo.launch explorer C:\
  %out = %out $+ $lf $+ docs|My Documents|folder|mo.launch explorer C:\ $+ Users\ $+ Guest\ $+ Documents\
  %out = %out $+ $lf $+ browser|Web Browser|globe|mo.launch browser
  %out = %out $+ $lf $+ notepad|Notepad|page|mo.launch notepad
  %out = %out $+ $lf $+ paint|Paint|palette|mo.launch paint
  %out = %out $+ $lf $+ term|Terminal|termscreen|mo.launch term
  %out = %out $+ $lf $+ settings|Settings|gear|mo.launch settings
  %out = %out $+ $lf $+ trash|Recycle Bin|bin|mo.launch explorer C:\ $+ Recycled\
  %out = %out $+ $lf $+ about|About MSL OS|info|mo.launch welcome
  var %dir = C:\ $+ Users\ $+ Guest\ $+ Desktop\
  var %list = $mo_fs_list(%dir)
  var %i = 1
  while (%i <= $numtok(%list,124)) {
    var %n = $gettok(%list,%i,124)
    var %ic = file
    if ($mo_fs_isdir($+(%dir,%n))) { %ic = folder }
    elseif (*.bmp iswm %n) || (*.png iswm %n) { %ic = image }
    elseif (*.paint iswm %n) { %ic = palette }
    elseif (*.txt iswm %n) { %ic = page }
    var %act = $+(mo.fs.openfile,$chr(32),%dir,%n)
    if (%ic == folder) { %act = $+(mo.launch explorer,$chr(32),%dir,%n,\) }
    %out = %out $+ $lf $+ $+(fs.,%n) $+ $chr(124) $+ %n $+ $chr(124) $+ %ic $+ $chr(124) $+ %act
    inc %i
  }
  return %out
}

alias mo.desk.draw {
  ; icons fill columns top to bottom, like a real desktop
  var %w = $1
  var %h = $2
  var %rows = $int( $calc(( %h - $mo_tb_h - 16 ) / 100))
  if (%rows < 1) { %rows = 1 }
  var %e = $mo_desk_entries
  var %i = 1
  var %n = $numtok(%e,10)
  while (%i <= %n) {
    var %it = $gettok(%e,%i,10)
    var %name = $gettok(%it,1,124)
    var %label = $gettok(%it,2,124)
    var %icon = $gettok(%it,3,124)
    var %col = $int( $calc(( %i - 1 ) / %rows))
    var %row = $mo_mod($calc( %i - 1),%rows)
    var %x = $calc( 10 + %col * 92)
    var %y = $calc( 10 + %row * 100)
    if ($calc( %x + 90) > %w) { break }
    var %under = $mo_under($calc( %x + 44),$calc( %y + 46))
    if (%modsel == %name) {
      drawrect -rfdn @MSLOS $mo_mix(%under,$rgb(255,255,255),0.22) 1 %x %y 88 94 8 8
      drawrect -rdn @MSLOS $mo_mix(%under,$rgb(255,255,255),0.40) 1 %x %y 88 94 8 8
    }
    elseif (%mohov == mo.desk.select %name) {
      drawrect -rfdn @MSLOS $mo_mix(%under,$rgb(255,255,255),0.11) 1 %x %y 88 94 8 8
    }
    mo.icon %icon $calc( %x + 22) $calc( %y + 10) 44
    var %lbl = $mo_clip(%label,82,9)
    var %lx = $int( $calc( %x + 44 - $width(%lbl,Segoe UI,9) / 2))
    drawtext -rn @MSLOS $mo_mix(%under,0,0.55) "Segoe UI" 9 %lx $calc( %y + 63) %lbl
    drawtext -rn @MSLOS $rgb(255,255,255) "Segoe UI" 9 %lx $calc( %y + 62) %lbl
    mo.hit d %x %y 88 94 c mo.desk.select %name
    mo.hit d %x %y 88 94 d mo.desk.open %name
    inc %i
  }
}

alias mo.desk.select {
  %modsel = $1-
  mo.render
}

alias mo.desk.open {
  var %name = $1-
  var %e = $mo_desk_entries
  var %i = 1
  var %n = $numtok(%e,10)
  while (%i <= %n) {
    var %it = $gettok(%e,%i,10)
    if ($gettok(%it,1,124) == %name) {
      unset %modsel
      var %c = $gettok(%it,4-,124)
      %c
      return
    }
    inc %i
  }
}

; ------------------------------------------------------------ icon art ----
; each icon is 32x32, drawn with rects/lines/dots

; ------------------------------------------------------------ icons ----
; an icon is a rounded gradient tile with a white Segoe Fluent Icons glyph.
; Tiles are drawn once per theme into the hidden window @MSLICO and copied
; with magenta as the transparent colour; the glyph is drawn on top.

alias mo_ico_keys { return computer folder globe page note palette termscreen gear bin info image file run power }

; $1=key -> "top bottom" $rgb values
alias mo_ico_cols {
  if ($1 == computer) { return $rgb(96,165,250) $rgb(37,99,235) }
  if ($1 == folder) { return $rgb(253,203,88) $rgb(240,152,12) }
  if ($1 == globe) { return $rgb(56,189,248) $rgb(2,120,199) }
  if ($1 == page) { return $rgb(148,163,184) $rgb(90,106,128) }
  if ($1 == note) { return $rgb(52,211,153) $rgb(5,150,105) }
  if ($1 == palette) { return $rgb(244,114,182) $rgb(214,36,116) }
  if ($1 == termscreen) { return $rgb(71,85,105) $rgb(15,23,42) }
  if ($1 == gear) { return $rgb(129,140,248) $rgb(79,70,229) }
  if ($1 == bin) { return $rgb(148,163,184) $rgb(71,85,105) }
  if ($1 == info) { return $mo_c(accent2) $mo_c(accent) }
  if ($1 == image) { return $rgb(192,132,252) $rgb(140,50,230) }
  if ($1 == run) { return $rgb(251,146,60) $rgb(234,88,12) }
  if ($1 == power) { return $rgb(248,113,113) $rgb(220,38,38) }
  return $rgb(203,213,225) $rgb(148,163,184)
}

; $1=key -> Segoe Fluent Icons codepoint
alias mo_ico_glyph {
  if ($1 == computer) { return 59380 }
  if ($1 == folder) { return 59575 }
  if ($1 == globe) { return 59252 }
  if ($1 == page) { return 59557 }
  if ($1 == note) { return 59147 }
  if ($1 == palette) { return 59280 }
  if ($1 == termscreen) { return 59222 }
  if ($1 == gear) { return 59155 }
  if ($1 == bin) { return 59213 }
  if ($1 == info) { return 59718 }
  if ($1 == image) { return 59675 }
  if ($1 == run) { return 59240 }
  if ($1 == power) { return 59368 }
  return 59331
}

; app id -> icon key
alias mo_app_ico {
  if ($1 == explorer) { return folder }
  if ($1 == browser) { return globe }
  if ($1 == paint) { return palette }
  if ($1 == viewer) { return image }
  if ($1 == welcome) { return info }
  if ($1 == term) { return termscreen }
  if ($1 == notepad) { return note }
  if ($1 == settings) { return gear }
  if ($1 == run) { return run }
  return file
}

alias mo.ico.cache {
  if ($window(@MSLICO)) && ($hget(mcfg,icoth) == $hget(mcfg,theme)) { return }
  if (!$window(@MSLICO)) { window -hp @MSLICO 0 0 680 200 }
  drawrect -rfn @MSLICO $rgb(255,0,255) 1 0 0 680 200
  var %keys = $mo_ico_keys
  var %i = 1
  while (%i <= $numtok(%keys,32)) {
    var %cols = $mo_ico_cols($gettok(%keys,%i,32))
    var %r = 1
    while (%r <= 4) {
      mo.ico.tile $calc( ( %i - 1 ) * 48) $calc( ( %r - 1 ) * 48) $gettok(16 24 32 44,%r,32) $gettok(%cols,1,32) $gettok(%cols,2,32)
      inc %r
    }
    inc %i
  }
  hadd mcfg icoth $hget(mcfg,theme)
}

; one rounded gradient tile into @MSLICO: $1=x $2=y $3=size $4=top $5=bottom
alias mo.ico.tile {
  var %s = $3
  var %rad = $int( $calc( %s / 4.4 + 0.5))
  var %i = 0
  while (%i < %s) {
    var %in = 0
    if (%i < %rad) { %in = $calc( %rad - $sqrt( $calc( %rad * %rad - ( %rad - %i - 0.5 ) * ( %rad - %i - 0.5 )))) }
    elseif (%i >= $calc( %s - %rad)) { %in = $calc( %rad - $sqrt( $calc( %rad * %rad - ( %i - %s + %rad + 0.5 ) * ( %i - %s + %rad + 0.5 )))) }
    %in = $int( $calc( %in + 0.5))
    var %c = $mo_mix($4,$5,$calc( %i / ( %s - 1 )))
    ; a faint light rim along the top
    if (%i == 0) { %c = $mo_mix(%c,$rgb(255,255,255),0.25) }
    drawline -rn @MSLICO %c 1 $calc( $1 + %in) $calc( $2 + %i) $calc( $1 + %s - 1 - %in) $calc( $2 + %i)
    inc %i
  }
}

; $1=key $2=x $3=y $4=size (16, 24, 32 or 44; default 32)
alias mo.icon {
  var %s = $iif($4,$4,32)
  var %r = $findtok(16 24 32 44,%s,1,32)
  if (!%r) { %r = 3 | %s = 32 }
  mo.ico.cache
  var %c = $findtok($mo_ico_keys,$1,1,32)
  if (!%c) { %c = $findtok($mo_ico_keys,file,1,32) }
  drawcopy -tn @MSLICO $rgb(255,0,255) $calc( ( %c - 1 ) * 48) $calc( ( %r - 1 ) * 48) %s %s @MSLOS $2 $3
  mo.glyphc $rgb(255,255,255) $gettok(7 10 13 18,%r,32) $2 $3 %s %s $mo_ico_glyph($1)
}

; 16px mini icon for taskbars (app ids)
; 16px icon for an app id (title bars)
alias mo.icon16 {
  mo.icon $mo_app_ico($1) $2 $3 16
}

; ---------------------------------------------------------- context menu ----
; %momenu = x y            %momenu.items = label>action entries, | separated

alias mo.menu.open {
  ; $1=x $2=y $3-=selected desktop item name or $null
  ; items are glyph>label>action, | separated
  var %items
  if ($3 != $null) {
    %items = 59559>Open>mo.desk.open $3-
    %items = %items $+ $chr(124) $+ 59213>Delete>mo.desk.del $3-
  }
  else {
    %items = 59636>New folder>mo.desk.newfolder
    %items = %items $+ $chr(124) $+ 59557>New text document>mo.desk.newtext
    %items = %items $+ $chr(124) $+ 59180>Refresh>mo.render
    %items = %items $+ $chr(124) $+ 59280>Personalize>mo.launch settings
  }
  %momenu.items = %items
  var %w = 232
  var %h = $calc( $numtok(%items,124) * 34 + 10)
  var %x = $mo_min($1,$calc( $window(@MSLOS).bw - %w - 8))
  var %y = $mo_min($2,$calc( $window(@MSLOS).bh - $mo_tb_h - %h - 8))
  %momenu = %x %y
  mo.render
}

alias mo.menu.close {
  unset %momenu
  unset %momenu.items
  mo.render
}

alias mo.menu.draw {
  tokenize 32 %momenu
  var %x = $1
  var %y = $2
  var %w = 232
  var %h = $calc( $numtok(%momenu.items,124) * 34 + 10)
  mo.hit.reset m
  mo.shadow %x %y %w %h
  drawrect -rfdn @MSLOS $mo_c(surface) 1 %x %y %w %h 8 8
  drawrect -rdn @MSLOS $mo_c(border) 1 %x %y %w %h 8 8
  var %i = 1
  var %n = $numtok(%momenu.items,124)
  while (%i <= %n) {
    var %it = $gettok(%momenu.items,%i,124)
    var %act = $gettok(%it,3-,62)
    var %iy = $calc( %y + 5 + ( %i - 1 ) * 34)
    if (%mohov == mo.menu.run %act) { drawrect -rfdn @MSLOS $mo_c(hover) 1 $calc( %x + 5) %iy $calc( %w - 10) 32 5 5 }
    mo.glyphc $mo_c(text) 10 $calc( %x + 10) %iy 28 32 $gettok(%it,1,62)
    mo.text $mo_c(text) ui 9 $calc( %x + 44) %iy 32 $gettok(%it,2,62)
    mo.hit m $calc( %x + 5) %iy $calc( %w - 10) 32 c mo.menu.run %act
    inc %i
  }
}

alias mo.menu.run {
  unset %momenu
  unset %momenu.items
  var %c = $1-
  %c
}

alias mo.menu.click {
  var %a = $mo_hit_test(m,$1,$2,c)
  if (%a != $null) {
    unset %momenu
    unset %momenu.items
    %a
    return
  }
  mo.menu.close
}

; ------------------------------------------------------------- taskbar ----

; apps always on the taskbar
alias mo_pinned { return explorer browser term notepad paint settings }

alias mo_app_label {
  if ($1 == explorer) { return File Explorer }
  if ($1 == browser) { return Web Browser }
  if ($1 == term) { return Terminal }
  if ($1 == notepad) { return Notepad }
  if ($1 == paint) { return Paint }
  if ($1 == settings) { return Settings }
  if ($1 == viewer) { return Photos }
  if ($1 == welcome) { return Welcome }
  return $1
}

; id of the first window running app $1, or 0
alias mo_wm_app {
  var %z = $hget(mwm,z)
  var %i = 1
  while (%i <= $numtok(%z,32)) {
    if ($hget(mwm,$+(w,$gettok(%z,%i,32),.app)) == $1) { return $gettok(%z,%i,32) }
    inc %i
  }
  return 0
}

; apps that are real dialogs or windows rather than drawn windows
alias mo_app_open {
  if ($1 == term) { return $iif($window(@MSLTERM),1,0) }
  if ($1 == notepad) { return $iif($dialog(mo_np),1,0) }
  if ($1 == settings) { return $iif($dialog(mo_set),1,0) }
  return 0
}

alias mo.taskbar.draw {
  var %w = $1
  var %h = $2
  var %tb = $mo_tb_h
  var %ty = $calc( %h - %tb)
  mo.hit.reset t
  var %bg = $mo_c(tb)
  var %fg = $mo_c(tbt)
  drawrect -rfn @MSLOS %bg 1 0 %ty %w %tb
  drawline -rn @MSLOS $mo_c(tbb) 1 0 %ty %w %ty
  ; slots: Start, pinned apps, then any other open windows
  var %pins = $mo_pinned
  var %slots = start %pins
  var %z = $hget(mwm,z)
  var %i = 1
  while (%i <= $numtok(%z,32)) {
    var %id = $gettok(%z,%i,32)
    if (!$istok(%pins,$hget(mwm,$+(w,%id,.app)),32)) { %slots = %slots $+(w,%id) }
    inc %i
  }
  var %n = $numtok(%slots,32)
  var %sx = $int( $calc(( %w - %n * 48 + 4 ) / 2))
  var %foc = $mo_wm_focused
  var %tip = $null
  var %tipx = 0
  var %i = 1
  while (%i <= %n) {
    var %s = $gettok(%slots,%i,32)
    var %x = $calc( %sx + ( %i - 1 ) * 48)
    var %run = 0
    var %on = 0
    var %ico = file
    if (%s == start) {
      var %act = mo.start.toggle
      var %lbl = Start
      %on = $iif(%mostart,1,0)
    }
    elseif ($left(%s,1) == w) && ($mid(%s,2) isnum) {
      var %id = $mid(%s,2)
      %ico = $mo_app_ico($hget(mwm,$+(w,%id,.app)))
      var %lbl = $hget(mwm,$+(w,%id,.title))
      var %act = mo.wm.taskclick %id
      %run = 1
      %on = $iif(%foc == %id && $hget(mwm,$+(w,%id,.st)) != min,1,0)
    }
    else {
      %ico = $mo_app_ico(%s)
      var %lbl = $mo_app_label(%s)
      var %id = $mo_wm_app(%s)
      if (%id) {
        var %act = mo.wm.taskclick %id
        %run = 1
        %on = $iif(%foc == %id && $hget(mwm,$+(w,%id,.st)) != min,1,0)
      }
      else {
        var %act = mo.launch %s
        %run = $mo_app_open(%s)
      }
    }
    var %hov = $iif(%mohov == %act,1,0)
    if (%on) { drawrect -rfdn @MSLOS $mo_mix(%bg,%fg,0.15) 1 %x $calc( %ty + 4) 44 40 8 8 }
    elseif (%hov) { drawrect -rfdn @MSLOS $mo_mix(%bg,%fg,0.09) 1 %x $calc( %ty + 4) 44 40 8 8 }
    if (%s == start) { mo.start.logo $calc( %x + 12) $calc( %ty + 14) }
    else { mo.icon %ico $calc( %x + 10) $calc( %ty + 10) 24 }
    if (%on) { drawrect -rfdn @MSLOS $mo_c(accent2) 1 $calc( %x + 14) $calc( %ty + 41) 16 3 2 2 }
    elseif (%run) { drawrect -rfdn @MSLOS $mo_mix(%bg,%fg,0.45) 1 $calc( %x + 19) $calc( %ty + 41) 6 3 2 2 }
    mo.hit t %x $calc( %ty + 4) 44 40 c %act
    if (%hov) { %tip = %lbl | %tipx = $calc( %x + 22) }
    inc %i
  }
  ; tray: network, volume, clock and date
  var %fmt = HH:nn
  if ($hget(mcfg,clk24) != 1) { %fmt = h:nn tt }
  if ($hget(mcfg,clksec) == 1) { %fmt = $iif($hget(mcfg,clk24) == 1,HH:nn:ss,h:nn:ss tt) }
  var %t = $asctime($ctime,%fmt)
  var %dt = $asctime($ctime,dd/mm/yyyy)
  var %cw = $mo_max($width(%t,Segoe UI,9),$width(%dt,Segoe UI,9))
  var %cx = $calc( %w - 14 - %cw)
  drawtext -rn @MSLOS %fg "Segoe UI" 9 $calc( %cx + %cw - $width(%t,Segoe UI,9)) $calc( %ty + 7) %t
  drawtext -rn @MSLOS %fg "Segoe UI" 9 $calc( %cx + %cw - $width(%dt,Segoe UI,9)) $calc( %ty + 25) %dt
  mo.glyphc %fg 10 $calc( %cx - 64) %ty 26 %tb 59137
  mo.glyphc %fg 10 $calc( %cx - 38) %ty 26 %tb 59239
  if (%tip != $null) && (!%mostart) { mo.tooltip %tipx %ty %tip }
}

; the Start logo: four rounded squares in a 20px box
alias mo.start.logo {
  var %a = $mo_c(accent2)
  var %b = $mo_c(accent)
  drawrect -rfdn @MSLOS %a 1 $1 $2 9 9 3 3
  drawrect -rfdn @MSLOS %a 1 $calc( $1 + 11) $2 9 9 3 3
  drawrect -rfdn @MSLOS %b 1 $1 $calc( $2 + 11) 9 9 3 3
  drawrect -rfdn @MSLOS %b 1 $calc( $1 + 11) $calc( $2 + 11) 9 9 3 3
}

; a tooltip above a point: $1=centre x $2=y of the thing it describes $3-=text
alias mo.tooltip {
  var %tw = $calc( $width($3-,Segoe UI,9) + 20)
  var %x = $mo_max(4,$mo_min($int( $calc( $1 - %tw / 2)),$calc( $window(@MSLOS).bw - %tw - 4)))
  var %y = $calc( $2 - 36)
  var %bg = $mo_mix($mo_c(tb),$mo_c(tbt),0.08)
  drawrect -rfdn @MSLOS %bg 1 %x %y %tw 28 6 6
  drawrect -rdn @MSLOS $mo_c(tbb) 1 %x %y %tw 28 6 6
  mo.text $mo_c(tbt) ui 9 $calc( %x + 10) %y 28 $3-
}

; ----------------------------------------------------------- start menu ----

alias mo.start.toggle {
  if (%mostart) { unset %mostart }
  else { %mostart = 1 }
  mo.render
}

alias mo_start_items {
  ; icon|label|action, one per line
  var %it = folder|File Explorer|mo.launch explorer
  %it = %it $+ $lf $+ globe|Web Browser|mo.launch browser
  %it = %it $+ $lf $+ termscreen|Terminal|mo.launch term
  %it = %it $+ $lf $+ note|Notepad|mo.launch notepad
  %it = %it $+ $lf $+ palette|Paint|mo.launch paint
  %it = %it $+ $lf $+ image|Photos|mo.launch viewer C:\Users\Guest\Pictures\Sunset.bmp
  %it = %it $+ $lf $+ gear|Settings|mo.launch settings
  %it = %it $+ $lf $+ run|Run|mo.launch run
  %it = %it $+ $lf $+ computer|This PC|mo.launch explorer C:\
  %it = %it $+ $lf $+ folder|Documents|mo.launch explorer C:\Users\Guest\Documents\
  %it = %it $+ $lf $+ bin|Recycle Bin|mo.launch explorer C:\Recycled\
  %it = %it $+ $lf $+ info|About|mo.launch welcome
  return %it
}

; icon key for a file name
alias mo_file_ico {
  if (*.txt iswm $1-) { return page }
  if (*.bmp iswm $1-) || (*.png iswm $1-) { return image }
  if (*.paint iswm $1-) { return palette }
  if (*.exe iswm $1-) { return run }
  return file
}

; up to four files from the Desktop and Documents, full paths separated by |
alias mo_recent {
  var %out = $null
  var %d = 1
  while (%d <= 2) {
    var %dir = $gettok(C:\Users\Guest\Desktop\|C:\Users\Guest\Documents\,%d,124)
    var %list = $mo_fs_list(%dir)
    var %i = 1
    while (%i <= $numtok(%list,124)) {
      var %p = %dir $+ $gettok(%list,%i,124)
      if ($mo_fs_isfile(%p)) && ($numtok(%out,124) < 4) { %out = $instok(%out,%p,$calc( $numtok(%out,124) + 1),124) }
      inc %i
    }
    inc %d
  }
  return %out
}

alias mo.start.draw {
  var %w = $1
  var %h = $2
  mo.hit.reset s
  var %mw = 620
  var %mh = $mo_min(640,$calc( %h - $mo_tb_h - 24))
  var %x = $int( $calc(( %w - %mw ) / 2))
  var %y = $calc( %h - $mo_tb_h - %mh - 12)
  var %tx = $mo_c(text)
  var %t2 = $mo_c(text2)
  mo.shadow %x %y %mw %mh
  drawrect -rfdn @MSLOS $mo_c(surface) 1 %x %y %mw %mh 12 12
  ; search
  var %sx = $calc( %x + 28)
  var %sy = $calc( %y + 24)
  var %sw = $calc( %mw - 56)
  drawrect -rfdn @MSLOS $iif(%mohov == mo.start.search,$mo_c(hover),$mo_c(surface2)) 1 %sx %sy %sw 38 18 18
  drawrect -rdn @MSLOS $mo_c(border) 1 %sx %sy %sw 38 18 18
  mo.glyphc %t2 10 $calc( %sx + 10) %sy 28 38 59169
  mo.text %t2 ui 10 $calc( %sx + 42) %sy 38 Search for apps and files
  mo.hit s %sx %sy %sw 38 c mo.start.search
  ; pinned apps
  var %py = $calc( %sy + 58)
  mo.text %tx semi 10 $calc( %x + 40) %py 22 Pinned
  var %items = $mo_start_items
  var %cw = $int( $calc(( %mw - 56 ) / 6))
  var %i = 1
  while (%i <= $numtok(%items,10)) {
    var %it = $gettok(%items,%i,10)
    var %act = $gettok(%it,3-,124)
    var %cx = $calc( %x + 28 + $mo_mod($calc( %i - 1),6) * %cw)
    var %cy = $calc( %py + 32 + $int( $calc(( %i - 1 ) / 6)) * 92)
    if (%mohov == mo.start.run %act) { drawrect -rfdn @MSLOS $mo_c(hover) 1 $calc( %cx + 2) %cy $calc( %cw - 4) 86 8 8 }
    mo.icon $gettok(%it,1,124) $calc( %cx + ( %cw - 44 ) / 2) $calc( %cy + 10) 44
    var %lbl = $mo_clip($gettok(%it,2,124),$calc( %cw - 8),9)
    drawtext -rn @MSLOS %tx "Segoe UI" 9 $int( $calc( %cx + ( %cw - $width(%lbl,Segoe UI,9) ) / 2)) $calc( %cy + 60) %lbl
    mo.hit s $calc( %cx + 2) %cy $calc( %cw - 4) 86 c mo.start.run %act
    inc %i
  }
  ; recent files
  var %ry = $calc( %py + 32 + 2 * 92 + 12)
  mo.text %tx semi 10 $calc( %x + 40) %ry 22 Recommended
  var %rec = $mo_recent
  var %hw = $int( $calc(( %mw - 56 ) / 2))
  var %j = 1
  while (%j <= $numtok(%rec,124)) {
    var %p = $gettok(%rec,%j,124)
    var %fx = $calc( %x + 28 + $mo_mod($calc( %j - 1),2) * %hw)
    var %fy = $calc( %ry + 30 + $int( $calc(( %j - 1 ) / 2)) * 56)
    if (%mohov == mo.start.run mo.fs.openfile %p) { drawrect -rfdn @MSLOS $mo_c(hover) 1 %fx %fy $calc( %hw - 6) 52 8 8 }
    mo.icon $mo_file_ico(%p) $calc( %fx + 10) $calc( %fy + 10) 32
    drawtext -rn @MSLOS %tx "Segoe UI" 9 $calc( %fx + 54) $calc( %fy + 9) $mo_clip($mo_fs_base(%p),$calc( %hw - 70),9)
    drawtext -rn @MSLOS %t2 "Segoe UI" 8 $calc( %fx + 54) $calc( %fy + 28) $mo_ex_title($mo_fs_parent(%p))
    mo.hit s %fx %fy $calc( %hw - 6) 52 c mo.start.run mo.fs.openfile %p
    inc %j
  }
  ; footer: account and power
  var %fy = $calc( %y + %mh - 64)
  drawrect -rfdn @MSLOS $mo_c(surface2) 1 %x %fy %mw 64 12 12
  drawrect -rfn @MSLOS $mo_c(surface2) 1 %x %fy %mw 14
  drawline -rn @MSLOS $mo_c(border) 1 %x %fy $calc( %x + %mw) %fy
  drawrect -rdn @MSLOS $mo_c(border) 1 %x %y %mw %mh 12 12
  drawrect -refn @MSLOS $mo_c(accent) 1 $calc( %x + 34) $calc( %fy + 16) 32 32
  var %gw = $width(G,Segoe UI Semibold,11)
  mo.text $rgb(255,255,255) semi 11 $int( $calc( %x + 50 - %gw / 2)) $calc( %fy + 16) 32 G
  mo.text %tx ui 10 $calc( %x + 78) %fy 64 Guest
  var %px = $calc( %x + %mw - 70)
  if (%mohov == mo.start.run mo.quit) { drawrect -rfdn @MSLOS $mo_c(hover) 1 %px $calc( %fy + 14) 36 36 6 6 }
  mo.glyphc %tx 11 %px $calc( %fy + 14) 36 36 59368
  mo.hit s %px $calc( %fy + 14) 36 36 c mo.start.run mo.quit
  ; clicks on empty parts of the panel keep it open
  mo.hit s %x %y %mw %mh c mo.start.keep
}

alias mo.start.keep {
  %mostart = 1
  mo.render
}

alias mo.start.search {
  var %q = $input(Search for apps and files:,e,,Search)
  if (%q == $null) { return }
  var %m = $+(*,%q,*)
  var %items = $mo_start_items
  var %i = 1
  while (%i <= $numtok(%items,10)) {
    var %it = $gettok(%items,%i,10)
    if (%m iswm $gettok(%it,2,124)) {
      var %c = $gettok(%it,3-,124)
      %c
      return
    }
    inc %i
  }
  var %i = 1
  while ($hget(mfs,%i).item != $null) {
    var %k = $ifmatch
    if ($left(%k,2) == F|) && (%m iswm $mo_fs_base($mo_fp($mid(%k,3)))) {
      mo.fs.openfile $mo_fp($mid(%k,3))
      return
    }
    inc %i
  }
  noop $input(Nothing matches " $+ %q $+ ".,o,,Search)
}

alias mo.start.run {
  unset %mostart
  var %c = $1-
  %c
}

alias mo.start.click {
  var %a = $mo_hit_test(s,$1,$2,c)
  if (%a != $null) {
    unset %mostart
    %a
    return
  }
  unset %mostart
  mo.render
}

; --------------------------------------------------------- input routing ----

alias mo.click {
  if ($window(@MSLOS) == $null) { return }
  var %x = $1
  var %y = $2
  if (%modrag.moved) { unset %modrag.moved | return }
  if (%momenu != $null) { mo.menu.click %x %y | return }
  if (%mostart) { mo.start.click %x %y | return }
  ; windows, topmost first
  var %z = $hget(mwm,z)
  var %i = $numtok(%z,32)
  while (%i >= 1) {
    var %id = $gettok(%z,%i,32)
    if ($hget(mwm,$+(w,%id,.st)) != min) {
      var %wx = $hget(mwm,$+(w,%id,.x))
      var %wy = $hget(mwm,$+(w,%id,.y))
      var %ww = $hget(mwm,$+(w,%id,.w))
      var %wh = $hget(mwm,$+(w,%id,.h))
      if ($hget(mwm,$+(w,%id,.st)) == max) { %wx = 0 | %wy = 0 | %ww = $window(@MSLOS).bw | %wh = $calc( $window(@MSLOS).bh - $mo_tb_h) }
      if ($inrect(%x,%y,%wx,%wy,%ww,%wh)) {
        mo.wm.focus %id
        var %a = $mo_hit_test($+(w,%id),%x,%y,c)
        if (%a != $null) {
          %a
          mo.render
          return
        }
        var %app = $hget(mwm,$+(w,%id,.app))
        var %c = mo.app. $+ %app $+ .click %id %x %y
        %c
        mo.render
        return
      }
    }
    dec %i
  }
  ; desktop icons
  var %a = $mo_hit_test(d,%x,%y,c)
  if (%a != $null) {
    %a
    return
  }
  ; taskbar
  var %a = $mo_hit_test(t,%x,%y,c)
  if (%a != $null) {
    %a
    return
  }
  ; bare desktop clears selection
  if (%y < $calc( $window(@MSLOS).bh - $mo_tb_h)) {
    if (%modsel) { unset %modsel | mo.render }
  }
}

alias mo.dclick {
  if ($window(@MSLOS) == $null) { return }
  var %x = $1
  var %y = $2
  if (%momenu != $null) { return }
  if (%mostart) { return }
  var %z = $hget(mwm,z)
  var %i = $numtok(%z,32)
  while (%i >= 1) {
    var %id = $gettok(%z,%i,32)
    if ($hget(mwm,$+(w,%id,.st)) != min) {
      if ($inrect(%x,%y,$hget(mwm,$+(w,%id,.x)),$hget(mwm,$+(w,%id,.y)),$hget(mwm,$+(w,%id,.w)),$hget(mwm,$+(w,%id,.h)))) {
        mo.wm.focus %id
        var %a = $mo_hit_test($+(w,%id),%x,%y,d)
        if (%a == $null) { %a = $mo_hit_test($+(w,%id),%x,%y,c) }
        if (%a != $null) {
          %a
          mo.render
          return
        }
        var %app = $hget(mwm,$+(w,%id,.app))
        var %c = mo.app. $+ %app $+ .dclick %id %x %y
        %c
        return
      }
    }
    dec %i
  }
  var %a = $mo_hit_test(d,%x,%y,d)
  if (%a == $null) { %a = $mo_hit_test(d,%x,%y,c) }
  if (%a != $null) { %a | return }
  var %a = $mo_hit_test(t,%x,%y,d)
  if (%a != $null) { %a }
}

alias mo.rclick {
  if ($window(@MSLOS) == $null) { return }
  var %x = $1
  var %y = $2
  if (%momenu != $null) { mo.menu.close | return }
  if (%mostart) { unset %mostart | mo.render | return }
  if (%y >= $calc( $window(@MSLOS).bh - $mo_tb_h)) { return }
  ; desktop context menu (with the selected icon, if any)
  var %sel = $null
  var %a = $mo_hit_test(d,%x,%y,c)
  if (%a != $null) {
    tokenize 32 %a
    if ($1 == mo.desk.select) { %sel = $2- }
  }
  mo.menu.open %x %y %sel
}

alias mo.mouse {
  if ($window(@MSLOS) == $null) { return }
  var %x = $1
  var %y = $2
  var %lb = $3
  ; dragging a title bar
  if (%modrag) {
    if (!%lb) { unset %modrag | unset %modrag.dx | unset %modrag.dy | return }
    var %id = %modrag
    var %nx = $calc( %x - %modrag.dx)
    var %ny = $calc( %y - %modrag.dy)
    if (%nx < -40) { %nx = -40 }
    if (%ny < 0) { %ny = 0 }
    if (%nx > $calc( $window(@MSLOS).bw - 60)) { %nx = $calc( $window(@MSLOS).bw - 60) }
    if (%ny > $calc( $window(@MSLOS).bh - 70)) { %ny = $calc( $window(@MSLOS).bh - 70) }
    var %moved = $calc( $abs( $calc( %nx - $hget(mwm,$+(w,%id,.x)))) + $abs( $calc( %ny - $hget(mwm,$+(w,%id,.y)))))
    if (%moved > 2) { %modrag.moved = 1 }
    hadd mwm $+(w,%id,.x) %nx
    hadd mwm $+(w,%id,.y) %ny
    mo.render
    return
  }
  if (%lb) {
    ; begin a drag if over a title bar, or hand to paint
    var %id = $mo_wm_at(%x,%y)
    if (%id) {
      var %app = $hget(mwm,$+(w,%id,.app))
      var %wx = $hget(mwm,$+(w,%id,.x))
      var %wy = $hget(mwm,$+(w,%id,.y))
      if ($hget(mwm,$+(w,%id,.st)) == max) { return }
      if (%y >= %wy && %y < $calc( %wy + $mo_cap_h) && %x < $calc( %wx + $hget(mwm,$+(w,%id,.w)) - 138)) {
        %modrag = %id
        %modrag.dx = $calc( %x - %wx)
        %modrag.dy = $calc( %y - %wy)
        return
      }
      if (%app == paint) {
        mo.app.paint.drag %id %x %y
        return
      }
    }
    return
  }
  ; hover highlight
  var %h = $mo_hover_at(%x,%y)
  if (%h != %mohov) {
    %mohov = %h
    mo.render
  }
}

alias mo_hover_at {
  var %x = $1
  var %y = $2
  var %a = $null
  if (%momenu != $null) { %a = $mo_hit_test(m,%x,%y,c) | return %a }
  if (%mostart) { %a = $mo_hit_test(s,%x,%y,c) | if (%a != $null) { return %a } }
  var %z = $hget(mwm,z)
  var %i = $numtok(%z,32)
  while (%i >= 1) {
    var %id = $gettok(%z,%i,32)
    if ($hget(mwm,$+(w,%id,.st)) != min) {
      if ($inrect(%x,%y,$hget(mwm,$+(w,%id,.x)),$hget(mwm,$+(w,%id,.y)),$hget(mwm,$+(w,%id,.w)),$hget(mwm,$+(w,%id,.h)))) {
        %a = $mo_hit_test($+(w,%id),%x,%y,c)
        return %a
      }
    }
    dec %i
  }
  %a = $mo_hit_test(d,%x,%y,c)
  if (%a != $null) { return %a }
  %a = $mo_hit_test(t,%x,%y,c)
  return %a
}

alias mo.leave {
  if (%modrag) { return }
  if (%mohov) { unset %mohov | mo.render }
}

; ---------------------------------------------------------------- tick ----

alias mo.tick {
  if ($window(@MSLOS) == $null) { return }
  var %w = $window(@MSLOS).w
  var %h = $window(@MSLOS).h
  if (%w != $window(@MSLOS).bw) || (%h != $window(@MSLOS).bh) {
    if (%w > 100) && (%h > 100) { drawsize @MSLOS %w %h | mo.render }
  }
  var %fmt = HH:nn
  if ($hget(mcfg,clk24) != 1) { %fmt = h:nn tt }
  if ($hget(mcfg,clksec) == 1) { %fmt = $iif($hget(mcfg,clk24) == 1,HH:nn:ss,h:nn:ss tt) }
  var %t = $asctime($ctime,%fmt)
  if (%t != %moclk) {
    %moclk = %t
    mo.render
  }
}

; ------------------------------------------------------ desktop actions ----

alias mo.launch {
  ; $1 = app id, $2- = arg
  if ($1 == explorer) { mo.wm.open explorer $iif($2-,$2-,C:\) | return }
  if ($1 == browser) { mo.wm.open browser $2- | return }
  if ($1 == paint) { mo.wm.open paint $2- | return }
  if ($1 == viewer) { mo.wm.open viewer $2- | return }
  if ($1 == welcome) { mo.wm.open welcome | return }
  if ($1 == notepad) { mo.np.open $2- | return }
  if ($1 == term) { mo.term.open | return }
  if ($1 == settings) { mo.set.open | return }
  if ($1 == run) { mo.run.open | return }
}

alias mo.desk.newfolder {
  var %dir = C:\ $+ Users\ $+ Guest\ $+ Desktop\
  var %n = $input(New folder name:,e,,New Folder,New Folder)
  if (%n == $null) { return }
  %n = $mo_fs_clean(%n)
  if (%n == $null) { return }
  var %path = %dir $+ %n
  if ($mo_fs_isdir(%path) || $mo_fs_isfile(%path)) {
    %path = %dir $+ $mo_fs_unique(%dir,%n,folder)
  }
  mo.fs.mkdir %path
  mo.save
  mo.render
}

alias mo.desk.newtext {
  var %dir = C:\ $+ Users\ $+ Guest\ $+ Desktop\
  var %n = $input(File name:,e,,New Text File,Untitled.txt)
  if (%n == $null) { return }
  %n = $mo_fs_clean(%n)
  if (%n == $null) { return }
  if (. !isin %n) { %n = %n $+ .txt }
  var %path = %dir $+ %n
  if ($mo_fs_isdir(%path) || $mo_fs_isfile(%path)) {
    %path = %dir $+ $mo_fs_unique(%dir,%n,file)
  }
  mo.fs.write $+(",%path,") MSL OS $crlf $+ Created $asctime($ctime,ddd dd mmm yyyy HH:nn) $crlf
  mo.save
  mo.render
}

alias mo.desk.del {
  ; $1- = desktop item name
  var %e = $mo_desk_entries
  var %i = 1
  var %n = $numtok(%e,10)
  while (%i <= %n) {
    var %it = $gettok(%e,%i,10)
    if ($gettok(%it,1,124) == $1-) {
      if ($left($1-,3) == fs.) {
        var %dir = C:\ $+ Users\ $+ Guest\ $+ Desktop\
        var %name = $mid($1-,4)
        mo.fs.delete %dir $+ %name
        unset %modsel
        mo.render
      }
      return
    }
    inc %i
  }
}

; ---------------------------------------------------------- menu events ----

menu @MSLOS {
  sclick:mo.click $mouse.x $mouse.y
  dclick:mo.dclick $mouse.x $mouse.y
  rclick:mo.rclick $mouse.x $mouse.y
  uclick:mo.uclick $mouse.x $mouse.y
  mouse:mo.mouse $mouse.x $mouse.y $mouse.lb
  leave:mo.leave
  wheel:mo.wheel $mouse.dy
}

menu @MSLTERM {
  wheel:mt.wheel $mouse.dy
}

alias mo.uclick {
  ; the press that starts a drag has already been handled as a click, so the
  ; drag is over when the button comes up
  unset %modrag.moved
  if (%modrag) {
    unset %modrag
    unset %modrag.dx
    unset %modrag.dy
    return
  }
  var %id = $mo_wm_at($1,$2)
  if (%id) && ($hget(mwm,$+(w,%id,.app)) == paint) { mo.paint.end %id }
}

alias mo.wheel {
  ; $1 = dy (dy > 0 scrolls toward the top)
  var %z = $hget(mwm,z)
  var %id = $mo_wm_at($mouse.x,$mouse.y)
  if (%id) {
    var %app = $hget(mwm,$+(w,%id,.app))
    if (%app == explorer) {
      var %s = $hget(mst,$+(x,%id,.scr))
      if (%s == $null) { %s = 0 }
      if ($1 > 0) { inc %s }
      else { dec %s }
      if (%s < 0) { %s = 0 }
      if (%s > 40) { %s = 40 }
      hadd mst $+(x,%id,.scr) %s
      mo.render
    }
  }
}

on *:CLOSE:@: {
  if ($target == @MSLOS) {
    .timermo.tick off
    .timermo.boot off
    mo.save
  }
}

; ------------------------------------------------- virtual filesystem ----
; directories:  D|C:\path\        value = child names, | separated ("-" if empty)
; files:        F|C:\path\name    value = content, CRLF stored as $chr(1)

alias mo.fs.init {
  if ($hget(mfs,ready)) { mo.fs.repair | return }
  hadd mfs ready 1
  hadd mfs ver 2
  ; root and system tree
  hadd mfs D|C:\ -
  mo.fs.mkdir C:\Users\
  mo.fs.mkdir C:\Users\Guest\
  mo.fs.mkdir C:\Users\Guest\Desktop\
  mo.fs.mkdir C:\Users\Guest\Documents\
  mo.fs.mkdir C:\Users\Guest\Documents\Secret\
  mo.fs.mkdir C:\Users\Guest\Pictures\
  mo.fs.mkdir "C:\Program Files\"
  mo.fs.mkdir C:\Recycled\
  mo.fs.write C:\Users\Guest\Desktop\Readme.txt Welcome to MSL OS! $+ $crlf $+ $crlf $+ Everything you see is drawn by one mIRC script: the taskbar, this window manager, the icons, even the Start menu. $+ $crlf $+ $crlf $+ Try: $+ $crlf $+ - double-click icons to open things $+ $crlf $+ - drag windows by their title bars $+ $crlf $+ - right-click the desktop for a context menu $+ $crlf $+ - open the Terminal and type help $+ $crlf $+ - browse msl://home in the Web Browser, or any http:// page $+ $crlf
  mo.fs.write "C:\Users\Guest\Desktop\Getting Started.txt" Getting started with MSL OS $+ $crlf $+ ========================= $+ $crlf $+ 1. Click Start (bottom left) or double-click icons. $+ $crlf $+ 2. Terminal: telnet, connect, tls and ssh commands. Try: telnet 127.0.0.1 2323 if you are running terminal-demo.mrc. $+ $crlf $+ 3. Notepad and Paint save into this virtual disk (C:\). $+ $crlf $+ 4. Settings changes the theme live. $+ $crlf $+ 5. Files are kept in mslos\fs.dat between sessions. $+ $crlf
  mo.fs.write C:\Users\Guest\Documents\Notes.txt Remember: the whole OS is one picture window and a lot of /drawrect. $crlf
  mo.fs.write C:\Users\Guest\Documents\Ideas.txt - window animations $crlf $+ - filesystem search $crlf $+ - solitaire $crlf
  mo.fs.write C:\Users\Guest\Documents\Secret\Diary.txt Day 1: wrote an operating system in an IRC scripting language. Nobody thought it was a good idea. It was not, but here we are. $crlf
  mo.fs.write C:\Users\Guest\Pictures\Sunset.bmp seed:sunset
  mo.fs.write C:\Users\Guest\Pictures\Mountains.bmp seed:mountains
  mo.fs.write "C:\Program Files\browser.exe" MSL Web Browser 1.0
  mo.fs.write "C:\Program Files\explorer.exe" MSL File Explorer 1.0
  mo.fs.write "C:\Program Files\notepad.exe" MSL Notepad 1.0
  mo.fs.write "C:\Program Files\paint.exe" MSL Paint 1.0
  mo.fs.write "C:\Program Files\terminal.exe" MSL Terminal 1.0
}

; disks saved by MSL OS before ver 2 never got the paths with spaces in them
; disks saved before ver 3 lost every path with a space in it (hash table
; item names cannot hold spaces); recreate the stock ones
alias mo.fs.repair {
  if ($hget(mfs,ver) >= 3) { return }
  hadd mfs ver 3
  ; leftovers of the space being cut off
  hdel mfs F|C:\Users\Guest\Desktop\Getting
  hdel mfs D|C:\Program
  hdel -w mfs F|C:\Program*
  mo.fs.mkdir C:\Program Files\
  if (!$mo_fs_isfile(C:\Users\Guest\Desktop\Getting Started.txt)) {
    mo.fs.write "C:\Users\Guest\Desktop\Getting Started.txt" Getting started with MSL OS $+ $crlf $+ ========================= $+ $crlf $+ 1. Click Start or double-click icons. $+ $crlf $+ 2. Terminal: telnet, connect, tls and ssh commands. $+ $crlf $+ 3. Notepad and Paint save into this virtual disk (C:\). $+ $crlf $+ 4. Settings changes the theme live. $+ $crlf $+ 5. Files are kept in mslos\fs.dat between sessions. $+ $crlf
  }
  var %apps = browser Web Browser|explorer File Explorer|notepad Notepad|paint Paint|terminal Terminal
  var %i = 1
  while (%i <= 5) {
    var %a = $gettok(%apps,%i,124)
    mo.fs.write $+(",C:\Program Files\,$gettok(%a,1,32),.exe") MSL $gettok(%a,2-,32) 1.0
    inc %i
  }
  mo.save
}

; directories are stored as D|C:\path\ (trailing backslash); callers often
; join a parent and a child name without one, so accept both forms
alias mo_fs_dir { return $iif($right($1,1) == \,$1,$1 $+ \) }

; hash table key for a path: item names cannot contain spaces, so spaces are
; stored as $chr(160)
alias mo_fk { return $replace($1-,$chr(32),$chr(160)) }

; path from a key (without the D| or F| prefix)
alias mo_fp { return $replace($1-,$chr(160),$chr(32)) }

alias mo_fs_isdir {
  if ($hget(mfs,$mo_fk($+(D|,$mo_fs_dir($1-)))) != $null) { return $true }
  return $iif($hget(mfs,$mo_fk($+(D|,$1-))) != $null,$true,$false)
}

alias mo_fs_isfile { return $iif($hget(mfs,$mo_fk($+(F|,$1-))) != $null,$true,$false) }

alias mo_fs_list {
  var %l = $hget(mfs,$mo_fk($+(D|,$mo_fs_dir($1-))))
  if (%l == $null) { %l = $hget(mfs,$mo_fk($+(D|,$1-))) }
  if (%l == $null) || (%l == -) { return $null }
  return %l
}

alias mo.fs.addchild {
  ; $1- = dir|name
  var %dir = $gettok($1-,1,124)
  var %l = $mo_fs_list(%dir)
  %l = $addtok(%l,$gettok($1-,2,124),124)
  hadd mfs $mo_fk($+(D|,$mo_fs_dir(%dir))) %l
}

alias mo.fs.delchild {
  ; $1- = dir|name
  var %dir = $gettok($1-,1,124)
  var %l = $mo_fs_list(%dir)
  %l = $remtok(%l,$gettok($1-,2,124),1,124)
  if (%l == $null) { %l = - }
  hadd mfs $mo_fk($+(D|,$mo_fs_dir(%dir))) %l
}

alias mo.fs.mkdir {
  ; $1- = path (quotes optional)
  var %d = $mo_fs_dir($remove($1-,$chr(34)))
  if ($mo_fs_isdir(%d)) { return }
  var %parent = $mo_fs_parent(%d)
  if (!$mo_fs_isdir(%parent)) { return }
  hadd mfs $mo_fk($+(D|,%d)) -
  mo.fs.addchild $+(%parent,$chr(124),$mo_fs_base(%d))
}

alias mo.fs.write {
  ; $1 = path ("quoted" if it has spaces), $2- = content
  ; (CRLF and LF preserved via $chr(1))
  var %path = $1
  var %body = $2-
  if ($left($1-,1) == $chr(34)) {
    var %q = $pos($1-,$chr(34),2)
    %path = $mid($1-,2,$calc( %q - 2))
    %body = $mid($1-,$calc( %q + 2))
  }
  var %dir = $mo_fs_parent(%path)
  var %name = $mo_fs_base(%path)
  if (!$mo_fs_isdir(%dir)) { return }
  var %c = $replace(%body,$crlf,$chr(1))
  %c = $replace(%c,$lf,$chr(1))
  hadd mfs $mo_fk($+(F|,%path)) $iif(%c == $null,-,%c)
  if (!$istok($mo_fs_list(%dir),%name,124)) { mo.fs.addchild $+(%dir,$chr(124),%name) }
}

alias mo_fs_read {
  var %c = $hget(mfs,$mo_fk($+(F|,$1-)))
  if (%c == $null) || (%c == -) { return $null }
  return $replace(%c,$chr(1),$crlf)
}

alias mo_fs_clean {
  var %n = $remove($1,\,/,:,*,?,",$chr(60),$chr(62),|)
  return %n
}

alias mo_fs_unique {
  ; $1=dir $2=base name $3=type -> a name not taken
  var %n = $2
  var %i = 2
  while ($iif($3 == folder,$mo_fs_isdir($+($1,%n)),$mo_fs_isfile($+($1,%n)))) {
    %n = $2 $+ ( $+ %i $+ )
    inc %i
  }
  return %n
}

alias mo_fs_parent {
  var %p = $1
  if ($right(%p,1) == \) { %p = $left(%p,$calc( $len(%p) - 1)) }
  var %n = $numtok(%p,92)
  if (%n <= 1) { return C:\ }
  %p = $gettok(%p,1- $+ $calc( %n - 1),92)
  return %p $+ \
}

alias mo_fs_base {
  var %p = $1
  if ($right(%p,1) == \) { %p = $left(%p,$calc( $len(%p) - 1)) }
  return $gettok(%p,-1,92)
}

alias mo.fs.delete {
  ; $1- = full path -> move to C:\Recycled\ (delete for good if already there)
  var %path = $1-
  if ($right(%path,1) == \) { %path = $left(%path,$calc( $len(%path) - 1)) }
  var %dir = $mo_fs_parent(%path)
  var %name = $mo_fs_base(%path)
  if (%dir == C:\Recycled\) {
    if ($input(Permanently delete %name $+ ?,y,,Confirm) != $true) { return }
    mo.fs.purge %path
    mo.fs.delchild $+(%dir,$chr(124),%name)
    mo.save
    return
  }
  var %new = $mo_fs_unique(C:\Recycled\,%name,$iif($mo_fs_isdir(%path),folder,file))
  ; no trailing \ on either side: mo.fs.move rewrites "D|old\..." as "D|new\..."
  mo.fs.move $+(%path,$chr(124),C:\Recycled\,%new)
  mo.fs.delchild $+(%dir,$chr(124),%name)
  mo.save
}

alias mo.fs.move {
  ; $1- = oldpath|newpath, both without a trailing \
  ; renames every key at or under oldpath
  var %oldD = $mo_fk($+(D|,$gettok($1-,1,124)))
  var %oldF = $mo_fk($+(F|,$gettok($1-,1,124)))
  var %newD = $mo_fk($+(D|,$gettok($1-,2,124)))
  var %newF = $mo_fk($+(F|,$gettok($1-,2,124)))
  var %keys
  var %i = 1
  while ($hget(mfs,%i).item != $null) {
    var %k = $ifmatch
    if (%k == %oldD) || (%k == %oldF) { %keys = %keys $+ $chr(1) $+ %k }
    elseif ($left(%k,$calc( $len(%oldD) + 1)) == %oldD $+ \) { %keys = %keys $+ $chr(1) $+ %k }
    elseif ($left(%k,$calc( $len(%oldF) + 1)) == %oldF $+ \) { %keys = %keys $+ $chr(1) $+ %k }
    inc %i
  }
  var %i = 1
  var %n = $numtok(%keys,1)
  while (%i <= %n) {
    var %k = $gettok(%keys,%i,1)
    var %v = $hget(mfs,%k)
    var %nk = %newD $+ $mid(%k,$calc( $len(%oldD) + 1))
    if ($left(%k,$len(%oldF)) == %oldF) { %nk = %newF $+ $mid(%k,$calc( $len(%oldF) + 1)) }
    hadd mfs %nk %v
    hdel mfs %k
    inc %i
  }
  mo.fs.addchild $+(C:\Recycled\,$chr(124),$mo_fs_base($gettok($1-,2,124)))
}

alias mo.fs.purge {
  ; $1- = path: remove a file or a whole folder
  var %oldD = $mo_fk($+(D|,$1-))
  var %oldF = $mo_fk($+(F|,$1-))
  var %keys
  var %i = 1
  while ($hget(mfs,%i).item != $null) {
    var %k = $ifmatch
    if (%k == %oldD) || (%k == %oldF) { %keys = %keys $+ $chr(1) $+ %k }
    elseif ($left(%k,$calc( $len(%oldD) + 1)) == %oldD $+ \) { %keys = %keys $+ $chr(1) $+ %k }
    elseif ($left(%k,$calc( $len(%oldF) + 1)) == %oldF $+ \) { %keys = %keys $+ $chr(1) $+ %k }
    inc %i
  }
  var %i = 1
  var %n = $numtok(%keys,1)
  while (%i <= %n) {
    hdel mfs $gettok(%keys,%i,1)
    inc %i
  }
}

alias mo.fs.openfile {
  ; $1- = full path (may contain spaces)
  var %p = $1-
  if ($mo_fs_isdir(%p)) { mo.launch explorer $mo_fs_dir(%p) | return }
  if (!$mo_fs_isfile(%p)) { return }
  if (*.txt iswm %p) { mo.np.openfile %p | return }
  if (*.paint iswm %p) { mo.wm.open paint %p | return }
  if (*.bmp iswm %p) || (*.png iswm %p) { mo.wm.open viewer %p | return }
  noop $input(No program is associated with $mo_fs_base(%p) $+ .,o,,MSL OS)
}

; ============================================================================
;                                  APPS
; ============================================================================

; ------------------------------------------------------------- explorer ----

alias mo.app.explorer.open {
  var %id = $1
  var %p = $iif($2- != $null,$2-,C:\)
  if (!$mo_fs_isdir(%p)) { %p = C:\ }
  hadd mst $+(x,%id,.path) %p
  mo.wm.title %id $mo_ex_title(%p)
}

alias mo_ex_title {
  if ($1 == C:\) { return This PC }
  if ($1 == C:\Recycled\) { return Recycle Bin }
  if ($1 == C:\ $+ Users\ $+ Guest\ $+ Desktop\) { return Desktop }
  var %b = $mo_fs_base($1)
  if ($right(%b,1) == \) { %b = $left(%b,$calc( $len(%b) - 1)) }
  return %b
}

alias mo.app.explorer.close { }

alias mo.app.explorer.draw {
  var %id = $1
  var %x = $2
  var %y = $3
  var %w = $4
  var %h = $5
  var %path = $hget(mst,$+(x,%id,.path))
  var %sel = $hget(mst,$+(x,%id,.sel))
  var %scr = $hget(mst,$+(x,%id,.scr))
  if (%scr == $null) { %scr = 0 }
  var %tx = $mo_c(text)
  var %t2 = $mo_c(text2)
  ; toolbar: up, path, new folder, delete
  mo.toolbar %x %y %w
  mo.tb.btn %id $calc( %x + 8) $calc( %y + 6) 32 32 59210 - $iif(%path == C:\,mo.nop,mo.ex.up %id)
  var %dx = $calc( %x + %w - 90)
  var %nx = $calc( %dx - 124)
  mo.tb.btn %id %nx $calc( %y + 6) 118 32 59636 New_folder mo.ex.newf %id
  mo.tb.btn %id %dx $calc( %y + 6) 82 32 59213 Delete $iif(%sel == $null,mo.nop,mo.ex.del %id)
  var %ax = $calc( %x + 48)
  var %aw = $calc( %nx - 8 - %ax)
  drawrect -rfdn @MSLOS $mo_c(surface) 1 %ax $calc( %y + 8) %aw 28 6 6
  drawrect -rdn @MSLOS $mo_c(border) 1 %ax $calc( %y + 8) %aw 28 6 6
  mo.ex.crumbs %id $calc( %ax + 6) $calc( %y + 8) $calc( %aw - 12) %path
  ; sidebar
  var %sw = 176
  var %top = $calc( %y + 45)
  var %bot = $calc( %y + %h - 24)
  drawline -rn @MSLOS $mo_c(border) 1 $calc( %x + %sw) %top $calc( %x + %sw) %bot
  var %places = computer|This PC|C:\ $+ $lf $+ folder|Desktop|C:\Users\Guest\Desktop\ $+ $lf $+ page|Documents|C:\Users\Guest\Documents\ $+ $lf $+ image|Pictures|C:\Users\Guest\Pictures\ $+ $lf $+ bin|Recycle Bin|C:\Recycled\
  var %i = 1
  while (%i <= 5) {
    var %pl = $gettok(%places,%i,10)
    var %pp = $gettok(%pl,3,124)
    var %ry = $calc( %top + 8 + ( %i - 1 ) * 36)
    if (%ry > $calc( %bot - 34)) { break }
    if (%path == %pp) {
      drawrect -rfdn @MSLOS $mo_c(sel) 1 $calc( %x + 6) %ry $calc( %sw - 12) 32 6 6
      drawrect -rfdn @MSLOS $mo_c(accent) 1 $calc( %x + 6) $calc( %ry + 9) 3 14 2 2
    }
    elseif (%mohov == mo.ex.go %id %pp) { drawrect -rfdn @MSLOS $mo_c(hover) 1 $calc( %x + 6) %ry $calc( %sw - 12) 32 6 6 }
    mo.icon $gettok(%pl,1,124) $calc( %x + 18) $calc( %ry + 8) 16
    mo.text %tx ui 9 $calc( %x + 44) %ry 32 $gettok(%pl,2,124)
    mo.hit $+(w,%id) $calc( %x + 6) %ry $calc( %sw - 12) 32 c mo.ex.go %id %pp
    inc %i
  }
  ; items: folders first, then files
  var %folders
  var %files
  var %list = $mo_fs_list(%path)
  var %i = 1
  while (%i <= $numtok(%list,124)) {
    var %n = $gettok(%list,%i,124)
    if ($mo_fs_isdir($+(%path,%n))) { %folders = $addtok(%folders,%n,124) }
    else { %files = $addtok(%files,%n,124) }
    inc %i
  }
  %folders = $sorttok(%folders,124)
  %files = $sorttok(%files,124)
  var %all = %folders $+ $iif(%folders != $null && %files != $null,$chr(124)) $+ %files
  var %cx = $calc( %x + %sw + 1)
  var %cw = $calc( %w - %sw - 1)
  var %cols = $int( $calc(( %cw - 16 ) / 96))
  if (%cols < 1) { %cols = 1 }
  var %n = $numtok(%all,124)
  if (%n == 0) { mo.text %t2 ui 9 $calc( %cx + 24) $calc( %top + 16) 20 This folder is empty. }
  var %i = $calc( %scr * %cols + 1)
  while (%i <= %n) {
    var %name = $gettok(%all,%i,124)
    var %slot = $calc( %i - 1 - %scr * %cols)
    var %ix = $calc( %cx + 8 + $mo_mod(%slot,%cols) * 96)
    var %iy = $calc( %top + 8 + $int( $calc( %slot / %cols)) * 96)
    if ($calc( %iy + 90) > %bot) { break }
    if (%sel == %name) {
      drawrect -rfdn @MSLOS $mo_c(sel) 1 %ix %iy 90 90 6 6
      drawrect -rdn @MSLOS $mo_mix($mo_c(sel),$mo_c(accent),0.35) 1 %ix %iy 90 90 6 6
    }
    elseif (%mohov == mo.ex.select %id %name) { drawrect -rfdn @MSLOS $mo_c(hover) 1 %ix %iy 90 90 6 6 }
    var %ic = $iif($mo_fs_isdir($+(%path,%name)),folder,$mo_file_ico(%name))
    mo.icon %ic $calc( %ix + 23) $calc( %iy + 10) 44
    var %lbl = $mo_clip(%name,84,9)
    drawtext -rn @MSLOS %tx "Segoe UI" 9 $int( $calc( %ix + 45 - $width(%lbl,Segoe UI,9) / 2)) $calc( %iy + 62) %lbl
    mo.hit $+(w,%id) %ix %iy 90 90 c mo.ex.select %id %name
    mo.hit $+(w,%id) %ix %iy 90 90 d mo.ex.openitem %id %name
    inc %i
  }
  var %st = %n $iif(%n == 1,item,items)
  if (%sel != $null) { %st = %st $+ $chr(32) $+ $chr(160) $+ $chr(183) $+ $chr(160) 1 selected }
  if (%scr > 0) { %st = %st $+ $chr(32) $+ $chr(160) $+ $chr(183) $+ $chr(160) scrolled %scr }
  mo.statusbar %x $calc( %y + %h - 24) %w %st
}

; breadcrumbs: This PC > Users > Guest, each one clickable
; $1=id $2=x $3=y $4=max width $5-=path
alias mo.ex.crumbs {
  var %path = $5-
  var %parts = $remove(%path,C:\)
  var %x = $2
  var %end = $calc( $2 + $4)
  var %acc = C:\
  var %i = 0
  var %n = $numtok(%parts,92)
  while (%i <= %n) {
    var %lbl = $iif(%i == 0,This PC,$gettok(%parts,%i,92))
    if (%i > 0) {
      %acc = %acc $+ $gettok(%parts,%i,92) $+ \
      if (%acc == C:\Recycled\) { %lbl = Recycle Bin }
      mo.glyphc $mo_c(text2) 7 %x $3 14 28 59244
      inc %x 16
    }
    var %tw = $width(%lbl,Segoe UI,9)
    if ($calc( %x + %tw) > %end) { break }
    var %act = mo.ex.go $1 %acc
    if (%mohov == %act) && (%i < %n) { drawrect -rfdn @MSLOS $mo_c(hover) 1 $calc( %x - 4) $calc( $3 + 3) $calc( %tw + 8) 22 4 4 }
    mo.text $iif(%i == %n,$mo_c(text),$mo_c(text2)) ui 9 %x $3 28 %lbl
    if (%i < %n) { mo.hit $+(w,$1) $calc( %x - 4) $3 $calc( %tw + 8) 28 c %act }
    inc %x $calc( %tw + 6)
    inc %i
  }
}

; $1=id $2-=folder
alias mo.ex.go {
  hadd mst $+(x,$1,.path) $mo_fs_dir($2-)
  hdel mst $+(x,$1,.sel)
  hdel mst $+(x,$1,.scr)
  mo.wm.title $1 $mo_ex_title($mo_fs_dir($2-))
  mo.render
}

; toolbar button used by apps
; flat toolbar button used by apps: $1=winid $2=x $3=y $4=w $5=h
; $6=glyph codepoint (0 for none) $7=label (_ for spaces, - for none) $8-=action
; (mo.nop draws it disabled)
alias mo.tb.btn {
  var %act = $8-
  var %off = $iif(%act == mo.nop,1,0)
  var %fg = $mo_c(text)
  if (%off) { %fg = $mo_mix($mo_c(text2),$mo_c(surface2),0.5) }
  elseif (%mohov == %act) { drawrect -rfdn @MSLOS $mo_c(hover) 1 $2 $3 $4 $5 6 6 }
  var %lbl = $iif($7 == -,$null,$replace($7,_,$chr(32)))
  var %gw = $iif($6,16,0)
  var %tw = $iif(%lbl != $null,$width(%lbl,Segoe UI,9),0)
  var %gap = $iif(%gw && %tw,7,0)
  var %cx = $int( $calc( $2 + ( $4 - %gw - %gap - %tw ) / 2))
  if ($6) { mo.glyphc %fg 10 %cx $3 16 $5 $6 }
  if (%lbl != $null) { mo.text %fg ui 9 $calc( %cx + %gw + %gap) $3 $5 %lbl }
  if (!%off) { mo.hit $+(w,$1) $2 $3 $4 $5 c %act }
}

; a status bar: $1=x $2=y $3=w $4-=text
alias mo.statusbar {
  drawrect -rfn @MSLOS $mo_c(surface2) 1 $1 $2 $3 24
  drawline -rn @MSLOS $mo_c(border) 1 $1 $2 $calc( $1 + $3) $2
  mo.text $mo_c(text2) ui 8 $calc( $1 + 12) $2 24 $4-
}

; the toolbar band under a title bar: $1=x $2=y $3=w
alias mo.toolbar {
  drawrect -rfn @MSLOS $mo_c(surface2) 1 $1 $2 $3 44
  drawline -rn @MSLOS $mo_c(border) 1 $1 $calc( $2 + 44) $calc( $1 + $3) $calc( $2 + 44)
}

; items are passed by name ($2-): the view is sorted, the stored list is not
alias mo.ex.select {
  hadd mst $+(x,$1,.sel) $2-
  mo.render
}

alias mo.ex.openitem {
  var %id = $1
  var %path = $hget(mst,$+(x,%id,.path))
  var %name = $2-
  if (%name == $null) { return }
  if ($mo_fs_isdir($+(%path,%name))) {
    var %to = $mo_fs_dir($+(%path,%name))
    hadd mst $+(x,%id,.path) %to
    hdel mst $+(x,%id,.sel)
    hdel mst $+(x,%id,.scr)
    mo.wm.title %id $mo_ex_title(%to)
    mo.render
    return
  }
  mo.fs.openfile $+(%path,%name)
}

alias mo.ex.up {
  var %id = $1
  var %path = $hget(mst,$+(x,%id,.path))
  if (%path == C:\) { return }
  var %up = $mo_fs_parent(%path)
  hadd mst $+(x,%id,.path) %up
  hdel mst $+(x,%id,.sel)
  hdel mst $+(x,%id,.scr)
  mo.wm.title %id $mo_ex_title(%up)
  mo.render
}

alias mo.ex.newf {
  var %id = $1
  var %path = $hget(mst,$+(x,%id,.path))
  var %n = $input(New folder name:,e,,New Folder,New Folder)
  if (%n == $null) { return }
  %n = $mo_fs_clean(%n)
  if (%n == $null) { return }
  var %target = $+(%path,%n)
  if ($mo_fs_isdir(%target) || $mo_fs_isfile(%target)) { %n = $mo_fs_unique(%path,%n,folder) }
  mo.fs.mkdir $+(%path,%n)
  mo.save
  mo.render
}

alias mo.ex.del {
  var %id = $1
  var %path = $hget(mst,$+(x,%id,.path))
  var %sel = $hget(mst,$+(x,%id,.sel))
  if (%sel == $null) {
    noop $input(Select something first.,o,,Delete)
    return
  }
  mo.fs.delete %path $+ %sel
  hdel mst $+(x,%id,.sel)
  mo.render
}

alias mo.app.explorer.click { }
alias mo.app.explorer.dclick { }

alias mo.wm.title {
  hadd mwm $+(w,$1,.title) $2-
  if ($hget(mwm,$+(w,$1,.st)) != min) { mo.render }
}

; -------------------------------------------------------------- browser ----

alias mo.app.browser.open {
  var %id = $1
  hadd mst $+(x,%id,.url) home
  hadd mst $+(x,%id,.hist) home
  hadd mst $+(x,%id,.pos) 1
  if ($2- != $null) { mo.br.nav %id $2- }
}

alias mo.app.browser.close { }
alias mo.app.browser.click { }
alias mo.app.browser.dclick { }

; normalise whatever the user typed into a page id
alias mo_br_page {
  var %u = $lower($remove($1-,msl://,http://,https://))
  %u = $gettok(%u,1,32)
  if (%u == $null) || (%u == home) || (%u == portal) || (%u == start) { return home }
  if (%u == news) { return news }
  if (%u == docs) || (%u == help) || (%u == getting) || (%u == started) { return docs }
  if (%u == credits) || (%u == about) { return credits }
  if (%u == theme) || (%u == themes) { return theme }
  if (www.* iswm %u) || (*.* iswm %u) { return $1- }
  return news
}

alias mo.br.nav {
  var %id = $1
  var %page = $mo_br_page($2-)
  var %hist = $hget(mst,$+(x,%id,.hist))
  var %pos = $hget(mst,$+(x,%id,.pos))
  var %curlist = $gettok(%hist,1- $+ %pos,124)
  %curlist = $addtok(%curlist,%page,124)
  %hist = %curlist
  %pos = $numtok(%hist,124)
  hadd mst $+(x,%id,.hist) %hist
  hadd mst $+(x,%id,.pos) %pos
  hadd mst $+(x,%id,.url) %page
  mo.br.load %id %page
  mo.wm.title %id Web Browser - $iif($left(%page,4) == http,www,$iif(*.* iswm %page,%page,msl:// $+ %page))
  mo.render
}

alias mo.br.load {
  ; fetch external pages with $urlget, local pages are instant
  var %id = $1
  var %page = $2
  if ($hget(mcfg,$+(web.,%page)) != $null) { return }
  if (*.* !iswm %page) { return }
  hadd mst $+(x,%id,.load) 1
  if ($left(%page,4) != http) { %page = http:// $+ %page }
  %mowebwin = %id
  noop $urlget(%page,bei,&mo.web,mo.web.done)
}

alias mo.web.done {
  ; $1 = urlget job id; %mowebwin = browser window id
  var %id = %mowebwin
  unset %mowebwin
  if (%id == $null) { return }
  if ($urlget($1).state != ok) {
    if ($hget(mst,$+(x,%id,.load)) != $null) { hadd mst $+(x,%id,.load) 2 }
    mo.render
    return
  }
  var %raw = $bvar(&mo.web,1-).text
  var %url = $hget(mst,$+(x,%id,.url))
  var %title = %url
  if ($regex(mot,%raw,/<title[^>]*>([^<]{1,120})</i)) { %title = $regml(mot,1) }
  var %links
  var %ln = $regex(mol,%raw,/<a[^>]+href=["']?([^"'\s>]+)/i)
  var %i = 1
  while (%i <= %ln) && ($numtok(%links,124) < 24) {
    var %l = $regml(mol,%i)
    if (http* iswm %l) { %links = $addtok(%links,%l,124) }
    inc %i
  }
  var %o1
  var %o2
  var %o3
  var %o4
  noop $regsub(mo1,%raw,/(?s)<script.*?<\/script>/i,,%o1)
  noop $regsub(mo2,%o1,/(?s)<style.*?<\/style>/i,,%o2)
  noop $regsub(mo3,%o2,/<[^>]*>/,$chr(32),%o3)
  %o3 = $replace(%o3,&lt;,<,&gt;>,&quot;,",&apos;,',&nbsp;,$chr(32),&amp;,&)
  noop $regsub(mo4,%o3,/\n{3,}/,$lf $+ $lf,%o4)
  var %text = $left(%o4,9000)
  hadd mcfg $+(web.title.,%url) %title
  hadd mcfg $+(web.links.,%url) $iif(%links == $null,-,%links)
  hadd mcfg $+(web.,%url) $iif(%text == $null,-,%text)
  hdel mst $+(x,%id,.load)
  mo.render
}

alias mo.app.browser.draw {
  var %id = $1
  var %x = $2
  var %y = $3
  var %w = $4
  var %h = $5
  var %url = $hget(mst,$+(x,%id,.url))
  var %pos = $hget(mst,$+(x,%id,.pos))
  var %hist = $hget(mst,$+(x,%id,.hist))
  ; toolbar: back, forward, home, address
  mo.toolbar %x %y %w
  mo.tb.btn %id $calc( %x + 8) $calc( %y + 6) 32 32 59179 - $iif(%pos > 1,mo.br.back %id,mo.nop)
  mo.tb.btn %id $calc( %x + 42) $calc( %y + 6) 32 32 59178 - $iif(%pos < $numtok(%hist,124),mo.br.fwd %id,mo.nop)
  mo.tb.btn %id $calc( %x + 76) $calc( %y + 6) 32 32 59407 - mo.br.nav %id home
  var %disp = $iif(*.* iswm %url,%url,msl:// $+ %url)
  var %ax = $calc( %x + 118)
  var %aw = $calc( %w - 128)
  var %ahov = $iif(%mohov == mo.br.ask %id,1,0)
  drawrect -rfdn @MSLOS $iif(%ahov,$mo_c(hover),$mo_c(surface)) 1 %ax $calc( %y + 8) %aw 28 14 14
  drawrect -rdn @MSLOS $mo_c(border) 1 %ax $calc( %y + 8) %aw 28 14 14
  var %g = 59718
  if (https://* iswm %url) { %g = 59182 }
  elseif (*.* iswm %url) { %g = 59252 }
  mo.glyphc $mo_c(text2) 9 $calc( %ax + 6) $calc( %y + 8) 20 28 %g
  mo.text $mo_c(text) ui 9 $calc( %ax + 30) $calc( %y + 8) 28 $mo_clip(%disp,$calc( %aw - 44),9)
  mo.hit $+(w,%id) %ax $calc( %y + 8) %aw 28 c mo.br.ask %id
  ; content
  var %cx = %x
  var %cy = $calc( %y + 45)
  var %cw = %w
  var %ch = $calc( %h - 45 - 24)
  drawrect -rfn @MSLOS $rgb(255,255,255) 1 %cx %cy %cw %ch
  if (*.* iswm %url) {
    mo.page.web %id %url %cx %cy %cw %ch
  }
  elseif (%url == news) { mo.page.news %id %cx %cy %cw %ch }
  elseif (%url == docs) { mo.page.docs %id %cx %cy %cw %ch }
  elseif (%url == credits) { mo.page.credits %id %cx %cy %cw %ch }
  elseif (%url == theme) { mo.page.theme %id %cx %cy %cw %ch }
  else { mo.page.home %id %cx %cy %cw %ch }
  var %st = Done
  if ($hget(mst,$+(x,%id,.load)) == 1) { %st = Loading... }
  if ($hget(mst,$+(x,%id,.load)) == 2) { %st = Could not load the page (offline? blocked?) }
  mo.statusbar %x $calc( %y + %h - 24) %w %st
}

alias mo.nop { }

alias mo.br.back {
  var %id = $1
  var %pos = $hget(mst,$+(x,%id,.pos))
  if (%pos <= 1) { return }
  dec %pos
  hadd mst $+(x,%id,.pos) %pos
  var %url = $gettok($hget(mst,$+(x,%id,.hist)),%pos,124)
  hadd mst $+(x,%id,.url) %url
  mo.br.load %id %url
  mo.render
}

alias mo.br.fwd {
  var %id = $1
  var %pos = $hget(mst,$+(x,%id,.pos))
  var %hist = $hget(mst,$+(x,%id,.hist))
  if (%pos >= $numtok(%hist,124)) { return }
  inc %pos
  hadd mst $+(x,%id,.pos) %pos
  var %url = $gettok(%hist,%pos,124)
  hadd mst $+(x,%id,.url) %url
  mo.br.load %id %url
  mo.render
}

alias mo.br.ask {
  var %id = $1
  var %cur = $hget(mst,$+(x,%id,.url))
  if (!*.* iswm %cur) { %cur = msl:// $+ %cur }
  var %u = $input(Type an address - a msl:// page or a real http:// site:,e,,Go to address,%cur)
  if (%u == $null) { return }
  mo.br.nav %id %u
}

; a text link; returns y advanced past it
alias mo_page_link {
  hadd mcfg dbgt $4-
  ; $1=id $2=x $3=y $4=text $5-=page/url
  var %t = $4
  var %u = $5-
  var %hov = $iif(%mohov == mo.br.nav $1 %u,1,0)
  var %col = $mo_c(title)
  if (%hov) { %col = $rgb(196,74,62) }
  drawtext -orn @MSLOS %col "Segoe UI" 10 $2 $3 %t
  drawline -rn @MSLOS %col 1 $2 $calc( $3 + 15) $calc( $2 + $width(%t,Segoe UI,10)) $calc( $3 + 15)
  mo.hit $+(w,$1) $2 $3 $calc( $width(%t,Segoe UI,10) + 6) 16 c mo.br.nav $1 %u
  return $calc( $3 + 22)
}

alias mo_page_h { return $calc( $height(Xg,Segoe UI,10) + 6) }

alias mo.page.home {
  var %id = $1
  var %x = $2
  var %y = $3
  var %w = $4
  var %h = $5
  var %mx = $calc( %x + %w / 2)
  drawtext -orn @MSLOS $mo_c(title) "Segoe UI" 22 $calc( %mx - $width(MSL Portal,Segoe UI,22,b1) / 2) $calc( %y + 28) MSL Portal
  drawtext -rn @MSLOS $mo_c(text2) "Segoe UI" 10 $calc( %mx - $width(the tiny internet of a tiny operating system,Segoe UI,10) / 2) $calc( %y + 62) the tiny internet of a tiny operating system
  var %y2 = $calc( %y + 110)
  var %l1 = Read the MSL OS news
  %y2 = $mo_page_link(%id,$calc( %x + 40),%y2,%l1,news)
  var %l2 = Getting started guide
  %y2 = $mo_page_link(%id,$calc( %x + 40),%y2,%l2,docs)
  var %l3 = Credits and about
  %y2 = $mo_page_link(%id,$calc( %x + 40),%y2,%l3,credits)
  var %l4 = Desktop themes
  %y2 = $mo_page_link(%id,$calc( %x + 40),%y2,%l4,theme)
  var %l5 = Visit a real website (example.com)
  %y2 = $mo_page_link(%id,$calc( %x + 40),%y2,%l5,example.com)
  drawtext -rn @MSLOS $mo_c(text2) "Segoe UI" 9 $calc( %x + 40) $calc( %y + %h - 70) Real sites are fetched over http(s) and rendered as text.
  drawtext -rn @MSLOS $mo_c(text2) "Segoe UI" 9 $calc( %x + 40) $calc( %y + %h - 54) Click the address bar above and type any url.
}

alias mo.page.news {
  var %id = $1
  var %x = $2
  var %y = $3
  var %w = $4
  var %h = $5
  drawtext -orn @MSLOS $mo_c(title) "Segoe UI" 16 $calc( %x + 24) $calc( %y + 20) MSL OS News
  var %items = 2026: MSL OS 1.0 released to an audience of one|Local script achieves sentience, still cannot ssh|Window manager dragged into production|
  var %i = 1
  var %yy = $calc( %y + 56)
  while (%i <= $numtok(%items,124)) {
    var %it = $gettok(%items,%i,124)
    drawdot -rn @MSLOS $mo_c(accent) 6 $calc( %x + 28) $calc( %yy + 5)
    drawtext -orn @MSLOS $mo_c(menut) "Segoe UI" 11 $calc( %x + 40) %yy %it
    inc %yy 30
    inc %i
  }
  var %lbl = < back to portal
  var %y2 = $mo_page_link(%id,$calc( %x + 24),$calc( %yy + 10),%lbl,home)
  drawtext -rn @MSLOS $mo_c(text2) "Segoe UI" 9 $calc( %x + 24) $calc( %y + %h - 30) (no journalists were harmed)
}

alias mo.page.docs {
  var %id = $1
  var %x = $2
  var %y = $3
  var %w = $4
  var %h = $5
  drawtext -orn @MSLOS $mo_c(title) "Segoe UI" 16 $calc( %x + 24) $calc( %y + 20) Getting started
  var %t = Welcome to MSL OS, a desktop drawn entirely by a mIRC script. $lf $lf - Everything is one picture window: the taskbar, icons, menus and apps are /drawrect and /drawtext. $lf - Drag windows by the title bar. Use _ to minimise, [] to maximise, X to close. $lf - Right-click the desktop for New Folder and themes. $lf - Notepad, Paint and the file picker share the virtual C:\ disk, saved to mslos\fs.dat. $lf - The Terminal is a real network terminal: try telnet 127.0.0.1 2323 (run terminal-demo.mrc first), or connect to any raw TCP service. Type help there. $lf - The browser fetches real pages: click the address bar and type example.com.
  var %n = $wrap(%t,Segoe UI,10,$calc( %w - 48),p0,0)
  var %lh = $mo_page_h
  var %max = $int( $calc(( %h - 110 ) / %lh))
  if (%n > %max) { %n = %max }
  var %i = 1
  var %yy = $calc( %y + 52)
  while (%i <= %n) {
    drawtext -rn @MSLOS $mo_c(menut) "Segoe UI" 10 $calc( %x + 26) %yy $wrap(%t,Segoe UI,10,$calc( %w - 48),p0,%i)
    inc %yy %lh
    inc %i
  }
  var %lbl = < back to portal
  var %y2 = $mo_page_link(%id,$calc( %x + 24),$calc( %y + %h - 34),%lbl,home)
}

alias mo.page.credits {
  var %id = $1
  var %x = $2
  var %y = $3
  var %w = $4
  var %h = $5
  drawtext -orn @MSLOS $mo_c(title) "Segoe UI" 16 $calc( %x + 24) $calc( %y + 20) Credits
  drawtext -rn @MSLOS $mo_c(menut) "Segoe UI" 10 $calc( %x + 26) $calc( %y + 56) MSL OS 1.0
  drawtext -rn @MSLOS $mo_c(menut) "Segoe UI" 10 $calc( %x + 26) $calc( %y + 74) A desktop environment in a single mIRC script.
  drawtext -rn @MSLOS $mo_c(menut) "Segoe UI" 10 $calc( %x + 26) $calc( %y + 92) Runs on the mslrt runtime (github.com/ValwareIRC/msl-runtime).
  drawtext -rn @MSLOS $mo_c(menut) "Segoe UI" 10 $calc( %x + 26) $calc( %y + 110) Picture windows, dialogs, timers, sockets and hash tables.
  drawtext -rn @MSLOS $mo_c(menut) "Segoe UI" 10 $calc( %x + 26) $calc( %y + 128) No DLLs. No COM. 100% mSL.
  var %lbl = < back to portal
  var %y2 = $mo_page_link(%id,$calc( %x + 24),$calc( %y + %h - 34),%lbl,home)
}

alias mo.page.theme {
  var %id = $1
  var %x = $2
  var %y = $3
  var %w = $4
  var %h = $5
  drawtext -orn @MSLOS $mo_c(title) "Segoe UI" 16 $calc( %x + 24) $calc( %y + 20) Desktop themes
  drawtext -rn @MSLOS $mo_c(menut) "Segoe UI" 10 $calc( %x + 26) $calc( %y + 56) Four themes ship with MSL OS. Opening Settings switches them live.
  var %lbl = Open Settings
  var %y2 = $mo_page_link(%id,$calc( %x + 26),$calc( %y + 84),%lbl,mo.page.openset)
  drawtext -rn @MSLOS $mo_c(text2) "Segoe UI" 9 $calc( %x + 26) $calc( %y + 120) Current theme: $hget(mcfg,theme)
  var %lbl2 = < back to portal
  %y2 = $mo_page_link(%id,$calc( %x + 24),$calc( %y + %h - 34),%lbl2,home)
}

alias mo.page.openset { mo.set.open }

alias mo.page.web {
  ; render a fetched page: cached text + links
  var %id = $1
  var %url = $2
  var %x = $3
  var %y = $4
  var %w = $5
  var %h = $6
  var %title = $hget(mcfg,$+(web.title.,%url))
  var %text = $hget(mcfg,$+(web.,%url))
  if ($hget(mst,$+(x,%id,.load)) == 1) {
    drawtext -rn @MSLOS $mo_c(text2) "Segoe UI" 12 $calc( %x + %w / 2 - 40) $calc( %y + 40) Loading...
    return
  }
  if (%text == $null) {
    drawtext -rn @MSLOS $rgb(196,74,62) "Segoe UI" 16 $calc( %x + 24) $calc( %y + 24) Page could not be loaded
    drawtext -rn @MSLOS $mo_c(menut) "Segoe UI" 10 $calc( %x + 24) $calc( %y + 56) The runtime could not fetch %url
    drawtext -rn @MSLOS $mo_c(menut) "Segoe UI" 10 $calc( %x + 24) $calc( %y + 74) (network offline, blocked, or the site refused)
    var %lbl = < back
    var %y2 = $mo_page_link(%id,$calc( %x + 24),$calc( %y + 110),%lbl,home)
    return
  }
  drawtext -orn @MSLOS $mo_c(title) "Segoe UI" 14 $calc( %x + 24) $calc( %y + 18) $mo_clip(%title,$calc( %w - 48),14)
  drawline -rn @MSLOS $mo_c(menub) 1 $calc( %x + 24) $calc( %y + 44) $calc( %x + %w - 24) $calc( %y + 44)
  var %lh = $mo_page_h
  var %links = $hget(mcfg,$+(web.links.,%url))
  var %nl = $numtok(%links,124)
  var %linkh = $iif(%nl > 0,$calc( 34 + %nl * 20),0)
  var %max = $int( $calc(( %h - 84 - %linkh ) / %lh))
  if (%max < 3) { %max = 3 }
  var %n = $wrap(%text,Segoe UI,10,$calc( %w - 48),p0,0)
  if (%n > %max) { %n = %max }
  var %i = 1
  var %yy = $calc( %y + 54)
  while (%i <= %n) {
    drawtext -rn @MSLOS $mo_c(menut) "Segoe UI" 10 $calc( %x + 26) %yy $wrap(%text,Segoe UI,10,$calc( %w - 48),p0,%i)
    inc %yy %lh
    inc %i
  }
  if (%nl > 0) {
    var %yy2 = $calc( %y + %h - %linkh - 10)
    drawtext -rn @MSLOS $mo_c(text2) "Segoe UI" 9 $calc( %x + 24) %yy2 Links on this page
    inc %yy2 18
    var %i = 1
    while (%i <= %nl) {
      var %l = $gettok(%links,%i,124)
      var %lt = $mo_clip(%l,$calc( %w - 80),10)
      var %y3 = $mo_page_link(%id,$calc( %x + 26),%yy2,%lt,%l)
      %yy2 = %y3
      inc %i
    }
  }
}

; ---------------------------------------------------------------- paint ----

alias mo_paint_cols { return $rgb(20,20,20) $rgb(230,60,50) $rgb(240,140,40) $rgb(240,210,60) $rgb(90,180,70) $rgb(60,170,160) $rgb(70,110,200) $rgb(140,90,200) $rgb(180,110,70) $rgb(150,150,150) $rgb(240,150,180) $rgb(255,255,255) }

alias mo.app.paint.open {
  var %id = $1
  hadd mst $+(x,%id,.col) $rgb(70,110,200)
  hadd mst $+(x,%id,.data) -
  if ($2- != $null) && ($mo_fs_isfile($2-)) {
    hadd mst $+(x,%id,.data) $replace($mo_fs_read($2-),$crlf,$chr(1))
    hadd mst $+(x,%id,.file) $2-
    mo.wm.title %id Paint - $mo_fs_base($2-)
  }
}

alias mo.app.paint.close { }

alias mo.app.paint.click { }
alias mo.app.paint.dclick { }

alias mo.app.paint.draw {
  var %id = $1
  var %x = $2
  var %y = $3
  var %w = $4
  var %h = $5
  ; toolbar: clear, save, colours
  mo.toolbar %x %y %w
  mo.tb.btn %id $calc( %x + 8) $calc( %y + 6) 78 32 59153 Clear mo.paint.clear %id
  mo.tb.btn %id $calc( %x + 90) $calc( %y + 6) 74 32 59214 Save mo.paint.save %id
  drawline -rn @MSLOS $mo_c(border) 1 $calc( %x + 174) $calc( %y + 12) $calc( %x + 174) $calc( %y + 32)
  var %i = 1
  var %sx = $calc( %x + 188)
  while (%i <= 12) {
    var %c = $gettok($mo_paint_cols,%i,32)
    if ($hget(mst,$+(x,%id,.col)) == %c) {
      drawrect -refn @MSLOS $mo_c(accent) 1 $calc( %sx - 4) $calc( %y + 7) 30 30
      drawrect -refn @MSLOS $mo_c(surface2) 1 $calc( %sx - 2) $calc( %y + 9) 26 26
    }
    drawrect -refn @MSLOS %c 1 %sx $calc( %y + 11) 22 22
    drawrect -ren @MSLOS $mo_mix(%c,0,0.18) 1 %sx $calc( %y + 11) 22 22
    mo.hit $+(w,%id) %sx $calc( %y + 11) 22 22 c mo.paint.setcol %id %i
    inc %sx 30
    inc %i
  }
  ; canvas
  var %cx = %x
  var %cy = $calc( %y + 45)
  var %cw = %w
  var %ch = $calc( %h - 45)
  drawrect -rfn @MSLOS $rgb(255,255,255) 1 %cx %cy %cw %ch
  hadd mst $+(x,%id,.ox) %cx
  hadd mst $+(x,%id,.oy) %cy
  hadd mst $+(x,%id,.cw) %cw
  hadd mst $+(x,%id,.ch) %ch
  ; replay strokes
  var %data = $hget(mst,$+(x,%id,.data))
  if (%data != $null) && (%data != -) {
    var %i = 1
    var %n = $numtok(%data,1)
    while (%i <= %n) {
      var %s = $gettok(%data,%i,1)
      if ($numtok(%s,32) == 5) {
        drawline -rn @MSLOS $gettok(%s,5,32) 2 $calc( %cx + $gettok(%s,1,32)) $calc( %cy + $gettok(%s,2,32)) $calc( %cx + $gettok(%s,3,32)) $calc( %cy + $gettok(%s,4,32))
      }
      inc %i
    }
  }
}

alias mo.paint.setcol {
  hadd mst $+(x,$1,.col) $gettok($mo_paint_cols,$2,32)
  mo.render
}

alias mo.paint.clear {
  hadd mst $+(x,$1,.data) -
  mo.render
}

alias mo.paint.save {
  var %id = $1
  var %def = untitled.paint
  if ($hget(mst,$+(x,%id,.file))) { %def = $mo_fs_base($hget(mst,$+(x,%id,.file))) }
  mo.pick.open save C:\Users\Guest\Pictures\ %def mo.paint.saved %id
}

alias mo.paint.saved {
  var %path = $hget(mcfg,pickresult)
  if (%path == $null) { return }
  var %id = $hget(mcfg,pickwin)
  mo.fs.write $+(",%path,") $replace($hget(mst,$+(x,%id,.data)),$chr(1),$lf)
  hadd mst $+(x,%id,.file) %path
  mo.wm.title %id Paint - $mo_fs_base(%path)
  mo.save
  mo.render
}

alias mo.app.paint.drag {
  ; $1=id $2=abs x $3=abs y
  var %id = $1
  var %ax = $2
  var %ay = $3
  var %ox = $hget(mst,$+(x,%id,.ox))
  var %oy = $hget(mst,$+(x,%id,.oy))
  var %cw = $hget(mst,$+(x,%id,.cw))
  var %ch = $hget(mst,$+(x,%id,.ch))
  var %x = $mo_max(0,$mo_min($calc( %ax - %ox),%cw))
  var %y = $mo_max(0,$mo_min($calc( %ay - %oy),%ch))
  var %col = $hget(mst,$+(x,%id,.col))
  var %data = $hget(mst,$+(x,%id,.data))
  if ($hget(mst,$+(x,%id,.lx)) == $null) {
    hadd mst $+(x,%id,.lx) %x
    hadd mst $+(x,%id,.ly) %y
    return
  }
  var %lx = $hget(mst,$+(x,%id,.lx))
  var %ly = $hget(mst,$+(x,%id,.ly))
  if (%lx == %x) && (%ly == %y) { return }
  if (%data == $null) || (%data == -) { %data = $null }
  hadd mst $+(x,%id,.data) %data $+ $chr(1) $+ %lx %ly %x %y %col
  drawline -rn @MSLOS %col 2 $calc( %ox + %lx) $calc( %oy + %ly) $calc( %ox + %x) $calc( %oy + %y)
  drawdot @MSLOS
  hadd mst $+(x,%id,.lx) %x
  hadd mst $+(x,%id,.ly) %y
}

alias mo.paint.end {
  hdel mst $+(x,$1,.lx)
  hdel mst $+(x,$1,.ly)
}

; -------------------------------------------------------------- viewer ----

alias mo.app.viewer.open {
  var %id = $1
  var %p = $iif($2- != $null,$2-,C:\Users\Guest\Pictures\Sunset.bmp)
  if (!$mo_fs_isfile(%p)) { %p = C:\Users\Guest\Pictures\Sunset.bmp }
  hadd mst $+(x,%id,.path) %p
  mo.wm.title %id $mo_fs_base(%p)
}

alias mo.app.viewer.close { }
alias mo.app.viewer.click { }
alias mo.app.viewer.dclick { }

alias mo.app.viewer.draw {
  var %id = $1
  var %x = $2
  var %y = $3
  var %w = $4
  var %h = $5
  var %p = $hget(mst,$+(x,%id,.path))
  var %seed = $mo_mod($hash($mo_fs_base(%p),8),6)
  var %ih = $calc( %h - 24)
  var %iw = $calc( %w - 2)
  var %skies = 70 130 190|140 90 160|40 150 150|180 120 60|90 90 160|60 130 60
  var %sky = $gettok(%skies,$calc( %seed + 1),124)
  var %r = $gettok(%sky,1,32)
  var %g = $gettok(%sky,2,32)
  var %b = $gettok(%sky,3,32)
  var %bands = $mo_min($int( $calc( %ih / 14)),30)
  var %i = 0
  while (%i < %bands) {
    var %t = %i / %bands
    var %bh = $calc( $int( $calc( %ih / %bands)) + 1)
    var %cr = $int( $calc( %r - 40 + 60 * %t))
    var %cg = $int( $calc( %g - 40 + 80 * %t))
    var %cb = $int( $calc( %b - 30 + 70 * %t))
    drawrect -rfn @MSLOS $rgb(%cr,%cg,%cb) 1 $calc( %x + 1) $calc( %y + 1 + %i * %bh) %iw %bh
    inc %i
  }
  drawrect -refn @MSLOS $rgb(250,214,110) 1 $calc( %x + %iw / 2 - 26) $calc( %y + %ih / 4) 52 52
  var %hy = $calc( %y + %ih - 60)
  drawline -rn @MSLOS $rgb(30,60,44) 40 $calc( %x + 4) $calc( %hy + 40) $calc( %x + %iw * 0.4) %hy
  drawline -rn @MSLOS $rgb(24,48,36) 40 $calc( %x + %iw * 0.35) $calc( %hy + 40) $calc( %x + %iw * 0.75) $calc( %hy - 8)
  drawline -rn @MSLOS $rgb(36,66,50) 40 $calc( %x + %iw * 0.7) $calc( %hy + 40) $calc( %x + %iw - 4) $calc( %hy + 12)
  mo.statusbar %x $calc( %y + %h - 24) %w $mo_fs_base(%p) $chr(160) $+ $chr(183) $+ $chr(160) generative art, seed %seed
}

; ------------------------------------------------------------- welcome ----

alias mo.app.welcome.open { }
alias mo.app.welcome.close { }
alias mo.app.welcome.click { }
alias mo.app.welcome.dclick { }

alias mo.app.welcome.draw {
  var %id = $1
  var %x = $2
  var %y = $3
  var %w = $4
  var %h = $5
  ; header: an accent gradient with the logo
  var %a1 = $mo_c(accent)
  var %a2 = $mo_mix($mo_c(accent2),$mo_c(glow2),0.35)
  var %i = 0
  while (%i < 96) {
    drawline -rn @MSLOS $mo_mix(%a1,%a2,$calc( %i / 95)) 1 %x $calc( %y + %i) $calc( %x + %w - 1) $calc( %y + %i)
    inc %i
  }
  var %lx = $calc( %x + 28)
  var %ly = $calc( %y + 30)
  drawrect -rfdn @MSLOS $rgb(255,255,255) 1 %lx %ly 15 15 5 5
  drawrect -rfdn @MSLOS $rgb(255,255,255) 1 $calc( %lx + 18) %ly 15 15 5 5
  drawrect -rfdn @MSLOS $mo_mix(%a1,$rgb(255,255,255),0.65) 1 %lx $calc( %ly + 18) 15 15 5 5
  drawrect -rfdn @MSLOS $mo_mix(%a1,$rgb(255,255,255),0.65) 1 $calc( %lx + 18) $calc( %ly + 18) 15 15 5 5
  drawtext -rn @MSLOS $rgb(255,255,255) "Segoe UI Light" 20 $calc( %x + 76) $calc( %y + 20) MSL OS
  drawtext -rn @MSLOS $mo_mix(%a1,$rgb(255,255,255),0.8) "Segoe UI" 9 $calc( %x + 78) $calc( %y + 56) version 1.0 $chr(183) an operating system in a picture window
  var %t = Everything here - the taskbar, this window, the icons, the menus - is drawn by one mIRC script running on mslrt. Double-click desktop icons, drag windows, right-click the desktop, and have a look inside the Terminal and the Web Browser.
  var %n = $wrap(%t,Segoe UI,10,$calc( %w - 56),p0,0)
  var %lh = $mo_page_h
  var %max = $int( $calc(( %h - 170 ) / %lh))
  if (%n > %max) { %n = %max }
  var %i = 1
  var %yy = $calc( %y + 114)
  while (%i <= %n) {
    drawtext -rn @MSLOS $mo_c(text) "Segoe UI" 10 $calc( %x + 28) %yy $wrap(%t,Segoe UI,10,$calc( %w - 56),p0,%i)
    inc %yy %lh
    inc %i
  }
  var %bw = $int( $calc(( %w - 56 - 16 ) / 3))
  var %by = $calc( %y + %h - 56)
  mo.wel.btn %id $calc( %x + 28) %by %bw 34 primary Get_started mo.launch browser docs
  mo.wel.btn %id $calc( %x + 36 + %bw) %by %bw 34 secondary My_files mo.launch explorer C:\
  mo.wel.btn %id $calc( %x + 44 + %bw * 2) %by %bw 34 secondary Terminal mo.launch term
}

alias mo.wel.btn {
  ; $1=id $2=x $3=y $4=w $5=h $6=primary|secondary $7=label (_ for spaces) $8-=action
  var %hov = $iif(%mohov == $8-,1,0)
  var %lbl = $replace($7,_,$chr(32))
  if ($6 == primary) {
    drawrect -rfdn @MSLOS $iif(%hov,$mo_mix($mo_c(accent),0,0.12),$mo_c(accent)) 1 $2 $3 $4 $5 6 6
    var %fg = $rgb(255,255,255)
  }
  else {
    drawrect -rfdn @MSLOS $iif(%hov,$mo_c(hover),$mo_c(surface)) 1 $2 $3 $4 $5 6 6
    drawrect -rdn @MSLOS $mo_c(border) 1 $2 $3 $4 $5 6 6
    var %fg = $mo_c(text)
  }
  mo.text %fg semi 9 $int( $calc( $2 + ( $4 - $width(%lbl,Segoe UI Semibold,9) ) / 2)) $3 $5 %lbl
  mo.hit $+(w,$1) $2 $3 $4 $5 c $8-
}

; ============================================================================
;                                DIALOGS
; ============================================================================

; ---------------------------------------------------------- file picker ----

dialog mo_pick {
  title "Open"
  size -1 -1 220 178
  option dbu
  text "", 1, 4 6 212 10
  list 2, 4 18 212 116, size
  text "Name:", 3, 4 140 22 8
  edit "", 4, 26 138 132 11, autohs
  button "Up", 6, 4 154 30 13
  button "New Folder", 7, 38 154 46 13
  button "Cancel", 8, 120 154 42 13, cancel
  button "OK", 9, 166 154 50 13, default ok
}

; mo.pick.open mode dir default callback [winid]
alias mo.pick.open {
  if ($dialog(mo_pick)) { dialog -v mo_pick | return }
  hadd mcfg pickmode $1
  hadd mcfg pickdir $2
  hadd mcfg pickcb $4
  hdel mcfg pickresult
  if ($5) { hadd mcfg pickwin $5 }
  dialog -m mo_pick mo_pick
  if ($1 == open) { dialog -t mo_pick Open }
  else { dialog -t mo_pick Save As }
  did -ra mo_pick 4 $3
  if ($1 == open) { did -h mo_pick 7 }
  mo.pick.fill
}

alias mo.pick.fill {
  if (!$dialog(mo_pick)) { return }
  did -ra mo_pick 1 $hget(mcfg,pickdir)
  did -r mo_pick 2
  var %dir = $hget(mcfg,pickdir)
  var %list = $mo_fs_list(%dir)
  var %folders
  var %files
  var %i = 1
  while (%i <= $numtok(%list,124)) {
    var %n = $gettok(%list,%i,124)
    if ($mo_fs_isdir($+(%dir,%n))) { %folders = $addtok(%folders,%n,124) }
    else { %files = $addtok(%files,%n,124) }
    inc %i
  }
  var %i = 1
  while (%i <= $numtok($sorttok(%folders,124),124)) {
    did -a mo_pick 2 $chr(9654) $gettok($sorttok(%folders,124),%i,124)
    inc %i
  }
  var %i = 1
  while (%i <= $numtok($sorttok(%files,124),124)) {
    did -a mo_pick 2 $gettok($sorttok(%files,124),%i,124)
    inc %i
  }
}

on *:DIALOG:mo_pick:init:0: {
  did -f mo_pick 4
}

on *:DIALOG:mo_pick:sclick:2: {
  var %sel = $did(mo_pick,2).seltext
  if (%sel == $null) { return }
  if ($chr(9654) isin %sel) {
    did -ra mo_pick 4 $remove(%sel,$chr(9654) $+ $chr(32))
  }
  else {
    did -ra mo_pick 4 %sel
  }
}

on *:DIALOG:mo_pick:dclick:2: {
  var %sel = $did(mo_pick,2).seltext
  if (%sel == $null) { return }
  var %dir = $hget(mcfg,pickdir)
  if ($chr(9654) isin %sel) {
    var %name = $remove(%sel,$chr(9654) $+ $chr(32))
    hadd mcfg pickdir $+(%dir,%name)
    mo.pick.fill
    return
  }
  hadd mcfg pickresult $+(%dir,%sel)
  mo.pick.done
}

on *:DIALOG:mo_pick:sclick:6: {
  var %up = $mo_fs_parent($hget(mcfg,pickdir))
  hadd mcfg pickdir %up
  mo.pick.fill
}

on *:DIALOG:mo_pick:sclick:7: {
  var %n = $input(New folder name:,e,,New Folder,New Folder)
  if (%n == $null) { return }
  %n = $mo_fs_clean(%n)
  if (%n == $null) { return }
  var %dir = $hget(mcfg,pickdir)
  if ($mo_fs_isdir($+(%dir,%n)) || $mo_fs_isfile($+(%dir,%n))) { %n = $mo_fs_unique(%dir,%n,folder) }
  mo.fs.mkdir $+(%dir,%n)
  mo.save
  mo.pick.fill
}

on *:DIALOG:mo_pick:sclick:9: {
  var %dir = $hget(mcfg,pickdir)
  var %name = $did(mo_pick,4)
  if ($hget(mcfg,pickmode) == open) {
    if (%name == $null) || (!$mo_fs_isfile($+(%dir,%name))) { return }
    hadd mcfg pickresult $+(%dir,%name)
  }
  else {
    %name = $mo_fs_clean(%name)
    if (%name == $null) { return }
    if ($mo_fs_isfile($+(%dir,%name))) {
      if ($input(%name already exists. Overwrite?,y,,Save As) != $true) { return }
    }
    hadd mcfg pickresult $+(%dir,%name)
  }
  mo.pick.done
}

alias mo.pick.done {
  var %cb = $hget(mcfg,pickcb)
  dialog -x mo_pick
  if (%cb) {
    var %c = %cb
    %c
  }
}

; -------------------------------------------------------------- notepad ----

dialog mo_np {
  title "Notepad"
  size -1 -1 300 200
  option dbu
  menu "&File", 10
  item "&New", 11
  item "&Open...", 12
  item "&Save", 13
  item "Save &As...", 14
  item "break", 19
  item "E&xit", 15
  menu "&Help", 20
  item "&About Notepad", 21
  edit "", 1, 0 0 300 200, multi return vsbar hsbar
}

alias mo.np.open {
  if (!$dialog(mo_np)) { dialog -m mo_np mo_np }
  dialog -v mo_np
}

alias mo.np.openfile {
  if (!$dialog(mo_np)) { dialog -m mo_np mo_np }
  hadd mcfg npfile $1-
  hdel mcfg npdirty
  dialog -t mo_np Notepad - $mo_fs_base($1-)
  did -ra mo_np 1 $mo_fs_read($1-)
}

alias mo.np.title {
  var %t = Notepad
  if ($hget(mcfg,npfile)) { %t = %t - $mo_fs_base($hget(mcfg,npfile)) }
  if ($hget(mcfg,npdirty)) { %t = %t $chr(42) }
  dialog -t mo_np %t
}

on *:DIALOG:mo_np:init:0: {
  mo.np.title
}

on *:DIALOG:mo_np:edit:1: {
  if ($hget(mcfg,npdirty) != 1) {
    hadd mcfg npdirty 1
    mo.np.title
  }
}

alias mo.np.save {
  if (!$dialog(mo_np)) { return }
  var %f = $hget(mcfg,npfile)
  if (%f == $null) { mo.np.saveas | return }
  mo.fs.write $+(",%f,") $did(mo_np,1)
  hdel mcfg npdirty
  mo.np.title
  mo.save
}

alias mo.np.saveas {
  var %def = Untitled.txt
  if ($hget(mcfg,npfile)) { %def = $mo_fs_base($hget(mcfg,npfile)) }
  mo.pick.open save C:\Users\Guest\Documents\ %def mo.np.picked
}

alias mo.np.picked {
  var %path = $hget(mcfg,pickresult)
  if (%path == $null) { return }
  hadd mcfg npfile %path
  mo.fs.write $+(",%path,") $did(mo_np,1)
  hdel mcfg npdirty
  mo.np.title
  mo.save
}

on *:DIALOG:mo_np:menu:11: {
  if ($hget(mcfg,npdirty)) {
    if ($input(Save changes first?,y,,Notepad) == $true) { mo.np.save }
  }
  hdel mcfg npfile
  hdel mcfg npdirty
  did -r mo_np 1
  mo.np.title
}

on *:DIALOG:mo_np:menu:12: {
  if ($hget(mcfg,npdirty)) {
    if ($input(Save changes first?,y,,Notepad) == $true) { mo.np.save }
  }
  mo.pick.open open C:\Users\Guest\Documents\ Readme.txt mo.np.opened
}

alias mo.np.opened {
  var %path = $hget(mcfg,pickresult)
  if (%path == $null) { return }
  mo.np.openfile %path
}

on *:DIALOG:mo_np:menu:13: { mo.np.save }
on *:DIALOG:mo_np:menu:14: { mo.np.saveas }
on *:DIALOG:mo_np:menu:15: { dialog -x mo_np }
on *:DIALOG:mo_np:menu:21: {
  noop $input(MSL Notepad 1.0 $+ $crlf $+ Files live on the virtual C:\ disk.,o,,About Notepad)
}
on *:DIALOG:mo_np:close:0: {
  if ($hget(mcfg,npdirty)) {
    if ($input(Save changes before closing?,y,,Notepad) == $true) { mo.np.save }
  }
  hdel mcfg npdirty
}

; ------------------------------------------------------------- settings ----

dialog mo_set {
  title "MSL OS Settings"
  size -1 -1 214 162
  option dbu
  tab "Appearance", 1, 2 2 210 130
  box "Theme", 2, 8 14 194 68, tab 1
  radio "Classic Teal", 3, 16 26 90 10, tab 1 group
  radio "Midnight", 4, 16 40 90 10, tab 1
  radio "Terracotta", 5, 16 54 90 10, tab 1
  radio "Moss", 6, 16 68 90 10, tab 1
  check "24-hour clock", 7, 112 26 84 10, tab 1
  check "Show seconds", 8, 112 44 84 10, tab 1
  text "Changes apply instantly and are saved.", 9, 112 84 88 20, tab 1
  tab "System", 12, 2 2 210 130
  edit "", 13, 8 16 198 84, read multi vsbar, tab 12
  button "Reset MSL OS", 14, 8 104 60 14, tab 12
  button "Close", 15, 80 136 54 14, cancel
}

alias mo.set.open {
  if (!$dialog(mo_set)) { dialog -m mo_set mo_set }
  dialog -v mo_set
}

on *:DIALOG:mo_set:init:0: {
  var %th = $hget(mcfg,theme)
  if (%th == teal) { did -c mo_set 3 }
  if (%th == midnight) { did -c mo_set 4 }
  if (%th == terracotta) { did -c mo_set 5 }
  if (%th == moss) { did -c mo_set 6 }
  if ($hget(mcfg,clk24) == 1) { did -c mo_set 7 }
  if ($hget(mcfg,clksec) == 1) { did -c mo_set 8 }
  var %files 0
  var %dirs 0
  var %i = 1
  while ($hget(mfs,%i).item != $null) {
    if (F|* iswm $ifmatch) { inc %files }
    if (D|* iswm $ifmatch) { inc %dirs }
    inc %i
  }
  var %up = $duration($calc( $ctime - $hget(mcfg,boot)))
  did -a mo_set 13 MSL OS 1.0
  did -a mo_set 13 mSL picture-window desktop
  did -a mo_set 13 Virtual disk: %files files, %dirs folders
  did -a mo_set 13 Uptime: %up
  did -a mo_set 13 Reset wipes the virtual disk and settings (mslos\*.dat).
}

on *:DIALOG:mo_set:sclick:3: { mo.set.theme teal }
on *:DIALOG:mo_set:sclick:4: { mo.set.theme midnight }
on *:DIALOG:mo_set:sclick:5: { mo.set.theme terracotta }
on *:DIALOG:mo_set:sclick:6: { mo.set.theme moss }

alias mo.set.theme {
  hadd mcfg theme $1
  mo.save
  mo.render
}

on *:DIALOG:mo_set:sclick:7: {
  hadd mcfg clk24 $iif($did(mo_set,7).state == 1,1,0)
  mo.save
  mo.render
}

on *:DIALOG:mo_set:sclick:8: {
  hadd mcfg clksec $iif($did(mo_set,8).state == 1,1,0)
  unset %moclk
  mo.save
  mo.render
}

on *:DIALOG:mo_set:sclick:14: {
  if ($input(This wipes the virtual disk and all settings. Continue?,y,,Reset MSL OS) != $true) { return }
  dialog -x mo_set
  remove mslos\fs.dat
  remove mslos\cfg.dat
  hfree mfs
  hfree mcfg
  hmake mfs 200
  hmake mcfg 100
  hadd mcfg theme teal
  hadd mcfg boot $ctime
  mo.theme.init
  mo.fs.init
  if ($window(@MSLWALL)) { window -c @MSLWALL }
  mo.render
  noop $input(MSL OS has been reset.,o,,Reset)
}

; ------------------------------------------------------------------ run ----

dialog mo_run {
  title "Run"
  size -1 -1 200 62
  option dbu
  text "Type the name of a program, folder or web address:", 1, 8 8 184 12
  edit "", 2, 8 24 184 12, autohs
  button "OK", 3, 96 42 44 14, default ok
  button "Cancel", 4, 144 42 44 14, cancel
}

alias mo.run.open {
  if (!$dialog(mo_run)) { dialog -m mo_run mo_run }
  dialog -v mo_run
  did -f mo_run 2
}

on *:DIALOG:mo_run:sclick:3: {
  var %t = $did(mo_run,2)
  dialog -x mo_run
  if (%t) { mo.run.exec %t }
}

alias mo.run.exec {
  var %t = $lower($1-)
  if (%t == $null) { return }
  if (%t == notepad) { mo.np.open | return }
  if (%t == paint) { mo.wm.open paint | return }
  if (%t == explorer) || (%t == files) || (%t == mycomputer) { mo.wm.open explorer | return }
  if (%t == browser) || (%t == web) { mo.wm.open browser | return }
  if (%t == terminal) || (%t == term) || (%t == cmd) { mo.term.open | return }
  if (%t == settings) || (%t == control) { mo.set.open | return }
  if (%t == about) || (%t == welcome) { mo.wm.open welcome | return }
  if (%t == viewer) { mo.wm.open viewer | return }
  if (%t == shutdown) || (%t == exit) { mo.quit | return }
  if ($mo_fs_isdir($1-)) { mo.wm.open explorer $1- | return }
  if ($mo_fs_isfile($1-)) { mo.fs.openfile $1- | return }
  if (http* iswm %t) || (www.* iswm %t) || (msl:* iswm %t) || (*.* iswm %t) {
    mo.wm.open browser $1-
    return
  }
  noop $input(Cannot find ' $+ $1- $+ '. Check the name and try again.,o,,Run)
}

; ============================================================================
;                        MSL TERMINAL (@MSLTERM)
;  a picture window with an editbox: a real network terminal.
;  telnet / connect / tls / ssh commands, ANSI colour, IAC negotiation,
;  scrollback with the mouse wheel.
; ============================================================================

alias mt_f { return Consolas }

alias mt_col {
  ; 0-15 ansi palette
  if ($1 == 0) { return $rgb(18,18,24) }
  if ($1 == 1) { return $rgb(205,72,62) }
  if ($1 == 2) { return $rgb(88,196,96) }
  if ($1 == 3) { return $rgb(220,208,130) }
  if ($1 == 4) { return $rgb(90,128,208) }
  if ($1 == 5) { return $rgb(190,100,200) }
  if ($1 == 6) { return $rgb(96,200,200) }
  if ($1 == 7) { return $rgb(196,198,202) }
  if ($1 == 8) { return $rgb(120,122,130) }
  if ($1 == 9) { return $rgb(255,116,106) }
  if ($1 == 10) { return $rgb(158,232,160) }
  if ($1 == 11) { return $rgb(255,250,180) }
  if ($1 == 12) { return $rgb(146,180,255) }
  if ($1 == 13) { return $rgb(232,150,255) }
  if ($1 == 14) { return $rgb(160,240,240) }
  return $rgb(255,255,255)
}

alias mo.term.open {
  if ($window(@MSLTERM)) { window -a @MSLTERM | return }
  var %tw = $window(-1).w
  var %th = $window(-1).h
  if (%tw < 2) { %tw = 1024 }
  if (%th < 2) { %th = 768 }
  dec %tw 220
  dec %th 220
  if (%tw < 700) { %tw = 700 }
  if (%th < 420) { %th = 420 }
  window -pek0 @MSLTERM -1 -1 %tw %th
  renwin @MSLTERM @MSLTERM MSL Terminal
  hadd mt mode off
  hadd mt echo 1
  hadd mt curcol 7
  hadd mt view 0
  mt.out MSL Terminal 1.0 - a network terminal written in mSL.
  mt.out Type help for the command list.
  mt.draw
}

alias mt.sys {
  ; muted local system line
  var %save = $hget(mt,curcol)
  hadd mt curcol 8
  mt.put * $1-
  hadd mt curcol %save
  mt.nl
}

alias mt.out {
  mt.put $1-
  mt.nl
}

; ---- screen model -------------------------------------------------------
; a line is stored as runs: <code><US><text> joined by $chr(1)
; code = fg 0-15, +16 when bold. current line is mt item "cur".

alias mt.pbapp {
  ; append one byte (by code) to pbuf. the $A $+ $chr() form silently
  ; produces nothing in this runtime, so build through $+() instead.
  var %c = $hget(mt,pbuf)
  if (%c == $null) { hadd mt pbuf $chr($1) }
  else { hadd mt pbuf $+(%c,$chr($1)) }
}

alias mt_curraw {
  ; the current line without its trailing sentinel
  var %c = $hget(mt,cur)
  if (%c == $null) { return $null }
  if ($right(%c,1) == $chr(2)) { return $mid(%c,1,$calc( $len(%c) - 1)) }
  return %c
}

alias mt_rtxt {
  ; a run's text without the trailing sentinel. $1 = run token
  var %t = $gettok($1,2-,31)
  if (%t == $null) { return $null }
  if ($right(%t,1) == $chr(2)) { return $mid(%t,1,$calc( $len(%t) - 1)) }
  return %t
}

alias mt.put {
  if ($1- == $null) { return }
  var %code = $hget(mt,curcol)
  if ($hget(mt,curbold) == 1) { %code = $calc( %code + 16) }
  var %cur = $mt_curraw
  if (%cur == $null) {
    hadd mt cur $+(%code,$chr(31),$1-,$chr(2))
    return
  }
  var %last = $gettok(%cur,-1,1)
  if ($gettok(%last,1,31) == %code) {
    hadd mt cur $+($puttok(%cur,$+(%code,$chr(31),$mt_rtxt(%last),$1-),-1,1),$chr(2))
  }
  else {
    hadd mt cur $+(%cur,$chr(1),%code,$chr(31),$1-,$chr(2))
  }
}

alias mt.putc {
  ; append one byte to the current line. takes the CHARACTER CODE, never the
  ; character itself - a space passed as a command argument would vanish.
  var %ch = $chr($1)
  var %code = $hget(mt,curcol)
  if ($hget(mt,curbold) == 1) { %code = $calc( %code + 16) }
  var %cur = $mt_curraw
  if (%cur == $null) {
    hadd mt cur $+(%code,$chr(31),%ch,$chr(2))
    return
  }
  var %last = $gettok(%cur,-1,1)
  if ($gettok(%last,1,31) == %code) {
    hadd mt cur $+($puttok(%cur,$+(%code,$chr(31),$mt_rtxt(%last),%ch),-1,1),$chr(2))
  }
  else {
    hadd mt cur $+(%cur,$chr(1),%code,$chr(31),%ch,$chr(2))
  }
}

alias mt.tab {
  ; a tab is four spaces, appended without going through arguments
  var %i = 1
  while (%i <= 4) {
    mt.putc 32
    inc %i
  }
}

alias mt.nl {
  var %n = $calc( $hget(mt,n) + 1)
  hadd mt n %n
  var %cur = $hget(mt,cur)
  if (%cur != $null) { hadd mt $+(l,%n) %cur }
  else { hadd mt $+(l,%n) $+(7,$chr(31),$chr(2)) }
  hadd mt cur $null
  if (%n > 500) { mt.trim }
}

alias mt.trim {
  var %n = $hget(mt,n)
  var %i = 1
  while (%i <= 150) {
    hdel mt $+(l,%i)
    inc %i
  }
  var %i = 151
  while (%i <= %n) {
    hadd mt $+(l,$calc( %i - 150)) $hget(mt,$+(l,%i))
    hdel mt $+(l,%i)
    inc %i
  }
  hadd mt n $calc( %n - 150)
}

alias mt.bs {
  var %cur = $mt_curraw
  if (%cur == $null) { return }
  var %last = $gettok(%cur,-1,1)
  var %code = $gettok(%last,1,31)
  var %txt = $mt_rtxt(%last)
  if ($len(%txt) <= 1) {
    var %rest = $gettok(%cur,1--2,1)
    if (%rest != $null) { hadd mt cur $+(%rest,$chr(2)) }
    else { hadd mt cur $null }
  }
  else {
    %txt = $mid(%txt,1,$calc( $len(%txt) - 1))
    hadd mt cur $+($puttok(%cur,$+(%code,$chr(31),%txt),-1,1),$chr(2))
  }
}

alias mt.cr {
  ; simple carriage return: clear the line being built
  hadd mt cur $null
}

alias mt.clear {
  var %i = 1
  while (%i <= $hget(mt,n)) {
    hdel mt $+(l,%i)
    inc %i
  }
  hadd mt n 0
  hadd mt cur $null
  hadd mt view 0
}

; ---- ansi / telnet parsing ----------------------------------------------

alias mt.sgr {
  ; $1 = ; separated params
  var %p = $1
  if (%p == $null) { %p = 0 }
  var %i = 1
  var %n = $numtok(%p,59)
  while (%i <= %n) {
    var %v = $gettok(%p,%i,59)
    if (%v == $null) || (%v == 0) { hadd mt curcol 7 | hadd mt curbold 0 }
    elseif (%v == 1) { hadd mt curbold 1 }
    elseif (%v == 2) || (%v == 22) { hadd mt curbold 0 }
    elseif (%v isnum 30-37) { hadd mt curcol $calc( %v - 30) }
    elseif (%v isnum 90-97) { hadd mt curcol $calc( %v - 90 + 8) }
    elseif (%v == 39) { hadd mt curcol 7 }
    inc %i
  }
}

alias mt.reply {
  ; $1- = prebuilt $chr() string, sent as single bytes
  if ($sock(mosterm)) { sockwrite -a mosterm $1- }
}

alias mt.parse {
  var %n = $bvar(&mt.acc,0)
  if (%n == 0) { return }
  var %i = 1
  var %used = 0
  var %st = $hget(mt,pstate)
  if (%st == $null) { %st = n }
  while (%i <= %n) {
    var %b = $bvar(&mt.acc,%i)
    if (%st == n) {
      if (%b == 27) { %st = e | hadd mt pbuf $null }
      elseif (%b == 255) && ($hget(mt,mode) != off) { %st = i }
      elseif (%b == 13) {
        ; CR: only clears the line when text follows (overwrite). CR+LF is
        ; just a line ending - LF below commits the line intact. A CR at the
        ; end of the chunk is kept for the next read.
        if (%i == %n) { %used = $calc( %i - 1) }
        elseif ($bvar(&mt.acc,$calc( %i + 1)) == 10) { %used = %i }
        else { mt.cr | %used = %i }
      }
      elseif (%b == 10) { mt.nl | %used = %i }
      elseif (%b == 8) { mt.bs | %used = %i }
      elseif (%b == 9) { mt.tab | %used = %i }
      elseif (%b == 7) { %used = %i }
      elseif (%b >= 32) { mt.putc %b | %used = %i }
      else { %used = %i }
    }
    elseif (%st == e) {
      if (%b == 91) { %st = c | hadd mt pbuf $null | %used = %i }
      elseif (%b == 93) { %st = o | hadd mt pbuf $null | %used = %i }
      else { %st = n | %used = %i }
    }
    elseif (%st == c) {
      if (%b isnum 64-126) {
        var %p = $hget(mt,pbuf)
        if (%b == 109) { mt.sgr %p }
        elseif (%b == 74) { mt.clear }
        elseif (%b == 75) { hadd mt cur $null }
        %st = n
        %used = %i
      }
      elseif (%b == 27) { %st = e | hadd mt pbuf $null | %used = $calc( %i - 1) }
      else {
        if ($len($hget(mt,pbuf)) < 40) { mt.pbapp %b }
        %used = %i
      }
    }
    elseif (%st == o) {
      if (%b == 7) {
        if ($hget(mt,pbuf) != $null) { renwin @MSLTERM @MSLTERM MSL Terminal - $hget(mt,pbuf) }
        %st = n
        %used = %i
      }
      elseif (%b == 27) { %st = oe | %used = %i }
      else {
        if ($len($hget(mt,pbuf)) < 100) { mt.pbapp %b }
        %used = %i
      }
    }
    elseif (%st == oe) { %st = n | %used = %i }
    elseif (%st == i) {
      if (%b == 255) { mt.putc 255 | %st = n | %used = %i }
      elseif (%b isnum 251-254) { %st = i2 | hadd mt pbuf %b | %used = %i }
      elseif (%b == 250) { %st = s | hadd mt pbuf $null | %used = %i }
      else { %st = n | %used = %i }
    }
    elseif (%st == i2) {
      var %cmd = $hget(mt,pbuf)
      var %opt = %b
      if (%cmd == 251) {
        if (%opt == 1) {
          hadd mt echo 0
          mt.reply $+($chr(255),$chr(253),$chr(1))
        }
        else { mt.reply $+($chr(255),$chr(254),$chr(%opt)) }
      }
      elseif (%cmd == 253) {
        if (%opt == 3) { mt.reply $+($chr(255),$chr(251),$chr(3)) }
        elseif (%opt == 24) { mt.reply $+($chr(255),$chr(251),$chr(24)) }
        else { mt.reply $+($chr(255),$chr(252),$chr(%opt)) }
      }
      %st = n
      %used = %i
    }
    elseif (%st == s) {
      if (%b == 255) { %st = s2 | %used = %i }
      else {
        if ($len($hget(mt,pbuf)) < 60) { mt.pbapp %b }
        %used = %i
      }
    }
    elseif (%st == s2) {
      if (%b == 240) {
        var %sb = $hget(mt,pbuf)
        if ($len(%sb) > 0) && ($asc($mid(%sb,1,1)) == 24) {
          mt.reply $+($chr(255),$chr(250),$chr(24),$chr(0),ANSI,$chr(255),$chr(240))
        }
        %st = n
        %used = %i
      }
      elseif (%b == 255) {
        if ($len($hget(mt,pbuf)) < 60) { mt.pbapp 255 }
        %st = s
        %used = %i
      }
      else { %st = s | %used = %i }
    }
    inc %i
  }
  hadd mt pstate %st
  ; drop the processed prefix; keep any tail (pending CR / re-parsed ESC).
  ; /btrunc only truncates files in this runtime, so rebuild via bcopy -c.
  if (%used >= %n) { bunset &mt.acc }
  elseif (%used > 0) { bcopy -c &mt.acc 1 &mt.acc $calc( %used + 1) $calc( %n - %used) }
}

; ---- rendering -----------------------------------------------------------

alias mt.draw {
  if ($window(@MSLTERM) == $null) { return }
  var %W = $window(@MSLTERM).bw
  var %H = $window(@MSLTERM).bh
  if (%W < 2) { %W = 800 }
  if (%H < 2) { %H = 540 }
  drawrect -rfn @MSLTERM $rgb(12,12,16) 1 0 0 %W %H
  ; header strip
  drawrect -rfn @MSLTERM $rgb(24,26,34) 1 0 0 %W 26
  drawline -rn @MSLTERM $rgb(60,64,78) 1 0 26 %W 26
  var %where = offline
  if ($hget(mt,mode) != off) { %where = $hget(mt,mode) $+ : $hget(mt,host) $+ : $+ $hget(mt,port) }
  drawtext -orn @MSLTERM $rgb(230,232,238) "Segoe UI" 10 10 6 MSL Terminal
  drawtext -rn @MSLTERM $rgb(140,146,160) "Segoe UI" 9 110 7 %where
  var %st = connected
  if ($hget(mt,mode) == off) { %st = offline }
  if ($hget(mt,mode) == ssh) { %st = ssh probe }
  var %stc = $rgb(120,220,160)
  if (%st != connected) { %stc = $rgb(200,140,90) }
  drawtext -rn @MSLTERM %stc "Segoe UI" 9 $calc( %W - 10 - $width(%st,Segoe UI,9)) 7 %st
  ; body
  var %lh = $height(Xg,$mt_f,12)
  var %x0 = 10
  var %y1 = $calc( %H - 46)
  var %rows = $int( $calc(( %y1 - 36 ) / %lh))
  if (%rows < 1) { %rows = 1 }
  var %n = $hget(mt,n)
  var %view = $hget(mt,view)
  var %bottom = $calc( %n - %view)
  if (%bottom < 0) { %bottom = 0 }
  var %top = $calc( %bottom - %rows + 1)
  if (%top < 0) { %top = 0 }
  var %i = %top
  var %yy = $calc( %y1 - %rows * %lh)
  while (%i <= %bottom) {
    var %line = $hget(mt,$+(l,%i))
    if (%line != $null) {
      var %r = 1
      var %x = %x0
      var %rn = $numtok(%line,1)
      while (%r <= %rn) {
        var %run = $gettok(%line,%r,1)
        var %code = $gettok(%run,1,31)
        var %txt = $mt_rtxt(%run)
        if (%txt != $null) {
          var %col = $mt_col($mo_mod(%code,16))
          if (%code >= 16) { %col = $mt_col($calc( %code - 16 + 8)) }
          %x = $mo_spaced(@MSLTERM,%x,%yy,%col,$mt_f,12,%txt)
        }
        inc %r
      }
    }
    inc %yy %lh
    inc %i
  }
  ; the current (unfinished) line
  var %line = $hget(mt,cur)
  if (%line != $null) && (%bottom == %n) {
    var %r = 1
    var %x = %x0
    var %yy2 = $calc( %y1 - %lh)
    var %rn = $numtok(%line,1)
    while (%r <= %rn) {
      var %run = $gettok(%line,%r,1)
      var %code = $gettok(%run,1,31)
      var %txt = $mt_rtxt(%run)
      if (%txt != $null) {
        var %col = $mt_col($mo_mod(%code,16))
        if (%code >= 16) { %col = $mt_col($calc( %code - 16 + 8)) }
        %x = $mo_spaced(@MSLTERM,%x,%yy2,%col,$mt_f,12,%txt)
      }
      inc %r
    }
  }
  if (%view > 0) {
    drawrect -rfn @MSLTERM $rgb(60,64,78) 1 $calc( %W - 150) 30 140 20
    drawtext -rn @MSLTERM $rgb(230,232,238) "Segoe UI" 9 $calc( %W - 142) 33 scrolled up %view - wheel to move
  }
  drawdot @MSLTERM
}

alias mt.wheel {
  var %d = $1
  var %v = $hget(mt,view)
  if (%d > 0) { dec %v 3 }
  else { inc %v 3 }
  if (%v < 0) { %v = 0 }
  if (%v > $hget(mt,n)) { %v = $hget(mt,n) }
  hadd mt view %v
  mt.draw
}

; ---- input ---------------------------------------------------------------

on *:INPUT:@MSLTERM: {
  if ($1- == $null) { return }
  mo.term.line $1-
}

alias mo.term.line {
  var %t = $1-
  if ($hget(mt,mode) == off) {
    mt.cmd %t
    mt.draw
    return
  }
  if ($hget(mt,echo) == 1) {
    var %save = $hget(mt,curcol)
    hadd mt curcol 15
    mt.put %t
    hadd mt curcol %save
    mt.nl
  }
  if ($sock(mosterm)) { sockwrite -n mosterm %t }
  mt.draw
}

alias mt.cmd {
  tokenize 32 $1-
  if ($1 == $null) { return }
  if ($1 == help) {
    mt.out commands:
    mt.out telnet <host> [port] - telnet with IAC negotiation (default 23)
    mt.out connect <host> [port] - raw tcp connection
    mt.out tls <host> [port] - encrypted tcp (default 443)
    mt.out ssh <host> [port] - ssh banner probe (ssh cannot go further in mSL)
    mt.out sshbridge <host> [port] - use bridge\sshterm.exe if you built it
    mt.out echo on|off - local echo (handled automatically for telnet)
    mt.out title <text> - set the window title
    mt.out clear - clear the screen
    mt.out close - disconnect
    mt.out ver / date / uptime - about MSL OS
    mt.out tip: run terminal-demo.mrc with mslrt, then: telnet 127.0.0.1 2323
    return
  }
  if ($1 == ver) {
    mt.out MSL Terminal 1.0 (mSL edition) - part of MSL OS
    return
  }
  if ($1 == date) {
    mt.out $asctime($ctime,dddd dd mmmm yyyy HH:nn:ss)
    return
  }
  if ($1 == uptime) {
    mt.out up $duration($calc( $ctime - $hget(mcfg,boot)))
    return
  }
  if ($1 == clear) || ($1 == cls) { mt.clear | return }
  if ($1 == echo) {
    if ($2 == on) { hadd mt echo 1 | mt.out local echo on }
    elseif ($2 == off) { hadd mt echo 0 | mt.out local echo off }
    else { mt.out echo is $iif($hget(mt,echo) == 1,on,off) }
    return
  }
  if ($1 == title) {
    renwin @MSLTERM @MSLTERM MSL Terminal - $2-
    return
  }
  if ($1 == close) || ($1 == disconnect) {
    mt.disconnect
    mt.out disconnected.
    return
  }
  if ($1 == telnet) || ($1 == connect) || ($1 == tls) || ($1 == ssh) {
    mt.connect $1 $2 $iif($3,$3,$iif($1 == telnet,23,$iif($1 == tls,443,$iif($1 == ssh,22,23))))
    return
  }
  if ($1 == sshbridge) {
    mt.bridge $2 $3
    return
  }
  mt.out ' $+ $1 $+ ' is not a command. type help.
}

alias mt.disconnect {
  if ($sock(mosterm)) { sockclose mosterm }
  hadd mt mode off
  hadd mt echo 1
  bunset &mt.acc
  hdel mt tail
  hadd mt pstate n
}

alias mt.connect {
  ; $1 = mode, $2 = host, $3 = port
  if ($2 == $null) {
    mt.out usage: $1 <host> [port]
    return
  }
  mt.disconnect
  hadd mt host $2
  hadd mt port $3
  hadd mt mode $1
  hadd mt sshdone 0
  mt.sys connecting to $2 $+ : $+ $3 ($1 $+ ) ...
  sockopen $iif($1 == tls,-e) mosterm $2 $3
  mt.draw
}

alias mt.bridge {
  ; $1 = host, $2 = ssh port. uses bridge\sshterm.exe if present
  if ($1 == $null) {
    mt.out usage: sshbridge <host> [port]
    return
  }
  if (!$findfile(bridge,sshterm.exe,1)) {
    mt.out bridge\sshterm.exe not found.
    mt.out build it:  cd bridge  then  go build
    mt.out then reconnect with: sshbridge <host>
    return
  }
  mt.disconnect
  mt.sys starting ssh bridge on 127.0.0.1:2223 ...
  run bridge\sshterm.exe $1 $iif($2 isnum,$2,22) 2223
  .timermt.bridge -m 1 900 mt.bridge.go
}

alias mt.bridge.go {
  mt.connect telnet 127.0.0.1 2223
}

; ---- socket events --------------------------------------------------------

on *:SOCKOPEN:mosterm: {
  if ($sockerr > 0) {
    mt.sys could not connect ($sock(mosterm).wsmsg [ $+ $sock(mosterm).wserr $+ ] $+ ).
    hadd mt mode off
    mt.draw
    return
  }
  mt.sys connected to $hget(mt,host) $+ : $+ $hget(mt,port)
  if ($hget(mt,mode) == ssh) {
    sockwrite -a mosterm SSH-2.0-MSLTerminal_1.0 $+ $crlf
  }
  mt.draw
}

on *:SOCKREAD:mosterm: {
  if ($sockerr > 0) { return }
  ; mslrt clears every &binvar when a script run ends, so the unparsed tail
  ; is carried between events in the "tail" item of the mt hash table.
  bunset &mt.acc
  if ($hget(mt,tail,&mt.tail)) {
    var %tl = $bvar(&mt.tail,0)
    if (%tl > 0) { bcopy -c &mt.acc 1 &mt.tail 1 %tl }
  }
  var %got = 1
  while (%got) {
    sockread -f &mt.r
    if ($sockbr == 0) { %got = 0 }
    else {
      var %base = $calc( $bvar(&mt.acc,0) + 1)
      bcopy &mt.acc %base &mt.r 1 $sockbr
    }
  }
  if ($bvar(&mt.acc,0) > 0) {
    if ($hget(mt,mode) == ssh) && (!$hget(mt,sshdone)) { mt.sshbanner }
    else { mt.parse }
  }
  var %left = $bvar(&mt.acc,0)
  if (%left > 0) { hadd -b mt tail &mt.acc }
  else { hdel mt tail }
  mt.draw
}

on *:SOCKCLOSE:mosterm: {
  mt.sys connection closed by remote host.
  hadd mt mode off
  hadd mt echo 1
  mt.draw
}

alias mt.sshbanner {
  ; show the remote ssh identification, then explain and close
  var %n = $bvar(&mt.acc,0)
  var %i = 1
  var %line = $null
  var %found = 0
  while (%i <= %n) {
    var %b = $bvar(&mt.acc,%i)
    if (%b == 10) || (%b == 13) { %found = 1 | break }
    %line = %line $+ $chr(%b)
    inc %i
  }
  if (!%found) && (%n < 255) { return }
  hadd mt sshdone 1
  var %save = $hget(mt,curcol)
  hadd mt curcol 10
  mt.put %line
  hadd mt curcol %save
  mt.nl
  mt.out
  mt.out that is as far as ssh goes in pure mSL:
  mt.out ssh-2 needs aes/ctr ciphers and diffie-hellman key exchange with
  mt.out big-integer math; mSL has neither (its $encode only offers
  mt.out blowfish). telnet, connect and tls all work for real services.
  mt.out
  mt.out if you have bridge\sshterm.exe built, run: sshbridge <host>
  mt.disconnect
  mt.draw
}

; probe: does renwin cause the collapse? two windows, one with, one without
on *:START: {
  window -p @Q1 -1 -1 1904 1020
  drawrect -f @Q1 $rgb(40,90,160) 1 0 0 1904 1020
  drawtext -o @Q1 $rgb(255,255,255) "Segoe UI" 40 40 40 NO-RENWIN 1904x1020
  window -p @Q2 -1 -1 1904 1020
  drawrect -f @Q2 $rgb(40,160,90) 1 0 0 1904 1020
  renwin @Q2 @Q2 WITH-RENWIN
  .timerprobeexit 1 30 exit
}

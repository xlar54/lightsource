10 rem renderer65 picture viewer (basic 65): shows the 640x200x256 iff pictures
20 rem the renderer saves. tokenised by petcat -w65; on the disk as viewer.
30 bank 128
40 scnclr:print "renderer65 picture viewer":print
50 dir "*.iff"
60 print:print "type a picture's name and press return (a key goes back),"
70 print "or just press return to stop."
80 f$="":input "picture";f$
90 if f$="" then end
100 if right$(f$,4)<>".iff" then f$=f$+".iff"
110 trap 200
120 screen 640,200,8
130 loadiff (f$)
140 getkey k$
150 screen close
160 trap:goto 40
200 screen close:trap
210 print:print "couldn't show ";f$;": ";err$(er):sleep 3
220 resume 40

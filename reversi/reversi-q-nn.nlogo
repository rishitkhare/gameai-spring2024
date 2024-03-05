extensions [ csv py ]
globals [ current-player winner-data gameplay-data next-piece white-wins black-wins x-output y-output ticks-since-last-filewrite ]
breed [ pieces piece ]
breed [ guesses guess ]

pieces-own [ next-color ]
patches-own [ q reward ]

to-report c2h [ c ]
  report 90 * c
end

to-report h2c [ h ]
  report h / 90
end

to-report d2t [ d ]
  if d = 0 [ report [] ]
  report lput (remainder d 3) (d2t int (d / 3))
end

to-report t2d [ t ]
  if empty? t [ report 0 ]
  report (first t * 3 ^ (length t - 1)) + t2d but-first t
end


to-report update-patch-q-dir [ patch-cardinal ] ;; patch
  let learning-rate 0.8
  let discount-factor 0.2
  let patch-direction c2h patch-cardinal

  let old-next-patch-q (item patch-cardinal q)
  let learned-factor (1 - learning-rate) * old-next-patch-q

  let next-patch patch-at-heading-and-distance patch-direction 1
  if nobody = next-patch [ report 0 ]
  let next-patch-reward [reward] of next-patch

  let next-patch-max-q [max q] of next-patch

  let next-q learned-factor + learning-rate * ( next-patch-reward + ( discount-factor * next-patch-max-q ) )
  report int next-q
end

to-report other-color [ piece-color ]
  if piece-color = white [ report black ]
  if piece-color = black [ report white ]
  report green
end


to init-piece [ piece-color ]
  set shape "circle"
  set size 0.5
  set color piece-color
  set next-color color
end

to init-patches
  ask patches [
    ifelse (pxcor + pycor) mod 2 = 0 [ set pcolor green - 2 ] [ set pcolor white - 2 ]
    if not is-list? q [ set q [0 0] ]
  ]
  let middle-patch-xy (list int (world-width / 2)  (int (world-width / 2) - 1))
  ask patches with [ member? pxcor middle-patch-xy and member? pycor middle-patch-xy ]
    [
      sprout-pieces 1 [ init-piece (ifelse-value (pxcor + pycor) mod 2 = 0 [ white ] [ black ]) ]
  ]
end

to-report legal-line [ piece-color dlx dly ] ;; patch
  let next-patch (patch-at dlx dly)
  if next-patch = nobody [ report false ]
  if [not any? pieces-here] of next-patch [ report piece-color = [color] of one-of pieces-here ]
  ifelse ([[color] of one-of pieces-here] of next-patch = piece-color)
            [ report true ]
            [ report [legal-line piece-color dlx dly] of next-patch ]
end


to-report legal-move [ piece-color ] ;; patch
  if any? pieces-here [ report false ]
  let candidate-neighbors neighbors with [any? pieces-here and [color] of one-of pieces-here != piece-color]
  if not any? candidate-neighbors [ report false ]
  foreach [self] of candidate-neighbors [ next-patch ->
    let dlx ([pxcor] of next-patch - pxcor)
    let dly ([pycor] of next-patch - pycor)
    if ((dlx != 0 or dly != 0) and [legal-line piece-color dlx dly] of next-patch) [
      report true
    ]
  ]
  report false
end

to reset-board
  ask pieces [ die ]
  set current-player white
  init-patches
end

to setup-python
  py:setup py:python
  py:run "import tensorflow as tf"
  py:run "import numpy as np"
  py:run "model = tf.keras.models.load_model('othello-discounted.keras')"
  py:run "print(model.summary())"
end

to-report turn-to-pyrow [ row ]
  report (word "np.array([[" csv:to-string (list row) "]])")
end

to-report random-row
  report turn-to-pyrow (n-values 64 [x -> precision random-float 1.0 2])
end

to setup
  ca
  set white-wins 0
  set black-wins 0
  set next-piece nobody
  set-default-shape guesses "target"
  setup-python
  set gameplay-data []
  set winner-data []
  reset-ticks
  reset-board
end

to flip-line [ piece-color dlx dly ]
  ask pieces-here [ set next-color piece-color ]
  let next-patch (patch-at dlx dly)
  if next-patch != nobody [
    if [any? pieces-here] of next-patch [
      if ([[color] of one-of pieces-here] of next-patch != piece-color)
      [
        ask next-patch [flip-line piece-color dlx dly]
      ]
    ]
  ]
end

to flip-lines [ piece-color ] ;; patch
  let candidate-neighbors neighbors with [any? pieces-here and [color] of one-of pieces-here != piece-color]
  foreach [self] of candidate-neighbors [ next-patch ->
    let dlx ([pxcor] of next-patch - pxcor)
    let dly ([pycor] of next-patch - pycor)
    if (dlx != 0 or dly != 0) [
      if (legal-line piece-color dlx dly) [
        flip-line piece-color dlx dly
      ]
    ]
  ]
end

to execute-flip
  ask pieces [ set color next-color ]
  set next-piece nobody
end

to no-flip
  ask pieces [ set next-color color ]
  if nobody != next-piece [ ask next-piece [ die ] ]
  set next-piece nobody
end

to play-piece ;; patch
  no-flip
  sprout-pieces 1 [
    init-piece current-player
    set next-piece self
  ]
  flip-lines current-player
  execute-flip
end

to opponent-move
  let legal-move-patches patches with [ legal-move current-player ]
  if any? legal-move-patches [
    ask one-of legal-move-patches [ play-piece ]
  ]
end

to nn-evaluate-legal-move ;; patch
end

to player-move
  let legal-move-patches patches with [ legal-move current-player ]
  if any? legal-move-patches [
    ifelse smart-move? [
      test-move
      ask max-one-of legal-move-patches [ [size] of one-of guesses-here ] [
        play-piece
        sprout-guesses 1 [ set shape "x" set color green set size 0.5 ]
      ]
    ]
    [
      ask one-of legal-move-patches [ play-piece ]
    ]
  ]
end

to test-move
  ask guesses [ die ]
  let legal-move-patches patches with [ legal-move current-player ]
  ask legal-move-patches [
    no-flip
    sprout-pieces 1 [
      init-piece current-player
      set next-piece self
    ]
    flip-lines current-player
    sprout-guesses 1 [
      let future eval-future-board
      let my-chance ifelse-value (current-player = white) [ first future ] [ first butfirst future ]
      set size 0.1 + (0.5 * my-chance)
      set heading 45 fd 0.3
      set color scale-color red my-chance -3 4
    ]
  ]
  ;; 1 is white
  no-flip
end

to-report game-over?
  let legal-move-patches patches with [ legal-move current-player or legal-move other-color current-player]
  report not any? legal-move-patches
end

to-report current-winner
  let black-pieces count pieces with [ color = black ]
  let white-pieces count pieces with [ color = white ]
  if black-pieces < white-pieces [ report black ]
  report white
end

to data-to-file
  let x-filename "x.csv"
  let y-filename "y.csv"
  csv:to-file x-filename x-output
  csv:to-file y-filename y-output
  print (word "outputting data X len = " length x-output " ; Y len = " length y-output)
end


to write-to-play-data
  let winner int one-of modes last gameplay-data
  let num-rows (length gameplay-data - length winner-data)
  let y-data reverse n-values num-rows [ i -> (abs (winner - i * 0.5 / num-rows))  ]
  set winner-data map [ x -> (list (precision (1 - x) 3) (precision x 3)) ] y-data
;  set winner-data sentence winner-data y-data ;(n-values num-rows [(list winner)])

  if not is-list? x-output [ set x-output [] set y-output [] ]
  set x-output sentence x-output gameplay-data
  set y-output sentence y-output winner-data
  set gameplay-data []
  set winner-data []
end

to-report patch-id ;; patch
  report pxcor + world-width * pycor
end

to-report future-patch-color-data
  if any? pieces-here [
    let c [next-color] of one-of pieces-here
    if c = black [ report 0.0 ]
    if c = white [ report 1.0 ]
  ]
  report 0.5
end

to-report patch-color-data
  if any? pieces-here [
    let c [color] of one-of pieces-here
    if c = black [ report 0.0 ]
    if c = white [ report 1.0 ]
  ]
  report 0.5
end

to-report future-board-as-row
  report (map [x -> [future-patch-color-data] of x] sort-on [patch-id] patches)
end

to-report board-as-row
  report (map [x -> [patch-color-data] of x] sort-on [patch-id] patches)
end

to-report eval-board
  report (map [n -> precision n 3] first py:runresult (word "tf.nn.softmax(model(" turn-to-pyrow board-as-row ")).numpy()"))
end

to-report eval-future-board
  report (map [n -> precision n 3] first py:runresult (word "tf.nn.softmax(model(" turn-to-pyrow future-board-as-row ")).numpy()"))
end

to add-play-data
  set gameplay-data lput board-as-row gameplay-data
end

to go
  tick
  set ticks-since-last-filewrite ticks-since-last-filewrite + 1
  ask guesses [ die ]
  if game-over? [
    if logging? [
      write-to-play-data
      if ticks-since-last-filewrite > 10000 [
        data-to-file
        set ticks-since-last-filewrite 0
      ]
    ]

    ifelse current-winner = black [
      set black-wins black-wins + 1
    ] [
      set white-wins white-wins + 1
    ]
    reset-board
  ]
  ifelse (current-player = black) [ opponent-move ] [ player-move ]
  if logging? [ add-play-data ]
  set current-player other-color current-player
end
@#$#@#$#@
GRAPHICS-WINDOW
10
10
418
419
-1
-1
50.0
1
10
1
1
1
0
0
0
1
0
7
0
7
0
0
1
ticks
30.0

BUTTON
425
10
545
75
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
425
80
545
130
NIL
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
425
135
545
180
go on
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SWITCH
425
190
532
223
logging?
logging?
1
1
-1000

BUTTON
425
230
517
263
NIL
test-move
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

MONITOR
425
270
502
315
NIL
black-wins
0
1
11

MONITOR
505
270
582
315
NIL
white-wins
0
1
11

PLOT
10
425
415
575
wins
NIL
NIL
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"white wins" 1.0 0 -7500403 true "" "plot white-wins"
"black wins" 1.0 0 -16777216 true "" "plot black-wins"

SWITCH
535
190
672
223
smart-move?
smart-move?
0
1
-1000

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
1
@#$#@#$#@

extensions [ csv py table ]
globals [ num-players message-patch pot-patch deck ranks suits current-bet names game-complete? data ]

breed [ players player ]
breed [ cards card ]
breed [ chips chip ]

cards-own [ suit rank owner opp-can-see? player-can-see? ]
players-own [ name bet bet? folded? called? raised? my-data ]
chips-own [ owner in-round? ]

;;; PYTHON

to setup-python
  py:setup py:python
  (py:run
    "import tensorflow as tf"
    "import numpy as np"
    "import json"
    "from mycode import *"
  )
;  py:run "model = tf.keras.models.load_model('othello-discounted.keras')"
;  py:run "print(model.summary())"
end


to-report second [multi-item-list]
  report first butfirst multi-item-list
end

to-report third [multi-item-list]
  report item 2 multi-item-list
end


to-report flatten [a-list]
  if not is-list? a-list [ report (list a-list) ]
  if empty? a-list [ report [] ]
  if not is-list? first a-list [ report fput (first a-list) flatten (butfirst a-list) ]
  if empty? first a-list [ report flatten butfirst a-list ]
  report se (flatten first first a-list) (se (flatten butfirst first a-list) (flatten butfirst a-list))
end

to-report has-card? [ card-name hand-of-cards ]
  report member? card-name [first rank] of hand-of-cards
end

to-report max-card-of [ some-cards ]
  report (50 - max flatten [second rank] of some-cards)
end

to-report is-flush? [ hand-of-cards ]
  report 1 = length remove-duplicates [ suit ] of hand-of-cards
end

to-report is-straight? [ hand-of-cards ]
  let sr sort flatten [second rank] of hand-of-cards
  let num-cards length sr

  let seq-diff (map - (sublist sr 0 (num-cards - 1)) (sublist sr 1 num-cards))

  if has-card? "ace" hand-of-cards [
    if (item 0 seq-diff = -1) [ set seq-diff sublist seq-diff 0 (length seq-diff - 1) ]
    if (last seq-diff = -1) [ set seq-diff sublist seq-diff 1 length seq-diff ]
  ]

  set seq-diff remove-duplicates seq-diff
  report (length seq-diff = 1 and first seq-diff = -1)
end

to-report is-straight-flush? [ hand-of-cards ]
  report is-flush? hand-of-cards and is-straight? hand-of-cards
end

to-report is-royal-flush? [ hand-of-cards ]
  let card-names [first rank] of hand-of-cards
  report is-straight-flush? hand-of-cards and has-card? "ace" hand-of-cards and has-card? "king" hand-of-cards
end

to-report is-three-of-a-kind? [ hand-of-cards ]
  let card-names [first rank] of hand-of-cards
  report member? 3 map second list-counter card-names
end

to-report max-three-of-a-kind [ hand-of-cards ]
  report max flatten filter [ x -> second x = 3 ] list-counter [rank] of hand-of-cards
end

to-report is-four-of-a-kind? [ hand-of-cards ]
  let card-names [first rank] of hand-of-cards
  report member? 4 map second list-counter card-names
end

to-report max-four-of-a-kind [ hand-of-cards ]
  report max flatten filter [ x -> second x = 4 ] list-counter [rank] of hand-of-cards
end

to-report is-two-pair? [ hand-of-cards ]
  let card-names [first rank] of hand-of-cards
  report member? 2 (map second list-counter (map second list-counter card-names))
end

to-report max-pair [ hand-of-cards ]
  report max flatten filter [ x -> second x = 2 ] list-counter [rank] of hand-of-cards
end

to-report is-pair? [ hand-of-cards ]
  let card-names [first rank] of hand-of-cards
  report member? 2 map second list-counter card-names
end

to-report is-full-house? [ hand-of-cards ]
  report is-pair? hand-of-cards and is-three-of-a-kind? hand-of-cards
end

to-report list-counter [ a-list ]
  let output (list (list first a-list 0))
  foreach a-list [ a ->
    let index position a (map first output)
    ifelse false != index [
      set output replace-item index output (list (first item index output) (1 + second item index output))
    ] [
      set output lput (list a 1) output
    ]
  ]
  report output
end

to-report evaluate-full-hand [ hand-of-cards ] ; lower is better
  let max-card max-card-of hand-of-cards
  if is-royal-flush? hand-of-cards [ report (list "royal flush" 0 max-card ) ]
  if is-straight-flush? hand-of-cards [ report (list  "straight flush" 1 max-card ) ]
  if is-four-of-a-kind? hand-of-cards [ report (list  "4 of a kind" 2 max-four-of-a-kind hand-of-cards ) ]
  if is-full-house? hand-of-cards [ report (list  "full house" 3 max-three-of-a-kind hand-of-cards ) ]
  if is-flush? hand-of-cards [ report (list  "flush" 4 max-card ) ]
  if is-straight? hand-of-cards [ report (list  "straight" 5 max-card ) ]
  if is-three-of-a-kind? hand-of-cards [ report (list  "3 of a kind" 6 max-three-of-a-kind hand-of-cards ) ]
  if is-two-pair? hand-of-cards [ report (list  "two pair" 7 max-pair hand-of-cards ) ]
  if is-pair? hand-of-cards [ report (list  "one pair" 8 max-pair hand-of-cards ) ]
  report (list "high card" max-card max-card)
end

to-report evaluate-my-full-hand ;; player
  report evaluate-full-hand cards with [ owner = myself ]
end

to-report evaluate-partial-hand [ hand-of-cards ]
  ;; TODO you write this!
  report 99
end

to create-deck-of-cards
  set suits [ "heart" "club" "diamond" "spade" ]
  set ranks sentence (n-values 9 [ i -> (list (word (i + 2)) (list (i + 2)))])
                     [["jack" [11]] ["queen" [12]] ["king" [13]] ["ace" [1 14]]]
  foreach suits [ s ->
    foreach ranks [ r ->
      create-cards 1 [
        set suit s
        set rank r
        set size 1
        set opp-can-see? true
        flip-card
        set player-can-see? false
        set shape (word "card" s)
        set label (word "\t\t" (first r))
        rt random 360 fd random 100
        set owner nobody
        hide-turtle
      ]
    ]
  ]
end

to flip-card ;; card
  ifelse opp-can-see? ;; flip it down
  [
    set label-color grey
    set color grey
  ]
  [ ;; flip it up
    set label-color black
    set color white
    set player-can-see? true
  ]
  set opp-can-see? not opp-can-see?
end

to-report cards-visible-to-me ;; player
  report cards with [ not hidden? and
    ((owner = myself and player-can-see?)
      or opp-can-see?)]
end

to-report cards-not-visible-to-me
  report cards with [not member? self cards-visible-to-me]
end


to flip-random-card-up ;; player
  ask one-of cards with [ owner = myself and not opp-can-see? and not player-can-see? ] [
    flip-card
  ]
end


to reset-game
  set game-complete? false
  ask cards [ die ]
  ask patches [ set plabel "" set pcolor white ]
  create-deck-of-cards
  reset-round
  ask players [
    set folded? false
    set label name
    let counter 0
    ask n-of 5 cards with [ owner = nobody ] [
      set owner myself
      show-turtle
      move-to myself
      set heading (270 / 5) * counter
      fd 2
      set counter counter + 1
    ]
    ask one-of cards with [ owner = myself ]
    [
      set player-can-see? true
      set pcolor grey + 3.5
    ]
  ]
  ask chips [ set in-round? false ]
  log-full-state "RESET"
end

to init-player
  set num-players 3
  set folded? false
  set label-color black
  set name item (who mod num-players) names
  move-to pot-patch
  set heading (who mod num-players) * (360 / num-players)
  set color item (2 + who mod num-players) base-colors
  fd max-pxcor - 4
  hatch-chips 20 [
    set size 0.2
    set color blue
    rt random 360 fd random-float 0.2
    set owner myself
    set in-round? false
  ]
end

to setup-logging
  set data []
end



to export-log
  file-open "poker.jsonl"
  foreach data [ row -> file-print (word row) ]
  set data []
  file-close
end

to reset-players
  ask players [ die ]
  ask chips [ die ]
  set names shuffle [ "alice" "bob" "charlie" "danny" "elissa" ]
  create-players num-players [  init-player  ]
end

to setup
  ca
  set num-players 3
  reset-ticks
  setup-python
  setup-logging
  ask patches [ set pcolor white set plabel-color black ]
  set message-patch patch 0 min-pycor
  set pot-patch patch 0 1
  set-default-shape players "circle"
  set-default-shape cards "cardback"
  set-default-shape chips "wheel"
  reset-players
  reset-game
end

to chip-bet ;; chip
  set in-round? true
  set heading towards pot-patch
  fd 1
  ask owner [ set bet bet + 1 ]
end

to bet-start
  let my-chips chips with [ owner = myself ]
  ask n-of random (count my-chips / 8) my-chips [ chip-bet ] ;; todo
  set bet? true
;  print (word name " bets: " bet)
end

to bet-call
  set called? true
  let pot-call max [bet] of players with [ not folded? and any? chips with [in-round?] ]
  if pot-call != bet [
    let my-max-bet count chips with [ owner = myself ]
    ifelse pot-call > my-max-bet [ bet-fold ]
    [
      let my-already-bet count chips with [ owner = myself and in-round? ]
      ask n-of (pot-call - my-already-bet) chips with [owner = myself and not in-round?] [
        chip-bet
      ]
    ]
  ]
;  print (word name " calls: " bet)
end

to bet-fold
;  print (word name " folds")
  set folded? true
  set bet 0
  ask chips with [ in-round? and owner = myself ] [
    set owner pot-patch
    set in-round? false
  ]
  ask cards with [ owner = myself ] [
    set pcolor grey
    set player-can-see? true
  ]
end

to bet-raise [ amount ]
  set raised? true
  let pot-call max [bet] of players with [ not folded? and any? chips with [in-round?] ]
  let my-max-bet count chips with [ owner = myself ]
  if pot-call > my-max-bet [ bet-fold ]
  if pot-call = my-max-bet [ bet-call ]
  if pot-call < my-max-bet [
    let my-already-bet count chips with [ owner = myself and in-round? ]
    ifelse (amount + my-already-bet) <= my-max-bet [
      ask n-of amount chips with [owner = myself and not in-round?] [ ;; todo
        chip-bet
      ]
;      print (word name " raises: " bet)
    ] [
;      print (word name ": raised too much" )
      bet-call
    ]
  ]
end

to do-bet ;; player ;; TODO
  if not folded? [
    let my-chips chips with [ owner = myself ]
    let bettors players with [ not folded? and any? (chips with [in-round?]) ]
    ifelse any? bettors ;; betting has started
    [ ;; raise, call, fold
      let current-max-bet max [bet] of bettors
      ifelse (current-max-bet > count my-chips) [ bet-fold ] [
        ;; YOU PUT SOMETHING HERE
;        print visible-state self

        (py:run
          (word "raw_row = '" (list visible-state self) "'")
          "row = json.loads(raw_row)"
          "print('DATA TO PYTHON:', row)")
        let a-choice int py:runresult "get_best_choice(json.loads(raw_row))"
        print (word "python choice: " a-choice)
        if a-choice > 0 [ bet-raise a-choice ]
        if a-choice = 0 [ bet-call ]
        if a-choice < 0 [ bet-fold ]
      ]
    ] [ ;; betting
      bet-start
    ]
  ]
  log-full-state "BET"
end

to-report winning-player
  if not any? players [ report "NULL" ]
  report min-one-of players with [not folded?] [
    (1000 * second evaluate-my-full-hand - third evaluate-my-full-hand)
  ]
end


to complete-game
  ask players [ set label (word name ":\n" first evaluate-my-full-hand )]
  let winner winning-player
  log-full-state "WIN"
  ask winner [
    ask chips with [ owner = pot-patch ] [
      set owner winner
      move-to winner
      rt random 360 fd random-float 1
    ]
  ]

  ask chips [ set in-round? false ]
  ask message-patch [ set plabel (word [name] of winner " wins") ]
  set game-complete? true
end

to-report game-over?
  report (not any? cards with [ not hidden? and not opp-can-see? and not player-can-see? ])
         or (2 > count players with [ not folded? ])
end

to-report player-state [ omniscient? ] ;; player
  let my-cards cards with [owner = myself and not hidden?]
  set my-data []
  set my-data lput (list "name" name) my-data
  set my-data lput (list "bet" bet) my-data
  set my-data lput (list "folded" ifelse-value folded? [ "True" ] [ "False" ]) my-data
  if any? my-cards [
    set my-data lput  (list "chips" count chips with [owner = myself])  my-data
    let face-up-cards my-cards with [opp-can-see?]
    set my-data lput (list "face_up_cards" ifelse-value not any? face-up-cards [ [] ] [[(list (first rank) suit)] of face-up-cards ])  my-data
    if (omniscient?) [
      set my-data lput (list "round_winner_by_cards" [name] of winning-player)  my-data
      let face-down-cards my-cards with [not opp-can-see? and not player-can-see?]
      let face-player-cards my-cards with [not opp-can-see? and player-can-see?]
      set my-data lput (list "face_down_cards" ifelse-value not any? face-down-cards [ [] ] [[(list (first rank) suit)] of face-down-cards])  my-data
      set my-data lput (list "face_player_cards" ifelse-value not any? face-player-cards [ [] ] [[(list (first rank) suit)] of face-player-cards ])  my-data
      set my-data lput (list "all_cards" [(list (first rank) suit)] of my-cards)  my-data
      set my-data lput (list "handvalue" first evaluate-my-full-hand) my-data
    ]
  ]
;  print table:to-json table:from-list my-data
  report table:to-json table:from-list my-data

;  report (list
;    name
;    ifelse-value (count cards with [ owner = myself ] >= 5) [ evaluate-my-full-hand ] [ "NO_CARDS" ]
;    bet
;    folded?
;    count chips with [owner = myself]
;    count chips with [owner = pot-patch]
;    [(list suit rank player-can-see? opp-can-see?)] of cards with [owner = myself]
;    )
end

to-report join-list-as-string [ a-list ]
  report reduce [[res x] -> (word res "," x)] a-list
end

to-report quote-string [ anything-stringable ]
  report (word "\"" anything-stringable "\"")
end



to log-action [ action action-data ]
  if logging? [
    set data lput (list quote-string date-and-time "," quote-string action "," join-list-as-string action-data) data
  ]
end

to log-full-state [ action ]
  log-action action [ player-state true ] of players
end

to-report visible-state [ player-viewing ]
  report (word quote-string date-and-time "," quote-string "VISIBLE" "," join-list-as-string ([player-state (self = player-viewing)] of players))
end

to reset-round
  log-full-state "ENDROUND"
  set current-bet 0
  ask players [
    set called? false
    set raised? false
    set bet 0
    set bet? false
  ]
  ask chips with [ in-round? ] [
    set in-round? false
    set owner pot-patch
    move-to owner
    rt random 360
    fd random-float 1.5
  ]
  export-log
end


to do-round
  let current-active-players players with [ bet? or called? or raised? ]
  if not any? current-active-players [ reset-round ]
  foreach sort [self] of players with [ not folded? ] [ p ->
    ask p [ do-bet ]
;    wait 0.1
  ]
  if (all? players [ folded? or called? ]) [
    ifelse not game-over? [
      ask players with [not folded?] [ flip-random-card-up ]
      reset-round
    ] [
      complete-game
    ]
  ]
end

to go
  tick
  ifelse game-complete? [
    if count players with [ count chips with [ owner = myself ] > 2 ] < 2 [ reset-players ]
    reset-game
  ] [ ifelse game-over? [ complete-game ] [ do-round ] ]
end
@#$#@#$#@
GRAPHICS-WINDOW
130
10
898
779
-1
-1
40.0
1
20
1
1
1
0
0
0
1
-9
9
-9
9
0
0
1
ticks
30.0

BUTTON
19
10
124
55
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
19
56
124
89
NIL
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
20
175
127
208
logging?
logging?
1
1
-1000

BUTTON
20
90
125
123
go once
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

cardback
false
0
Rectangle -1 true false 45 15 255 285
Rectangle -7500403 true true 60 30 240 45
Rectangle -7500403 true true 60 255 240 270
Circle -7500403 true true 75 75 150

cardclub
false
0
Circle -7500403 true true 90 0 120
Polygon -16777216 true false 150 0 135 45 90 45 150 120 210 45 165 45 150 0

carddiamond
false
0
Circle -7500403 true true 90 0 120
Polygon -2674135 true false 90 60 120 30 150 0 210 60 150 120 120 90 90 60

cardheart
false
0
Circle -7500403 true true 90 0 120
Polygon -2674135 true false 150 120 90 30 120 0 135 30 165 30 180 0 210 30

cardspade
false
0
Circle -7500403 true true 88 -2 124
Polygon -16777216 true false 150 120 135 60 90 75 150 0 210 75 165 60 150 120

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

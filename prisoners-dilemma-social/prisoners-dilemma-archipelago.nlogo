globals [water-level max-level min-level lb ub colors]
breed [trees tree]
breed [monkeys monkey]
breed [ results result]

trees-own
[
  occupant1
  occupant2
  available?
  age
]

monkeys-own
[
  at-tree?
  waiting
  strategy
  energy
  target
  memory
]

patches-own
[
  level
  land-mass
  dist-to-tree
  neighbors-diag
  visited
]

results-own
[
  age
]

to setup
  clear-all
  ask patches
  [
    set neighbors-diag ( neighbors with [
      (not member? self [neighbors4] of myself)] )
  ]
  set colors [red green yellow cyan orange brown grey magenta]
  ; ask patches
  ; [
  ; set level random 100
  ; ]
  ask n-of 50 patches
  [
    set level level + 2500
  ]
  repeat smooth
  [
    diffuse level 0.2
  ]
  set lb [level] of min-one-of patches [level]
  set ub [level] of max-one-of patches [level]
  ask patches
  [
    let diff ((level - lb) / (ub - lb))
    set pcolor (rgb (1 + (diff * 246)) (122 + (diff * 120)) (30 + (diff * 138)))
  ]

  set max-level ((max-level-ratio * ub) + ((1 - max-level-ratio) * lb))
  set min-level ((min-level-ratio * ub) + ((1 - min-level-ratio) * lb))
  set water-level min-level
  ask patches with [level < water-level] [set pcolor blue]
  ask n-of 20 patches with [level >= water-level]
  [
    sprout-monkeys 1
    [
      set size 3
      set shape "monkey"
      set color 33
      set energy 100
      set strategy 1
      set waiting 0
      set at-tree? false
      set target nobody
      set memory turtle-set nobody
    ]

  ]
  reset-ticks
end

to label-patches
  ask patches
  [
    ifelse (level < water-level)
    [
      set land-mass -10
    ]
    [
      set land-mass -1
    ]
  ]
  let counter 1
  while [any? patches with [land-mass = -1]]
  [
    ask one-of patches with [land-mass = -1]
    [do-label counter]
    set counter counter + 1
  ]
end

to do-label [c]
  set land-mass c
  ask neighbors
  [
    if land-mass = -1
    [ do-label c ]
  ]
end

to make-distance-gradient
  ask patches [set dist-to-tree 10000000 set visited False]
  let q []
  ask trees
  [
    ask patch-here [set dist-to-tree 0]
    set q lput patch-here q
  ]
  while [not empty? q]
  [
    ;set q sort-by [ [a b] -> [dist-to-tree] of a < [dist-to-tree] of b] q
    let curr item 0 q
    set q butfirst q
    if not [visited] of curr
    [
      ask curr
      [
        let d dist-to-tree
        set visited true
        ask neighbors4
        [
          if not visited and dist-to-tree > (d + 1) and level >= water-level
          [
            set dist-to-tree (d + 1)
            set q lput self q
          ]
        ]
        ask neighbors-diag
        [
          if not visited and dist-to-tree > (d + (sqrt 2)) and level >= water-level
          [
            set dist-to-tree (d + (sqrt 2))
            set q lput self q
          ]
        ]
      ]
    ]
  ]
end

to go
  set water-level ((max-level + min-level) / 2.0) + ((max-level - min-level) / 2.0) * sin (rate * ticks + 270)
  ask patches with [level >= water-level]
  [
    let diff ((level - lb) / (ub - lb))
    set pcolor (rgb (1 + (diff * 246)) (122 + (diff * 120)) (30 + (diff * 138)))
  ]
  ask patches with [level < water-level] [set pcolor blue]
  ;;label-patches
  let roll random-float 1
  if roll < tree-grow-probability
  [
    ask one-of patches with [level >= water-level]
    [
      if not any? trees-here [
        sprout-trees 1
        [
          set age 0
          set shape "PalmFruitTree"
          set size 4
          set available? true
          set occupant1 nobody
          set occupant2 nobody
        ]
      ]
    ]
  ]
  ;;make-distance-gradient
  process-monkeys
  process-trees
  process-results
  tick
end

to process-trees
  ask trees
  [
    set age age + 1
    if [level] of patch-here < water-level
    [
      if occupant1 != nobody
      [ask occupant1 [die]]
      if occupant2 != nobody
      [ask occupant2 [die]]
      die
    ]
    ;;if age > max-tree-age [die]
    (ifelse
      occupant2 != nobody
      [
        ask occupant2 [set waiting waiting + 1]
        if [waiting] of occupant2 > wait-time
        [
          play-the-game occupant1 occupant2
          die
        ]
      ]
      occupant1 != nobody
      [
        ask occupant1 [set waiting waiting + 1]
        if [waiting] of occupant1 > wait-time
        [
          play-the-game occupant1 nobody
          die
        ]
      ]
    )
  ]
end

to process-monkeys
  ask monkeys with [not at-tree?]
  [
    if target = nobody or [not available?] of target
    [
      let targs trees with [available? and (distance myself < 10) and occupant1 != nobody]
      if not any? targs
      [
        set targs trees with [available? and (distance myself < 10)]
      ]
      let x 0
      ifelse ((count targs) > 3)
      [set x 3]
      [set x count targs]

      ifelse any? targs
      [set target one-of min-n-of x targs [distance myself]]
      [set target nobody]
    ]
    ifelse target != nobody
    [
      face target
    ]
    [
      rt (random 31) - 15
    ]
    if [level] of patch-ahead 0.2 < water-level
    [
      rt 180
      set target nobody
    ]
    fd 0.2
    set energy energy - 0.2
    if target != nobody and distance target < 0.3
    [
      arrive-at-tree target
    ]
    if energy < 0
    [die]
    if [level] of patch-here < water-level
    [die]
    if energy > 200
    [
      set energy energy - 100
      hatch-monkeys 1
      [
        if random-float 1 < mutation-rate
        [set strategy one-of [1 2 3]]
        set energy 100
        set waiting 0
        set at-tree? false
        set target nobody
        set memory turtle-set nobody
      ]
    ]
  ]
end

to arrive-at-tree [t]
  (ifelse
    [occupant1] of t = nobody ;; if the first person here
    [
      ask t [set occupant1 myself]
      set at-tree? true
    ]
    [occupant2] of t = nobody
    [
      ask t [set occupant2 myself set available? false]
      set at-tree? true
    ]
  )
end

to play-the-game [p1 p2]
  let s1 (get-strategy p1 p2)
  let s2 (get-strategy p2 p1)
  (ifelse
    p2 = nobody
    [
      ask p1 [set energy energy + 10 set waiting 0 set at-tree? false]
    ]
    s1 = 1 and s2 = 1
    [
      ask p1 [set energy energy + 25 set waiting 0 set at-tree? false]
      ask p2 [set energy energy + 25 set waiting 0 set at-tree? false]
      hatch-results 1 [set age 0 set shape "cooperate" set size 3]
      process-outcome p1 p2 1
      process-outcome p2 p1 1
    ]
    s1 = 1 and s2 = 2
    [
      ask p1 [set waiting 0 set at-tree? false]
      ask p2 [set energy energy + 40 set waiting 0 set at-tree? false]
      hatch-results 1 [set age 0 set shape "cheat" set size 3]
      process-outcome p1 p2 3
      process-outcome p2 p1 2
    ]
    s1 = 2 and s2 = 1
    [
      ask p1 [set energy energy + 40 set waiting 0 set at-tree? false]
      ask p2 [set waiting 0 set at-tree? false]
      hatch-results 1 [set age 0 set shape "cheat" set size 3]
      process-outcome p1 p2 2
      process-outcome p2 p1 3
    ]
    [
      ask p1 [set energy energy + 10 set waiting 0 set at-tree? false]
      ask p2 [set energy energy + 10 set waiting 0 set at-tree? false]
      hatch-results 1 [set age 0 set shape "defect" set size 3]
      process-outcome p1 p2 4
      process-outcome p2 p1 4
  ])
end

to-report get-strategy [p1 p2]
  (ifelse
    p1 = nobody or p2 = nobody
    [report 0]
    [strategy] of p1 = 1
    [report 1]
    [strategy] of p1 = 2
    [report 2]
    [strategy] of p1 = 3
    [
      if-else member? p2 ([memory] of p1)
      [report 2]
      [report 1]
    ]
  )
end

to process-outcome [p1 p2 outcome] ;;1-cooperate 2-I cheated 3-got cheated 4-double defect
  (ifelse
    outcome = 3 and [strategy] of p1 = 3
    [
      ask p1 [set memory (turtle-set memory p2)]
    ]
  )
end

to process-results
    ask results
  [
    set age age + 1
    if age > visualization-peristence-ticks
    [die]
  ]
end


; 247 153 138
@#$#@#$#@
GRAPHICS-WINDOW
210
10
863
664
-1
-1
5.0
1
10
1
1
1
0
1
1
1
-64
64
-64
64
1
1
1
ticks
30.0

BUTTON
35
241
98
274
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

SLIDER
21
286
193
319
smooth
smooth
0
400
400.0
1
1
NIL
HORIZONTAL

SLIDER
21
323
193
356
max-level-ratio
max-level-ratio
0.1
0.9
0.4
0.01
1
NIL
HORIZONTAL

SLIDER
21
359
193
392
min-level-ratio
min-level-ratio
0.1
0.9
0.1
0.01
1
NIL
HORIZONTAL

SLIDER
21
395
193
428
rate
rate
0.001
0.1
0.005
0.001
1
NIL
HORIZONTAL

BUTTON
115
241
178
274
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

SLIDER
20
432
193
465
tree-grow-probability
tree-grow-probability
0
1
0.3
0.01
1
NIL
HORIZONTAL

SLIDER
20
469
193
502
max-tree-age
max-tree-age
0
500
150.0
1
1
NIL
HORIZONTAL

SLIDER
22
201
194
234
init-trees
init-trees
0
200
50.0
1
1
NIL
HORIZONTAL

PLOT
869
12
1192
230
Monkey Population
Ticks
Monkeys
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"Total" 1.0 0 -10402772 true "" "if ticks mod 1000 = 0 [plot count monkeys]"
"Chumps" 1.0 0 -13345367 true "" "if ticks mod 1000 = 0 [plot count monkeys with [strategy = 1]]"
"Cheaters" 1.0 0 -2674135 true "" "if ticks mod 1000 = 0 [plot count monkeys with [strategy = 2]]"
"Vengeful Friends" 1.0 0 -13840069 true "" "if ticks mod 1000 = 0 [plot count monkeys with [strategy = 3]]"

SLIDER
21
507
193
540
wait-time
wait-time
0
100
20.0
1
1
NIL
HORIZONTAL

SLIDER
21
545
194
578
visualization-peristence-ticks
visualization-peristence-ticks
0
100
20.0
1
1
NIL
HORIZONTAL

PLOT
869
234
1194
455
Strategy Types
NIL
Monkeys
0.0
3.0
0.0
10.0
true
true
"" "clear-plot"
PENS
"Chumps" 1.0 1 -13345367 true "" "plotxy 0 count monkeys with [strategy = 1]"
"Cheaters" 1.0 1 -2674135 true "" "plotxy 1 count monkeys with [strategy = 2]"
"Vengeful Friends" 1.0 1 -13840069 true "" "plotxy 2 count monkeys with [strategy = 3]"

SLIDER
22
162
194
195
mutation-rate
mutation-rate
0
0.1
0.1
0.01
1
NIL
HORIZONTAL

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

cheat
false
0
Line -2674135 false 75 45 225 255
Line -2674135 false 225 45 75 255
Line -2674135 false 225 60 90 255
Line -2674135 false 90 45 225 240
Line -2674135 false 75 60 210 255
Line -2674135 false 210 45 75 240

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cooperate
false
0
Circle -13791810 false false 45 45 210
Circle -13791810 false false 60 60 180
Circle -13791810 false false 75 75 150

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

defect
false
0
Rectangle -1184463 false false 75 45 225 255
Rectangle -1184463 false false 90 60 210 240

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

monkey
false
0
Polygon -7500403 true true 64 182 79 227 49 257 79 287 94 272 64 257 113 229 105 191 131 198 124 257 154 287 169 272 139 257 169 197 154 182 177 183 173 230 185 277 216 272 199 257 199 197 238 263 274 262 248 247 220 194 214 152 199 122 139 107 94 122 64 152 64 182
Circle -7500403 true true 178 88 62
Polygon -7500403 true true 75 165 45 150 30 120 45 90 90 75 120 60 120 45 105 45 90 45 105 30 135 30 150 60 120 75 60 105 60 120 90 135 105 135
Circle -7500403 true true 222 91 30
Circle -7500403 true true 165 90 30

palmfruittree
false
0
Polygon -10899396 true false 120 30 120 30 180 75 165 150 150 105 120 60 120 30
Polygon -13840069 true false 90 90 120 30 180 75 180 150 150 105 120 60 90 90
Polygon -6459832 true false 135 270 165 270 165 210 135 150 150 60 120 60 105 150 120 210 105 270 135 270 120 270
Polygon -10899396 true false 120 90 150 30 210 75 225 150 180 105 150 60 120 90
Circle -1184463 true false 180 75 30
Polygon -10899396 true false 135 90 105 30 45 75 45 150 75 105 105 60 135 90
Circle -1184463 true false 60 90 30
Circle -1184463 true false 75 45 30
Circle -1184463 true false 105 75 30
Circle -1184463 true false 150 105 30
Polygon -13840069 true false 105 90 135 30 195 75 195 150 165 105 135 60 105 90
Polygon -13840069 true false 165 90 120 30 75 75 75 150 105 105 135 60 165 90
Circle -1184463 true false 150 60 30

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
NetLogo 6.1.1
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
0
@#$#@#$#@
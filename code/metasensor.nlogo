__includes ["neural-net.nls"]
breed [robots robot]
breed [lights light]
breed [metasensors metasensor]
breed [obstacles obstacle]

robots-own [
  speed

  sensor-dx-current-xy ; (list pos_x pos_y) current position
  sensor-sx-current-xy ; (list pos_x pos_y) current position

]
metasensors-own [
  my-creator

  best-fitness
  current-fitness
  fitness-values-window  ;FINESTRA DI ADATTAMENTO ONLINE
  offline-optimization-fitness-values  ;SEQUENZA DI VALORI DI FITNESS PER L'OTTIMIZZAZIONE OFFLINE


  ; ground sensors
  ground_front
  ground_back
  ground_left
  ground_right

  previous-heading
  total-heading-change

  wasInProhibitedAreas
  turningDirectionChosen
]

globals [
  patches-modified
  patches-modified-previous-values
  max_distance_proximity_sensors
  area_avoidance_steps
  total_area_avoidance_steps
  STEPS_OF_ADAPTATION_WINDOW

]

patches-own [light-intensity]



to setup
  ;random-seed experiment-seed  ;; Set the seed to a specific value
  clear-all
  reset-ticks
  set patches-modified []
  set patches-modified-previous-values []
  set max_distance_proximity_sensors 6 ; maximum perceivable distance
  set area_avoidance_steps 0
  set total_area_avoidance_steps 0
  set STEPS_OF_ADAPTATION_WINDOW 40
  ;set SIMULATION_STEPS_OFFLINE_OPTIMIZATION 1000


  ifelse offline-optimization? = true
  [
    ;read from file the weights  of the neural net
    read_nn_weights_from_file
    print-all-weights
  ]
  [
    ; altrimenti setta una random neural network
     setup-nn ;; seutp neural network (random weigths)
  ]

  setup-light
  setup-robots


   create-forbidden-area 20 8 -3 0
  create-forbidden-area 5 20 3 -1
  create-forbidden-area 8 20 5 24



   ifelse offline-optimization? = false and hand-coded? = false
   [
       print "[WARNING] Since no preference was selected between the hand-coded and the optimised offline version, the HAND-CODED version is selected by default!"
   ]
  [
    if offline-optimization? = true and hand-coded? = true
    [
        print "[WARNING] Since both metasensor versions are selected, the NN-based metasensor is selected."
    ]
  ]

end

; COLORA LE PATCH SECONDO IL LORO VALORE "val"
to visualize-patches
   ask patches [ set pcolor scale-color yellow light-intensity 0.0 1.0]
end

to setup-light
  create-lights 1 [
    set shape "circle"
    set color yellow
    set size 3
    setxy 18 18 ;random-xcor random-ycor
    ; Assegna l'intensità della luce ai patch circostanti

    ask patch-here [
      set light-intensity 150
    ]
  ]
  diffuse-light
  visualize-patches
end

to diffuse-light
  ; Diffondi l'intensità della luce ai patch circostanti
  repeat 150 [ diffuse light-intensity 0.95 ]
end

to setup-obstacles
  create-obstacles 1 [
    set shape "square"
    set color red
    set size 1
    setxy 22 22
    ;setxy random-xcor random-ycor
  ]
end

to create-forbidden-area [rows cols x-offset y-offset]
  let obstacle-size 1  ; Size of each obstacle
  let start-x ((cols - 1) * obstacle-size / 2) + x-offset  ; Calculate starting x position for centering
  let start-y ((rows - 1) * obstacle-size / 2) + y-offset ; Calculate starting y position for centering

  ; Create obstacles in a grid formation
  let row-index 0
  while [row-index < rows] [
    let current-y start-y + (row-index * obstacle-size)  ; Calculate y position for the current row

    let col-index 0
    while [col-index < cols] [
      create-obstacles 1 [
        set shape "square"
        set color red
        set size obstacle-size
        setxy start-x + (col-index * obstacle-size) current-y  ; Position the obstacle
      ]

      set col-index col-index + 1  ; Increment the column index
    ]

    set row-index row-index + 1  ; Increment the row index
  ]
end

to setup-robots
  create-robots 1 [
    set shape "default"
    set color 8
    set size 2.5
    set heading 0
    setxy 23 13
    ;set heading random 360
    ;setxy random-xcor random-ycor

    if metasensor?[
     hatch-metasensors 1 [
      set fitness-values-window []
      set offline-optimization-fitness-values []
      set current-fitness 0
      set best-fitness current-fitness
      set-best-equal-to-current ; pesi nn
      set wasInProhibitedAreas false
      set turningDirectionChosen "dx"
      set shape "default"
      set size 1.7
      set color 63
      set my-creator myself ; Pass the robot reference to the metasensor
      set heading [heading] of my-creator

      set previous-heading heading  ;; Inizializza la direzione precedente
      set total-heading-change 0    ;; Inizializza il cambiamento di direzione totale

      set ground_front 0
      set ground_back 0
      set ground_left 0
      set ground_right 0

      ]
    ]
  ]
end

to restore-patch-values
  ;; Iterate through the list of coordinates and restore the previous values
  let num-modified length patches-modified
  repeat num-modified [
    let coordinates item 0 patches-modified  ;; Get the coordinates list
    let previous-value item 0 patches-modified-previous-values  ;; Get the previous value

    ;; Extract the x and y coordinates
    let x (item 0 coordinates)
    let y (item 1 coordinates)

    ;; Restore the previous value to the respective patch
    ask patch x y [
      set light-intensity previous-value  ;; Restore the value
    ]

    ;; Remove the processed elements
    set patches-modified remove-item 0 patches-modified
    set patches-modified-previous-values remove-item 0 patches-modified-previous-values
  ]
end

to setup-plot-fitness
  set-current-plot "Metasensor's fitness"  ;; Set the plot name to the one you've created
  set-current-plot-pen "Fitness"  ;; Set the pen name in the plot
  clear-plot  ;; Clear the plot for new data
end

to setup-plot-collisions
  set-current-plot "Steps in prohibited areas"  ;; Set the plot name to the one you've created
  set-current-plot-pen "steps"  ;; Set the pen name in the plot
  clear-plot  ;; Clear the plot for new data
end

to check-if-on-prohibited-areas
  ask robots [
    if any? obstacles-on patch-here [
      set area_avoidance_steps area_avoidance_steps + 1
      set total_area_avoidance_steps total_area_avoidance_steps + 1
    ]
  ]
end


to plot_time_on_prohibited_areas
  set-current-plot "Steps in prohibited areas"  ;; Set the plot name to the one you've created
  set-current-plot-pen "steps"  ;; Set the pen name in the plot

  plot area_avoidance_steps
  set area_avoidance_steps 0
end

to go

  ask robots[
    move-robot-phototaxis

  ]
  check-if-on-prohibited-areas

  ;; RESET THE WORLD LIGHTS TO THEIR PREVIOUS VALUES
  restore-patch-values

  ifelse metasensor?[
    ask metasensors [
      follow-my-robot

      ; update fitness
      if length fitness-values-window >= STEPS_OF_ADAPTATION_WINDOW [
         set current-fitness mean fitness-values-window
          set-current-plot "Metasensor's fitness"  ;; Set the plot name to the one you've created
         set-current-plot-pen "Fitness"  ;; Set the pen name in the plot
         plot current-fitness   ;; Plot the energy value of each robot

        plot_time_on_prohibited_areas


      ]

    ]
  ]
  [
    ask metasensors [die]

    ; se non c'è il metasensore aggiorniamo il plot del tempo nelle aree proibite
    if ticks mod STEPS_OF_ADAPTATION_WINDOW = 0 [
       plot_time_on_prohibited_areas
    ]

  ]

  visualize-patches


  if ticks >= SIMULATION_STEPS_OFFLINE_OPTIMIZATION
  [
    print "stop simulation!"
    ask metasensors [
        save-values-to-csv (word  experiment-folder "/" offline-solution-id "/" offline-solution-id ".csv") offline-optimization-fitness-values "fitness"
      ]
    let TEMP_area_avoidance_steps_list []
    set TEMP_area_avoidance_steps_list lput total_area_avoidance_steps TEMP_area_avoidance_steps_list
    save-values-to-csv (word  experiment-folder "/" offline-solution-id "/tot_steps_area_avoidance.csv") TEMP_area_avoidance_steps_list "tot-steps"


    stop
    set total_area_avoidance_steps 0
  ]

  ;print (word "ticks: " ticks)
  ;print (word "tot: " total_area_avoidance_steps)
  tick
end

to move-robot-phototaxis
  let current-patch patch-here
    ask current-patch [
     ; set pcolor green
    ]


    let angle_dx heading-to-angle(heading) - 30
    let angle_sx heading-to-angle(heading) + 30

    let sensor-dx-info read_sensor angle_dx lime
    let sensor-sx-info read_sensor angle_sx lime


    ; retrieve val of light intensity
    let right-intensity item 0 sensor-dx-info ;val
    let left-intensity item 0 sensor-sx-info ;val

    ;retrieve x and y position of sensor ath the right and at the left
    set sensor-dx-current-xy sublist sensor-dx-info 1 3
    set sensor-sx-current-xy sublist sensor-sx-info 1 3


    ;;; FEAR
    let total-intensity (left-intensity + right-intensity) * 1.5
    let limited-intensity min list total-intensity 1
    set speed total-intensity
    let turn (left-intensity - right-intensity) * 140

    rt turn
    fd speed


end

to-report heading-to-angle [h]
  report (90 - h) mod 360
end

to-report read_sensor [angle _col]

  let x xcor + 1.5 * cos(angle)
  let y ycor + 1.5 * sin(angle)

  let val 0
  ask patch x y
  [
    ;set pcolor _col
    set val light-intensity
  ]

  ;print (word "angle: " angle ", lights, x: " x "lights y: " y)
  report (list val x y)

end


;;;; METASENSOR
to follow-my-robot
  ; This makes the metasensor follow the robot that created it

  if my-creator != nobody [
    ;face my-creator
    let creator-speed [speed] of my-creator ; Retrieve the speed of the robot
    ;fd creator-speed * 1 ; Move at 80% of the creator's speed (or adjust as needed)


    let creator-heading [heading] of my-creator ; heading del robot

    ;set light to its light sensors
    let robot-sensor-dx-xy [sensor-dx-current-xy] of my-creator
    let dx-x (item 0 robot-sensor-dx-xy)
    let dx-y (item 1 robot-sensor-dx-xy)


    ;; Recupera la posizione attuale per sx-x e sx-y
    let robot-sensor-sx-xy [sensor-sx-current-xy] of my-creator
    let sx-x (item 0 robot-sensor-sx-xy)
    let sx-y (item 1 robot-sensor-sx-xy)

    ;print (word "PRIMA metas DX, x: "  dx-x  "lights y: " dx-y)
    ;print (word "PRIMA metas SX, x: "  sx-x  "lights y: " sx-y)

    ;; Calcola il cambiamento di posizione in base alla velocità e alla direzione del creatore
    let dx-x-new dx-x + creator-speed * sin creator-heading
    let dx-y-new dx-y + creator-speed * cos creator-heading

    let sx-x-new sx-x + creator-speed * sin creator-heading
    let sx-y-new sx-y + creator-speed * cos creator-heading


    ; "RETRIEVE PREIVOUS VALUES OF THE WORLD LIGHTS IN ORDER TO RESET AFTER THE ROBOT READINGS
    set patches-modified (list (list dx-x-new dx-y-new) (list sx-x-new sx-y-new))
    ask patch dx-x-new dx-y-new [
      set patches-modified-previous-values lput light-intensity patches-modified-previous-values
    ]
    ask patch sx-x-new sx-y-new [
      set patches-modified-previous-values lput light-intensity patches-modified-previous-values
    ]

    ; MOVE THE METASENSOR ACCORDING TO THE ROBOT MOVEMENT
    set heading [heading] of my-creator
    fd creator-speed * 1 ; Move at 80% of the creator's speed (or adjust as needed)

    ; KEEP TRACK OF HEADING CHANGE
    ;; Calcola la differenza con segno, tenendo conto della rotazione a destra o sinistra
    let current-heading heading

    let heading-change current-heading - previous-heading

    ;; Assicura che il cambiamento di direzione sia all'interno dell'intervallo [-180, 180]
    if heading-change > 180 [
      set heading-change heading-change - 360
    ]
    if heading-change < -180 [
      set heading-change heading-change + 360
    ]

    ;; Aggiungi il cambiamento di direzione al totale
    set total-heading-change total-heading-change + abs heading-change



    ; GROUND SENSORS
    check-ground-sensors



    ifelse offline-optimization?
    [
      ;AREA AVOIDANCE USING NN
      metasensor-area-avoidance-nn  dx-x-new dx-y-new sx-x-new sx-y-new
    ]
    [
      ; HAND_CODED AREA AVOIDANCE
      metasensor-area-avoidance-hand-coded dx-x-new dx-y-new sx-x-new sx-y-new

    ]



    ;let robot-xcor [xcor] of my-creator
    ;let robot-ycor [ycor] of my-creator
    ;setxy robot-xcor robot-ycor
    ; ESSENTIAL COMMANDS
    ;face my-creator


   ;; Aggiorna la direzione precedente
    set previous-heading current-heading


  ]
end

to-report normalize-sensor [value]
  report ( abs(value - max_distance_proximity_sensors) / max_distance_proximity_sensors)
end


to-report compute-fitness-area-avoidance
  let all_ground_sensors (list ground_front ground_back ground_left ground_right)
  let num_of_active_ground_sensors sum all_ground_sensors
  let penalty 0.25

  ;report (1 - (sqrt (penalty * num_of_active_ground_sensors))) *  ([speed] of my-creator) * (1 / (1 + (total-heading-change / (ticks + 1))))

  ifelse num_of_active_ground_sensors > 0
  [
    report 0
  ]
  [
    report (sqrt ([speed] of my-creator)) * (1 / (1 + (total-heading-change / (ticks + 1))))
  ]


end

 ; AREA AVOIDANCE (USING NN)
to metasensor-area-avoidance-nn [dx-x-new dx-y-new sx-x-new sx-y-new]
   let result feed-forward (list ground_front ground_back ground_left ground_right)

   let new-max 1  ;; Define the maximum of the new range
   let rescaled-dx-light (item 0 result) * new-max  ;; Normalize the value
   let rescaled-sx-light (item 1 result) * new-max  ;; Normalize the value
    ask patch dx-x-new dx-y-new
    [
       set light-intensity light-intensity + rescaled-dx-light
    ]
    ask patch sx-x-new sx-y-new
    [
        set light-intensity light-intensity + rescaled-sx-light
    ]

    ;; FITNESS
  let fit compute-fitness-area-avoidance
  set fitness-values-window lput fit fitness-values-window
  set offline-optimization-fitness-values lput fit offline-optimization-fitness-values

end

; AREA AVOIDANCE (HAND-CODED)
to complex-metasensor-area-avoidance-hand-coded [dx-x-new dx-y-new sx-x-new sx-y-new]

  let fit compute-fitness-area-avoidance
  set fitness-values-window lput fit fitness-values-window

  let delta 0.1
  let dx_light 0
  let sx_light 0

  let any_sensor_is_activated false



  ifelse ground_right = 1 and ground_left = 0 and ground_front = 0 and ground_back = 0
  [
        set any_sensor_is_activated true
        set dx_light dx_light + delta
  ]
  [
    ifelse ground_right = 0 and ground_left = 1 and ground_front = 0 and ground_back = 0
    [
          set any_sensor_is_activated true
          set sx_light sx_light + delta
    ]
    [
      if (ground_right = 1 or ground_left = 1) and ( ground_front = 1 or ground_back = 1 )
      [
        set any_sensor_is_activated true
        ifelse ground_right = 1 and ground_left = 1
        [
          ifelse wasInProhibitedAreas = false
          [
            let choice one-of ["dx" "sx"]
            set turningDirectionChosen choice
            ifelse choice = "dx"
            [
              ; code for "dx"
               set dx_light dx_light + delta
            ]
            [
               set sx_light sx_light + delta
            ]
          ]
          [ ;wasInProhibitedAreas = true
            ifelse turningDirectionChosen = "dx"
            [
              ; code for "dx"
               set dx_light dx_light + delta
            ]
            [
               set sx_light sx_light + delta
            ]
          ]
        ]
        [ ifelse ground_right = 1
          [
               set dx_light dx_light + 2 * delta
          ]
          [ ;ground_left = 1
               set sx_light sx_light + 2 * delta
          ]
        ]
      ]

    ]
  ]



  ; add noise
   ifelse any_sensor_is_activated = true
   [
    set wasInProhibitedAreas true

    set dx_light dx_light + random-float 0.1 - 0.05
    set sx_light sx_light + random-float 0.1 - 0.05

   ]
   [
    set wasInProhibitedAreas false
   ]

    ask patch dx-x-new dx-y-new
    [
      set light-intensity light-intensity + dx_light
    ]
    ask patch sx-x-new sx-y-new
    [
        set light-intensity light-intensity + sx_light
    ]

    ;; FITNESS
   ;let fit compute-fitness-area-avoidance ground
   ;set fitness-values-window lput fit fitness-values-window
end

to metasensor-area-avoidance-hand-coded [dx-x-new dx-y-new sx-x-new sx-y-new]
  let fit compute-fitness-area-avoidance
  set fitness-values-window lput fit fitness-values-window

  let delta 0.1
  let dx_light 0
  let sx_light 0

  let any_sensor_is_activated false


  let increment (1 + 0.5 * ground_front) * delta

    ifelse ground_right = 1 and ground_left = 0 [
      set dx_light dx_light + increment
      set any_sensor_is_activated true
    ]
    [
      ifelse ground_left = 1 and ground_right = 0 [
       set sx_light sx_light + increment
       set any_sensor_is_activated true
      ]
      [
         if ground_left = 1 and ground_right = 1 [
              set dx_light dx_light + increment
              set any_sensor_is_activated true
         ]
      ]
    ]


  ; add noise
   if any_sensor_is_activated = true
   [

    set dx_light dx_light + random-float 0.1 - 0.05
    set sx_light sx_light + random-float 0.1 - 0.05

   ]

    ask patch dx-x-new dx-y-new
    [
      set light-intensity light-intensity + dx_light
    ]
    ask patch sx-x-new sx-y-new
    [
        set light-intensity light-intensity + sx_light
    ]
end






to check-ground-sensors
  ; Define sensor positions relative to the turtle's heading and position
  let front-sensor patch-ahead 1.2  ; Sensor in front
  let back-sensor patch-left-and-ahead 180 1.2  ; Sensor behind
  let left-sensor patch-left-and-ahead 90 1.2  ; Sensor on the left
  let right-sensor patch-right-and-ahead 90 1.2  ; Sensor on the right


  ; Draw sensors on the patches
  ;draw-sensor front-sensor brown
  ;draw-sensor back-sensor blue
  ;draw-sensor left-sensor yellow
  ;draw-sensor right-sensor violet

  set ground_front 0
  set ground_back 0
  set ground_left 0
  set ground_right 0

  ; Check if sensors detect obstacles
  if any? obstacles-on front-sensor [
    ;print "Front sensor: Obstacle detected!"
    ;stop-movement  ; Call a procedure to stop or change movement
    set ground_front 1
  ]
  if any? obstacles-on back-sensor [
   ;print "Back sensor: Obstacle detected!"
    set ground_back 1
  ]
  if any? obstacles-on left-sensor [
    ;print "Left sensor: Obstacle detected!"
    set ground_left 1
  ]
  if any? obstacles-on right-sensor [
    ;print "Right sensor: Obstacle detected!"
    set ground_right 1
  ]

end

to draw-sensor [sensor-patch sensor-color]
  ask sensor-patch [
    set pcolor sensor-color  ; Temporarily change the patch color to visualize the sensor
  ]
end



; Procedure to save values to a CSV file
to save-values-to-csv [OUTPUT_FILE VALUES_LIST COLUMN_NAME]
  ; Define the filename
  ;let filename "output-data.csv"
  let filename OUTPUT_FILE

  ; Open the file for writing
  file-open filename


  file-print COLUMN_NAME


  foreach VALUES_LIST [
    x -> file-print (word x )
  ]


  ; Collect data you want to save
  ;let tick-value ticks

  ; Write the data to the file
  ;file-print (word tick-value ", " tick-value )

  ; Close the file
  file-close
  print (word "Data saved to " filename)
end
@#$#@#$#@
GRAPHICS-WINDOW
293
10
1021
739
-1
-1
20.0
1
10
1
1
1
0
1
1
1
0
35
0
35
1
1
1
ticks
30.0

BUTTON
18
36
84
69
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
20
89
83
122
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
0

BUTTON
20
139
83
172
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
0

SWITCH
20
191
155
224
metasensor?
metasensor?
0
1
-1000

PLOT
1048
98
1449
375
Metasensor's fitness
NIL
NIL
0.0
10.0
0.0
1.0
true
true
"" ""
PENS
"Fitness" 1.0 0 -16777216 true "" ""

PLOT
1053
426
1445
697
Steps in prohibited areas
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
"steps" 1.0 0 -16777216 true "" ""

SWITCH
20
246
157
279
hand-coded?
hand-coded?
0
1
-1000

SWITCH
12
378
198
411
offline-optimization?
offline-optimization?
0
1
-1000

INPUTBOX
10
501
239
561
offline-solution-id
59db27150973b478bf7e956ce3fe8252190259126309669944464
1
0
String

TEXTBOX
20
342
170
360
Offline optimization
11
0.0
1

INPUTBOX
10
577
272
637
SIMULATION_STEPS_OFFLINE_OPTIMIZATION
1000.0
1
0
Number

MONITOR
1135
32
1320
77
total_area_avoidance_steps
total_area_avoidance_steps
17
1
11

INPUTBOX
10
430
239
490
experiment-folder
0.0
1
0
Number

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
0
@#$#@#$#@

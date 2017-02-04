module View exposing (..)

import Char exposing (fromCode, toCode)
import Debug
import Dict
import Html exposing (div, hr, program)
import Html.Attributes as Hattr exposing (class, id, style)
import Html.Events as Hevent
import List
import Set
import String
import Svg exposing (Svg, polygon, g)
import Svg.Attributes as Sattr exposing (x, y, stroke, fill, points)
import Svg.Events as Sevent exposing (onClick, onMouseOut, onMouseOver)

import Hexagons.Hex as Hex exposing (Hex(..))
import Hexagons.Layout as HexLayout exposing (hexToPoint, polygonCorners)
import Hexagons.Map as HexMap

import Types exposing (..)
import Rest exposing (..)

-- VIEW
rootView model =
  div [ class "row" ]
    [ div [ class "large-8 columns" ]
          [ Svg.svg [ Sattr.class "havannah-board" 
                    ]
                    ((havannahBoard model) ++ (coordinatesText model))
          ]
    , div [ class "large-4 columns" ]
          [ Html.p [] [ Html.text (gameStateText model) ]
          , Html.hr [] []
          , movesList model
          ]
    ]

movesList model =
  let
    header =
      Html.thead 
        []
        [ Html.tr []
                  [
                  ]
        ]

    body = 
      Html.tbody
        []
        [ Html.tr []
                  []
        ]
                
  in
    Html.table 
      [ class "hover" ]
      [ header
      , body
      ]

hoveredText model =
  case model.hoverCell of
    Nothing ->
      ""

    Just hex ->
      toString (HexMap.hashHex hex)

gameStateText model =
  case model.gameState of 
    P1Wins ->
      "Player 1 wins"

    P2Wins ->
      "Player 2 wins"

    Draw ->
      "Draw"

    Aborted ->
      "Game aborted"

    NotStarted ->
      ""

    Started ->
      if model.turn == Player1 then
         "Player 1's turn"
      else
        "Player 2's turn"

havannahBoard model =
  let
    gHexs = Dict.values model.board
  in
    List.map (gData model) gHexs

-- Given the model and a hex cell, produce the corresponding
-- g element suitable for use within an SVG 
gData model hex =
  let
    hash = HexMap.hashHex hex

    cornerPoints = 
      polygonCorners model.layout hex

    (centerX, centerY) = hexToPoint model.layout hex

    (letter, number) = cartesianHex model.boardSize hash

    isHover = model.hoverCell == Just hex

    fillColor =
      if Set.member hash model.p1Moves then
        model.p1Color
      else if Set.member hash model.p2Moves then
        model.p2Color
      else if model.turn == Player1 && isHover then
        model.p1Color
      else if model.turn == Player2 && isHover then
        model.p2Color
      else
        --"Gold"
        "Aliceblue"

    fillOpacity =
      if isHover then
        "0.5"
      else
        "1.0"

    isMove = Set.member hash model.p1Moves || 
             Set.member hash model.p2Moves

    gClass =
      let
        qualifier =
          case model.gameState of
            Started ->
              if isMove then "taken" else "available"

            _ ->
              "no-game-play"

      in 
        "hex-cell-" ++ qualifier
   
    clickHandlers = 
      if model.gameState /= Started then
         []
      else
        [ onClick (PlaceCell hex)
        , onMouseOver (HoverCell hex)
        , onMouseOut UnhoverCell
        ]

  in
    g ([ Sattr.class gClass
       , Sattr.id (idString hex)
       ] 
       ++ 
       clickHandlers
      )

      [ polygon [ points (pointsString cornerPoints)
                , fill fillColor
                ]
                []
      ]

coordinatesText model =
  let 
    size = if model.boardSize == Ten then 9 else 7

    letterCorner = (-size, size, 0)

    numberCorner = (size, 0, -size)

    letterEdges = 
      List.filter isLetterEdge model.edges

    numberEdges =
      List.filter isNumberEdge model.edges

    isLetterEdge edge =
      List.any (areNeighbors model.board letterCorner) (Set.toList edge)

    isNumberEdge edge =
      List.any (areNeighbors model.board numberCorner) (Set.toList edge)

    letterHexHash = [ (0, size, -size) 
                    , (-size, size, 0)
                    , (-size, 0, size)
                    ]
                    ++
                    (List.concatMap Set.toList letterEdges)
                    
    numberHexHash = [ (0, size, -size)
                    , (size, 0, -size)
                    , (size, -size, 0)
                    ]
                    ++
                    (List.concatMap Set.toList numberEdges)

    defaultHex = IntCubeHex (0, 0, 0)

    letterHex = List.map (HexMap.getHex defaultHex model.board) letterHexHash

    numberHex = List.map (HexMap.getHex defaultHex model.board) numberHexHash

  in
    (List.map (letterText model) letterHex)
    ++
    (List.map (numberText model) numberHex)
    
letterText model hex =
  let
    (letter, _) = 
      cartesianHex model.boardSize (HexMap.hashHex hex)

    (x, y) = 
      HexLayout.hexToPoint model.layout hex

    edgeLength = 
      if model.boardSize == Ten then
         9
      else
        7

    xOffset =
      if (Char.toCode letter) - (Char.toCode 'A') >= edgeLength then
        23
      else
        20

    yOffset = 
      if (Char.toCode letter) - (Char.toCode 'A') >= edgeLength then
         5
      else
        15

  in
    g [ Sattr.class "coordinate" ]
      [ Svg.text_
          [ Sattr.stroke "none"
          , Sattr.fill "black"
          , Sattr.x (toString <| x - xOffset)
          , Sattr.y (toString <| y + yOffset)
          , Sattr.textAnchor "end"
          ]
          [ Svg.text (String.fromChar letter) ]
      ]

numberText model hex =
  let
    (_, number) = 
      cartesianHex model.boardSize (HexMap.hashHex hex)

    (x, y) = 
      HexLayout.hexToPoint model.layout hex

    edgeLength = 
      if model.boardSize == Ten then
         9
      else
        7

    xOffset =
      if number > edgeLength then
        23
      else
        20

    yOffset = 
      if number > edgeLength then
         5
      else
        15

  in
    g [ Sattr.class "coordinate" ]
      [ Svg.text_
          [ Sattr.stroke "none"
          , Sattr.fill "black"
          , Sattr.x (toString <| x + xOffset)
          , Sattr.y (toString <| y + yOffset)
          , Sattr.textAnchor "start"
          ]
          [ Svg.text (toString number) ]
      ]

-- HELPERS
printPoint (x, y) = (toString x) ++ "," ++ (toString y)

pointsString = 
  String.join " " << List.map printPoint

idString hex =
  let 
    (q, r, s) = HexMap.hashHex hex
  in
    String.join "," <| List.map (toString) [q, r, s]

cartesianHex : BoardSize -> HexMap.Hash -> (Char, Int)
cartesianHex boardSize (x, y, z) =
  let
      size = if boardSize == Ten then 9 else 7

      startLetterZ = -size

      startNumY = size

      startCharCode = toCode 'A'
  in
    ( fromCode (z + startCharCode + size)
    , -y + size + 1
    )

cartesianString (letter, number) =
  (String.fromChar letter) ++ (toString number)

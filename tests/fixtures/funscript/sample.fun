// FunScript fixture: bindings, schemas, matching, effects, and pipelines.
// TODO: keep this file in sync with the language examples.

import { Array, Console } from "effect"

export schema Shape =
  | Circle(radius: Number)
  | Rect(width: Number, height: Number)

export name: String = "Ada"
export isActive = true
export result = (10 + 20) * 2 - 5
export check = name #= "Ada" and result #! 0

export describe = (shape: Shape) =>
  match shape
    | Circle(r) when r > 10 => "large circle {r}"
    | Circle(r) => "circle {r}"
    | Rect(w, h) => "rectangle {w}x{h}"
    | _ => "unknown shape"

export main =
  effect {
    _ <- Console.log("FunScript fixture")
    [Circle(2), Rect(3, 4)]
    |> Array.map(describe)
    |> Array.join(" | ")
    |> Console.log
  }

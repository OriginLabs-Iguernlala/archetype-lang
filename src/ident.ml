(* -------------------------------------------------------------------- *)
open Core

type ident = string
[@@deriving show]

(* -------------------------------------------------------------------- *)
let cmp_ident = (String.compare : ident -> ident -> int)

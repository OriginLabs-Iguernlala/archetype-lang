open Mltree

let pp_str fmt str =
  Format.fprintf fmt "%s" str

let pp_id = pp_str

(* -------------------------------------------------------------------------- *)
let pp_list sep pp =
  Format.pp_print_list
    ~pp_sep:(fun fmt () -> Format.fprintf fmt "%(%)" sep)
    pp

let pp_option pp fmt (x : 'a option) =
  match x with None -> () | Some x -> pp fmt x

let pp_enclose pre post pp fmt x =
  Format.fprintf fmt "%(%)%a%(%)" pre pp x post

let pp_prefix pre pp fmt x =
  pp_enclose pre "" pp fmt x

let pp_postfix post pp fmt x =
  pp_enclose "" post pp fmt x
(* -------------------------------------------------------------------------- *)
type assoc  = Left | Right | NonAssoc
type pos    = PLeft | PRight | PInfix | PNone

let e_in            =  (10,  NonAssoc) (* in  *)
let e_to            =  (10,  NonAssoc) (* to  *)
let e_arrow         =  (12,  NonAssoc) (* ->  *)
let e_match         =  (14,  Right)    (* match *)
let e_if            =  (14,  Right)    (* if  *)
let e_then          =  (14,  Right)    (* then *)
let e_else          =  (16,  Right)    (* else *)
let e_comma         =  (20,  Left)     (* ,   *)
let e_semi_colon    =  (20,  Left)     (* ;   *)
let e_colon         =  (25,  NonAssoc) (* :   *)
let e_and           =  (60,  Left)     (* and *)
let e_or            =  (70,  Left)     (* or  *)
let e_equal         =  (80,  NonAssoc) (* =   *)
let e_nequal        =  (80,  NonAssoc) (* <>  *)
let e_gt            =  (90,  Left)     (* >   *)
let e_ge            =  (90,  Left)     (* >=  *)
let e_lt            =  (90,  Left)     (* <   *)
let e_le            =  (90,  Left)     (* <=  *)
let e_plus          =  (100, Left)     (* +   *)
let e_minus         =  (100, Left)     (* -   *)
let e_mult          =  (110, Left)     (* *   *)
let e_div           =  (110, Left)     (* /   *)
let e_modulo        =  (110, Left)     (* %   *)
let e_not           =  (115, Right)    (* not *)
let e_dot           =  (120, Right)    (* .   *)
let e_app           =  (140, NonAssoc) (* f ()  *)
let e_for           =  (140, NonAssoc) (* for in .  *)

let e_default       =  (0, NonAssoc)   (* ?  *)
let e_simple       =   (200, NonAssoc)   (* ?  *)

let get_prec_from_operator (op : operator) =
  match op with
  | `Bin And     -> e_and
  | `Bin Or      -> e_or
  | `Bin Equal   -> e_equal
  | `Bin Nequal  -> e_nequal
  | `Bin Gt      -> e_gt
  | `Bin Ge      -> e_ge
  | `Bin Lt      -> e_lt
  | `Bin Le      -> e_le
  | `Bin Plus    -> e_plus
  | `Bin Minus   -> e_minus
  | `Bin Mult    -> e_mult
  | `Bin Div     -> e_div
  | `Bin Modulo  -> e_modulo
  | `Una Not     -> e_not
  | `Una Uminus  -> e_minus
  | `Una Uplus   -> e_plus

let pp_if c pp_true pp_false fmt x =
  match c with
  | true  -> pp_true fmt x
  | false -> pp_false fmt x

let pp_maybe c tx pp fmt x =
  pp_if c (tx pp) pp fmt x

let pp_paren pp fmt x =
  pp_enclose "(" ")" pp fmt x

let pp_maybe_paren c pp =
  pp_maybe c pp_paren pp

let maybe_paren outer inner pos pp =
  let c =
    match (outer, inner, pos) with
    | ((o, Right), (i, Right), PLeft) when o >= i -> true
    | ((o, Right), (i, NonAssoc), _)  when o >= i -> true
    | ((o, Right), (i, Left), _)      when o >= i -> true
    | ((o, Left),  (i, Left), _)      when o >= i -> true
    | ((o, NonAssoc), (i, _), _)      when o >= i -> true
    | _ -> false
  in pp_maybe_paren c pp

(* -------------------------------------------------------------------------- *)

let type_basic_to_string = function
  | Tunit      -> "unit"
  | Tbool      -> "bool"
  | Tint       -> "int"
  | Tnat       -> "nat"
  | Ttez       -> "tez"
  | Tstring    -> "string"
  | Tbytes     -> "bytes"
  | Ttimestamp -> "timestamp"
  | Tkey       -> "key"
  | Tkey_hash  -> "key_hash"
  | Tsignature -> "signature"
  | Toperation -> "operation"
  | Taddress   -> "address"

let rec pp_type fmt = function
  | Tbasic b ->
    Format.fprintf fmt "%s"
      (type_basic_to_string b)

  | Ttuple l ->
    let pp fmt l =
      Format.fprintf fmt "%a"
        (pp_list " * " pp_type) l
    in
    pp fmt l

  | Tlist t ->
    let pp fmt t =
      Format.fprintf fmt "%a list"
        pp_type t
    in
    pp fmt t

  | Tmap (k, v) ->
    let pp fmt (k, v) =
      Format.fprintf fmt "(%a, %a) map"
        pp_type k
        pp_type v
    in
    pp fmt (k, v)

  | Tcontract ->
    Format.fprintf fmt "contract"

  | Toption t ->
    let pp fmt t =
      Format.fprintf fmt "%a option"
        pp_type t
    in
    pp fmt t

  | Tlocal str ->
    Format.fprintf fmt "%s" str

let pp_literal fmt = function
  | Lint    n -> Format.fprintf fmt "%s" (Big_int.string_of_big_int n)
  | Lbool   b -> Format.fprintf fmt "%s" (if b then "true" else "false")
  | Lstring s -> Format.fprintf fmt "\"%s\"" s
  | Lraw    s -> Format.fprintf fmt "%s" s

let binop_to_string = function
  | And    -> "&&"
  | Or     -> "||"
  | Equal  -> "="
  | Nequal -> "<>"
  | Gt     -> ">"
  | Ge     -> ">="
  | Lt     -> "<"
  | Le     -> "<="
  | Plus   -> "+"
  | Minus  -> "-"
  | Mult   -> "*"
  | Div    -> "/"
  | Modulo -> "%"

let unaop_to_string = function
  | Not    -> "not"
  | Uminus -> "-"
  | Uplus  -> "+"

let pp_pattern fmt = function
  | Pid id ->
    Format.fprintf fmt "| %a"
      pp_id id
  | Pwild ->
    Format.fprintf fmt "| _"

let rec pp_expr outer pos fmt = function
  | Eletin (l, b) ->
    let pp_letin_item fmt (l, e) =
      Format.fprintf fmt "let %a : %a = %a in@\n"
        (pp_list ", " pp_id) (List.map fst l)
        pp_type (Ttuple (List.map snd l))
        (pp_expr e_equal PRight) e
    in
    Format.fprintf fmt "@[%a%a@]"
      (pp_list "@\n" pp_letin_item) l
      (pp_expr e_in PRight) b

  | Eif (cond, then_, else_) ->
    let pp fmt (cond, then_, else_) =
      Format.fprintf fmt "@[if %a@ then %a@ else %a@ @]"
        (pp_expr e_if PRight) cond
        (pp_expr e_then PRight) then_
        (pp_expr e_else PRight) else_
    in
    (maybe_paren outer e_default pos pp) fmt (cond, then_, else_)

  | Ematchwith (e, l) ->
    let pp fmt (e, l) =
      Format.fprintf fmt "@[match %a with@\n%a@]"
        (pp_expr e_match PRight) e
        (pp_list "@\n" (fun fmt (pts, e) ->
             Format.fprintf fmt "%a -> %a"
               (pp_list " " pp_pattern) pts
               (pp_expr e_arrow PRight) e)) l
    in
    (maybe_paren outer e_default pos pp) fmt (e, l)

  | Eapp (id, args) ->

    let pp fmt (id, args) =
      Format.fprintf fmt "%a %a"
        pp_id id
        (pp_list " " (pp_expr e_app PInfix)) args
    in
    (maybe_paren outer e_app pos pp) fmt (id, args)

  | Ebin (op, l, r) ->

    let prec_op = get_prec_from_operator (`Bin op) in
    let pp fmt (op, l, r) =
      Format.fprintf fmt "%a %s %a"
        (pp_expr prec_op PLeft) l
        (binop_to_string op)
        (pp_expr prec_op PRight) r
    in
    (maybe_paren outer prec_op pos pp) fmt (op, l, r)

  | Eunary (op, e) ->

    let prec_op = get_prec_from_operator (`Una op) in
    let pp fmt (op, e) =
      Format.fprintf fmt "%s %a"
        (unaop_to_string op)
        (pp_expr prec_op PRight) e
    in

    (maybe_paren outer prec_op pos pp) fmt (op, e)

  | Erecord (w, l) ->
    let pp fmt (w, l) =
      let pp_item fmt (id, e) =
        Format.fprintf fmt "%a = %a"
          pp_id id
          (pp_expr e_equal PRight) e in
      Format.fprintf fmt "{ %a %a }"
        (pp_option (pp_postfix " with " pp_id)) w
        (pp_list "; " pp_item) l
    in
    (maybe_paren outer e_simple pos pp) fmt (w, l)

  | Etuple l ->

    let pp fmt l =
      Format.fprintf fmt "(%a)"
        (pp_list ", " (pp_expr e_comma PInfix)) l
    in
    (maybe_paren outer e_comma pos pp) fmt l

  | Evar s ->
    Format.fprintf fmt "%s" s

  | Econtainer l ->
    let pp fmt l =
      Format.fprintf fmt "[%a]"
        (pp_list "; " (pp_expr e_semi_colon PInfix)) l
    in
    (maybe_paren outer e_simple pos pp) fmt l

  | Elit l ->
    pp_literal fmt l

  | Edot (e, id) ->

    let pp fmt (e, id) =
      Format.fprintf fmt "%a.%a"
        (pp_expr e_dot PLeft) e
        pp_id id
    in
    (maybe_paren outer e_dot pos pp) fmt (e, id)

let pp_struct_type fmt (s : type_struct) =
  let pp_item fmt ((id, t) : (ident * type_ option)) =
    Format.fprintf fmt "| %a%a"
      pp_id id
      (pp_option (pp_prefix " of " pp_type)) t
  in
  Format.fprintf fmt "type %a =@\n@[<v 2>  %a@]@."
    pp_id s.name
    (pp_list "@\n" pp_item) s.values

let pp_sstruct fmt (s : struct_struct) =
  let pp_field fmt ((id, t) : (ident * type_)) =
    Format.fprintf fmt "%a: %a;"
      pp_id id
      pp_type t
  in
  Format.fprintf fmt "type %a = {@\n@[<v 2>  %a@]@\n}@."
    pp_id s.name
    (pp_list "@\n" pp_field) s.fields

let pp_fun fmt (s : fun_struct) =
  let pp_fun_node fmt = function
    | Init  -> Format.fprintf fmt "%%init"
    | Entry -> Format.fprintf fmt "%%entry"
    | None  -> Format.fprintf fmt ""
  in
  let pp_arg fmt (id, t) =
    match t with
    | Tbasic Tunit -> Format.fprintf fmt "()"
    | _ ->
      Format.fprintf fmt "(%a : %a)"
        pp_id id
        pp_type t
  in
  Format.fprintf fmt "let%a %a %a =@\n@[  %a@]@."
    pp_fun_node s.node
    pp_id s.name
    (pp_list " " pp_arg) s.args
    (pp_expr e_equal PRight) s.body

let pp_decl fmt = function
  | Dtype s   -> pp_struct_type fmt s
  | Dstruct s -> pp_sstruct fmt s
  | Dfun s    -> pp_fun fmt s

let pp_tree fmt tree =
  Format.fprintf fmt "%a@."
    (pp_list "@\n" pp_decl) tree.decls

(* -------------------------------------------------------------------------- *)
let string_of__of_pp pp x =
  Format.asprintf "%a@." pp x

let show_tree (x : tree) = string_of__of_pp pp_tree x
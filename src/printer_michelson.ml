open Tools
open Printer_tools
open Michelson

let rec pp_type fmt (t : type_) =
  let pp_annot fmt a = Format.fprintf fmt " %%%a" pp_str a in
  let pp_annot_opt fmt _ = (pp_option pp_annot) fmt t.annotation in
  let pp_simple_a str =
    match t.annotation with
    | Some a -> Format.fprintf fmt "(%a%a)" pp_str str pp_annot a
    | _ -> pp_str fmt str
  in
  match t.node with
  | Tkey                -> pp_simple_a "key"
  | Tunit               -> pp_simple_a "unit"
  | Tsignature          -> pp_simple_a "signature"
  | Toption    t        -> Format.fprintf fmt "(option%a %a)"     pp_annot_opt () pp_type t
  | Tlist      t        -> Format.fprintf fmt "(list%a %a)"       pp_annot_opt () pp_type t
  | Tset       t        -> Format.fprintf fmt "(set%a %a)"        pp_annot_opt () pp_type t
  | Toperation          -> pp_simple_a "operation"
  | Tcontract  t        -> Format.fprintf fmt "(contract%a %a)"   pp_annot_opt () pp_type t
  | Tpair      (lt, rt) -> Format.fprintf fmt "(pair%a %a %a)"    pp_annot_opt () pp_type lt  pp_type rt
  | Tor        (lt, rt) -> Format.fprintf fmt "(or%a %a %a)"      pp_annot_opt () pp_type lt  pp_type rt
  | Tlambda    (at, rt) -> Format.fprintf fmt "(lambda%a %a %a)"  pp_annot_opt () pp_type at  pp_type rt
  | Tmap       (kt, vt) -> Format.fprintf fmt "(map%a %a %a)"     pp_annot_opt () pp_type kt  pp_type vt
  | Tbig_map   (kt, vt) -> Format.fprintf fmt "(big_map%a %a %a)" pp_annot_opt () pp_type kt  pp_type vt
  | Tchain_id           -> pp_simple_a "chain_id"
  | Tint                -> pp_simple_a "int"
  | Tnat                -> pp_simple_a "nat"
  | Tstring             -> pp_simple_a "string"
  | Tbytes              -> pp_simple_a "bytes"
  | Tmutez              -> pp_simple_a "mutez"
  | Tbool               -> pp_simple_a "bool"
  | Tkey_hash           -> pp_simple_a "key_hash"
  | Ttimestamp          -> pp_simple_a "timestamp"
  | Taddress            -> pp_simple_a "address"

let rec pp_pretty_type fmt (t : type_) =
  match t.node with
  | Toption    t        -> Format.fprintf fmt "option_%a"     pp_pretty_type t
  | Tlist      t        -> Format.fprintf fmt "list_%a"       pp_pretty_type t
  | Tset       t        -> Format.fprintf fmt "set_%a"        pp_pretty_type t
  | Tcontract  t        -> Format.fprintf fmt "contract_%a"   pp_pretty_type t
  | Tpair      (lt, rt) -> Format.fprintf fmt "pair_%a_%a"    pp_pretty_type lt  pp_pretty_type rt
  | Tor        (lt, rt) -> Format.fprintf fmt "or_%a_%a"      pp_pretty_type lt  pp_pretty_type rt
  | Tlambda    (at, rt) -> Format.fprintf fmt "lambda_%a_%a"  pp_pretty_type at  pp_pretty_type rt
  | Tmap       (kt, vt) -> Format.fprintf fmt "map_%a_%a"     pp_pretty_type kt  pp_pretty_type vt
  | Tbig_map   (kt, vt) -> Format.fprintf fmt "big_map_%a_%a" pp_pretty_type kt  pp_pretty_type vt
  | _ -> pp_type fmt t

let rec pp_data fmt (d : data) =
  match d with
  | Dint    v       -> pp_big_int fmt v
  | Dstring v       -> Format.fprintf fmt "\"%s\"" v
  | Dbytes  v       -> Format.fprintf fmt "0x%s"     v
  | Dunit           -> Format.fprintf fmt "Unit"
  | Dtrue           -> Format.fprintf fmt "True"
  | Dfalse          -> Format.fprintf fmt "False"
  | Dpair  (ld, rd) -> Format.fprintf fmt "(Pair %a %a)" pp_data ld pp_data rd
  | Dleft   d       -> Format.fprintf fmt "(Left %a)"      pp_data d
  | Dright  d       -> Format.fprintf fmt "(Right %a)"     pp_data d
  | Dsome   d       -> Format.fprintf fmt "(Some %a)"      pp_data d
  | Dnone           -> Format.fprintf fmt "None"
  | Dlist l         -> Format.fprintf fmt "{ %a }" (pp_list "; " pp_data) l
  | Dplist l        -> Format.fprintf fmt "{ %a }" (pp_list "; " (fun fmt (x, y) -> Format.fprintf fmt "Elt %a %a" pp_data x pp_data y)) l

let rec pp_code fmt (i : code) =
  let pp s = Format.fprintf fmt s in
  let pp_annot = pp_option (fun fmt -> Format.fprintf fmt " %s") in
  let pp_arg fmt i =
    match i with
    | 0 | 1 -> ()
    | _ -> Format.fprintf fmt " %i" i
  in
  let pp_arg2 fmt i =
    match i with
    | 0 -> ()
    | _ -> Format.fprintf fmt " %i" i
  in
  let fs fmt = Format.fprintf fmt "{ @[%a@] }" (pp_list ";@\n" pp_code) in
  let fsl fmt = Format.fprintf fmt "{ %a }" (pp_list "; " pp_code) in
  match i with
  | SEQ l                -> fs fmt l
  | DROP i               -> pp "DROP%a" pp_arg i
  | DUP                  -> pp "DUP"
  | SWAP                 -> pp "SWAP"
  | DIG i                -> pp "DIG%a" pp_arg2 i
  | DUG i                -> pp "DUG%a" pp_arg2 i
  | PUSH (t, d)          -> pp "PUSH %a %a" pp_type t pp_data d
  | SOME                 -> pp "SOME"
  | NONE t               -> pp "NONE %a" pp_type t
  | UNIT                 -> pp "UNIT"
  | IF_NONE (ti, ei)     -> pp "IF_NONE@\n  @[%a@]@\n  @[%a@]" fs ti fs ei
  | PAIR                 -> pp "PAIR"
  | CAR                  -> pp "CAR"
  | CDR                  -> pp "CDR"
  | UNPAIR               -> pp "UNPAIR"
  | LEFT  t              -> pp "LEFT %a" pp_type t
  | RIGHT t              -> pp "RIGHT %a" pp_type t
  | IF_LEFT (ti, ei)     -> pp "IF_LEFT@\n  @[%a@]@\n  @[%a@]" fs ti fs ei
  | NIL t                -> pp "NIL %a" pp_type t
  | CONS                 -> pp "CONS"
  | IF_CONS (ti, ei)     -> pp "IF_CONS@\n  @[%a@]@\n  @[%a@]" fs ti fs ei
  | SIZE                 -> pp "SIZE"
  | EMPTY_SET     t      -> pp "EMPTY_SET %a" pp_type t
  | EMPTY_MAP     (k, v) -> pp "EMPTY_MAP %a %a" pp_type k pp_type v
  | EMPTY_BIG_MAP (k, v) -> pp "EMPTY_BIG_MAP %a %a" pp_type k pp_type v
  | MAP  is              -> pp "MAP %a" fs is
  | ITER is              -> pp "ITER %a" fs is
  | MEM                  -> pp "MEM"
  | GET                  -> pp "GET"
  | UPDATE               -> pp "UPDATE"
  | IF (ti, ei)          -> pp "IF@\n  @[%a@]@\n  @[%a@]" fs ti fs ei
  | LOOP is              -> pp "LOOP %a" fs is
  | LOOP_LEFT is         -> pp "LOOP_LEFT %a" fs is
  | LAMBDA (at, rt, is)  -> pp "LAMBDA@\n  @[%a@]@\n  @[%a@]@\n  @[%a@]" pp_type at pp_type rt fs is
  | EXEC                 -> pp "EXEC"
  | DIP (i, is)          -> pp "DIP%a %a" pp_arg i fsl is
  | FAILWITH             -> pp "FAILWITH"
  | CAST                 -> pp "CAST"
  | RENAME               -> pp "RENAME"
  | CONCAT               -> pp "CONCAT"
  | SLICE                -> pp "SLICE"
  | PACK                 -> pp "PACK"
  | UNPACK t             -> pp "UNPACK %a" pp_type t
  | ADD                  -> pp "ADD"
  | SUB                  -> pp "SUB"
  | MUL                  -> pp "MUL"
  | EDIV                 -> pp "EDIV"
  | ABS                  -> pp "ABS"
  | ISNAT                -> pp "ISNAT"
  | INT                  -> pp "INT"
  | NEG                  -> pp "NEG"
  | LSL                  -> pp "LSL"
  | LSR                  -> pp "LSR"
  | OR                   -> pp "OR"
  | AND                  -> pp "AND"
  | XOR                  -> pp "XOR"
  | NOT                  -> pp "NOT"
  | COMPARE              -> pp "COMPARE"
  | EQ                   -> pp "EQ"
  | NEQ                  -> pp "NEQ"
  | LT                   -> pp "LT"
  | GT                   -> pp "GT"
  | LE                   -> pp "LE"
  | GE                   -> pp "GE"
  | ASSERT_EQ            -> pp "ASSERT_EQ"
  | ASSERT_NEQ           -> pp "ASSERT_NEQ"
  | ASSERT_LT            -> pp "ASSERT_LT"
  | ASSERT_GT            -> pp "ASSERT_GT"
  | ASSERT_LE            -> pp "ASSERT_LE"
  | ASSERT_GE            -> pp "ASSERT_GE"
  | SELF                 -> pp "SELF"
  | CONTRACT (t, a)      -> pp "CONTRACT%a %a" pp_annot a pp_type t
  | TRANSFER_TOKENS      -> pp "TRANSFER_TOKENS"
  | SET_DELEGATE         -> pp "SET_DELEGATE"
  | CREATE_ACCOUNT       -> pp "CREATE_ACCOUNT"
  | CREATE_CONTRACT  is  -> pp "CREATE_CONTRACT %a" fs is
  | IMPLICIT_ACCOUNT     -> pp "IMPLICIT_ACCOUNT"
  | NOW                  -> pp "NOW"
  | AMOUNT               -> pp "AMOUNT"
  | BALANCE              -> pp "BALANCE"
  | CHECK_SIGNATURE      -> pp "CHECK_SIGNATURE"
  | BLAKE2B              -> pp "BLAKE2B"
  | SHA256               -> pp "SHA256"
  | SHA512               -> pp "SHA512"
  | HASH_KEY             -> pp "HASH_KEY"
  | STEPS_TO_QUOTA       -> pp "STEPS_TO_QUOTA"
  | SOURCE               -> pp "SOURCE"
  | SENDER               -> pp "SENDER"
  | ADDRESS              -> pp "ADDRESS"
  | CHAIN_ID             -> pp "CHAIN_ID"

let pp_id fmt i = Format.fprintf fmt "%s" i

let rec pp_instruction fmt (i : instruction) =
  let pp s = Format.fprintf fmt s in
  let f = pp_instruction in
  match i with
  | Iseq [] -> pp "{ }"
  | Iseq l -> (pp_list ";@\n" f) fmt l
  | IletIn (id, v, b) -> Format.fprintf fmt "let %a = %a in@\n  @[%a@]" pp_id id f v f b
  | Ivar id -> pp_id fmt id
  | Icall (id, args)       -> Format.fprintf fmt "%a(%a)" pp_id id (pp_list ", " f) args
  | Iassign (id, v)        -> Format.fprintf fmt "%a := @[%a@]" pp_id id f v
  | IassignRec (id, n, v)  -> Format.fprintf fmt "%a[%i] := @[%a@]" pp_id id n f v
  | Iif (c, t, e)          -> pp "if (%a)@\nthen @[%a@]@\nelse @[%a@]" f c f t f e
  | Iifnone (v, t, fe, id) -> pp "if_none (%a)@\nthen @[%a@]@\nelse @[fun %s -> %a@]" f v f t id f (fe(Ivar id))
  | Iifcons (v, t, e)      -> pp "if_cons (%a)@\nthen @[%a@]@\nelse @[%a@]" f v f t f e
  | Iwhile (c, b)          -> pp "while (%a) do@\n  @[%a@]@\ndone" f c f b
  | Iiter (ids, c, b)      -> pp "iter %a on (%a) do@\n  @[%a@]@\ndone" (pp_list ", " pp_id) ids f c f b
  | Izop op -> begin
      match op with
      | Znow               -> pp_id fmt "now"
      | Zamount            -> pp_id fmt "amount"
      | Zbalance           -> pp_id fmt "balance"
      | Zsource            -> pp_id fmt "source"
      | Zsender            -> pp_id fmt "sender"
      | Zaddress           -> pp_id fmt "address"
      | Zchain_id          -> pp_id fmt "chain_id"
      | Zself_address      -> pp_id fmt "self_address"
      | Znone t            -> Format.fprintf fmt "none(%a)" pp_type t
    end
  | Iunop (op, e) -> begin
      match op with
      | Ucar        -> pp "car(%a)"          f e
      | Ucdr        -> pp "cdr(%a)"          f e
      | Uneg        -> pp "neg(%a)"          f e
      | Uint        -> pp "int(%a)"          f e
      | Unot        -> pp "not(%a)"          f e
      | Uabs        -> pp "abs(%a)"          f e
      | Uisnat      -> pp "isnat(%a)"        f e
      | Usome       -> pp "some(%a)"         f e
      | Usize       -> pp "size(%a)"         f e
      | Upack       -> pp "pack(%a)"         f e
      | Uunpack t   -> pp "unpack<%a>(%a)"   pp_type t f e
      | Ublake2b    -> pp "blake2b(%a)"      f e
      | Usha256     -> pp "sha256(%a)"       f e
      | Usha512     -> pp "sha512(%a)"       f e
      | Uhash_key   -> pp "hash_key(%a)"     f e
      | Ufail       -> pp "fail(%a)"         f e
      | Ucontract (t, a) -> pp "contract%a<%a>(%a)" (pp_option (fun fmt x -> Format.fprintf fmt "%%%a" pp_id x)) a pp_type t f e
    end
  | Ibinop (op, lhs, rhs) -> begin
      match op with
      | Badd       -> pp "(%a) + (%a)"       f lhs f rhs
      | Bsub       -> pp "(%a) - (%a)"       f lhs f rhs
      | Bmul       -> pp "(%a) * (%a)"       f lhs f rhs
      | Bediv      -> pp "(%a) / (%a)"       f lhs f rhs
      | Blsl       -> pp "(%a) << (%a)"      f lhs f rhs
      | Blsr       -> pp "(%a) >> (%a)"      f lhs f rhs
      | Bor        -> pp "(%a) or (%a)"      f lhs f rhs
      | Band       -> pp "(%a) and (%a)"     f lhs f rhs
      | Bxor       -> pp "(%a) xor (%a)"     f lhs f rhs
      | Bcompare   -> pp "compare (%a, %a)"  f lhs f rhs
      | Bget       -> pp "get(%a, %a)"       f lhs f rhs
      | Bmem       -> pp "mem(%a, %a)"       f lhs f rhs
      | Bconcat    -> pp "concat(%a, %a)"    f lhs f rhs
      | Bcons      -> pp "cons(%a, %a)"      f lhs f rhs
      | Bpair      -> pp "pair(%a, %a)"      f lhs f rhs
    end
  | Iterop (op, a1, a2, a3) -> begin
      match op with
      | Tcheck_signature -> pp "check_signature(%a, %a, %a)" f a1 f a2 f a3
      | Tslice           -> pp "slice(%a, %a, %a)"           f a1 f a2 f a3
      | Tupdate          -> pp "update(%a, %a, %a)"          f a1 f a2 f a3
      | Ttransfer_tokens -> pp "transfer_tokens(%a, %a, %a)" f a1 f a2 f a3
    end
  | Icompare (op, lhs, rhs) -> begin
      match op with
      | Ceq        -> pp "(%a) = (%a)"       f lhs f rhs
      | Cne        -> pp "(%a) <> (%a)"      f lhs f rhs
      | Clt        -> pp "(%a) < (%a)"       f lhs f rhs
      | Cgt        -> pp "(%a) > (%a)"       f lhs f rhs
      | Cle        -> pp "(%a) <= (%a)"      f lhs f rhs
      | Cge        -> pp "(%a) >= (%a)"      f lhs f rhs
    end
  | Iconst (t, e)     -> pp "const(%a : %a)" pp_data e pp_type t
  | Iset (t, l)       -> pp "set<%a>[%a]" pp_type t (pp_list "; " f) l
  | Ilist (t, l)      -> pp "list<%a>[%a]" pp_type t (pp_list "; " f) l
  | Imap (k, v, l)    -> pp "map<%a, %a>[%a]" pp_type k pp_type v (pp_list "; " (fun fmt (vk, vv) -> Format.fprintf fmt "%a : %a" f vk f vv)) l
  | Irecord l         -> pp "record[%a]" (pp_list "; " f) l
  | Imichelson (a, c, v) -> pp "michelson [%a] (%a) {%a}" (pp_list "; " pp_id) v (pp_list "; " f) a pp_code c

let pp_func fmt (f : func) =
  Format.fprintf fmt "function %s %a@\n "
    f.name
    (fun fmt x ->
       match x with
       | Concrete (args, body) ->
         Format.fprintf fmt "(%a) : %a{@\n  @[%a@]@\n}"
           (pp_list ", " (fun fmt (id, t) ->
                Format.fprintf fmt "%s : %a" id pp_type t)) args
           pp_type f.tret
           pp_instruction body
       | Abstract _ ->
         Format.fprintf fmt "(%a) : %a = abstract" pp_type f.targ pp_type f.tret
    ) f.body

let pp_entry fmt (e : entry) =
  Format.fprintf fmt "entry %s (%a) {@\n  @[%a@]@\n}@\n "
    e.name
    (pp_list ", " (fun fmt (id, t) -> Format.fprintf fmt "%s : %a" id pp_type t)) e.args
    pp_instruction e.body

let pp_ir fmt (ir : ir) =
  let pp a = Format.fprintf fmt a in
  Format.fprintf fmt "storage_type: %a@\n@\n" pp_type ir.storage_type;
  Format.fprintf fmt "storage_data: %a@\n@\n" pp_data ir.storage_data;
  (pp_list "@\n@\n" pp_func) fmt ir.funs;
  (if (List.is_not_empty ir.funs) then (pp "@\n"));
  (pp_list "@\n@\n" pp_entry) fmt ir.entries

let pp_michelson fmt (m : michelson) =
  Format.fprintf fmt
    "{@\n  \
     storage %a;@\n  \
     parameter %a;@\n  \
     code %a;@\n\
     }"
    pp_type m.storage
    pp_type m.parameter
    pp_code m.code

(* -------------------------------------------------------------------------- *)

let string_of__of_pp pp x =
  Format.asprintf "%a@." pp x

let show_pretty_type x = string_of__of_pp pp_pretty_type x
let show_model x = string_of__of_pp pp_michelson x
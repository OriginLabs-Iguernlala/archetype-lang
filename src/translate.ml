open Location
open Model
open ParseTree

exception ModelError of string * Location.t

let get_name_model (pt : ParseTree.model) : lident =
  let loc = loc pt in
  let ptu = Location.unloc pt in
  match ptu with
  | Mmodel decls ->
    (let res = List.fold_left (fun acc i -> (
           let decl_u = Location.unloc i in
           match decl_u with
           | Dmodel id -> (match acc with
               | None -> Some (unloc id)
               | _ -> raise (ModelError ("only one name can be set to model.", loc)))
           | _ -> acc)) None decls
     in
      match res with
      | Some id -> (dumloc id)
      | _ -> raise (ModelError ("no name for model found.", loc)))
  | _ -> raise (ModelError ("only ParseTree.model can be translated into Model.model.", loc))

let to_rexpr e =
  let loc = loc e in
  let value = unloc e in
  match value with
  | Eliteral l -> (
      match l with
      | Laddress a -> Raddress a
      | _ -> raise (ModelError ("only address is supported", loc)) )
  | Eterm (None, id) -> Rrole id
  | Eterm (Some a, id) -> Rasset (a, id)
  (*  | Eapp ({pldesc = {pldesc = Eop}, args, _}) ->*)
  | _ -> raise (ModelError ("wrong type for ", loc))

let get_roles decls =
  List.fold_left ( fun acc i ->
      (let loc = loc i in
       let decl_u = Location.unloc i in
       match decl_u with
       | Drole (id, dv, _) ->
         (mkloc loc {name = id; default = BatOption.map to_rexpr dv})::acc
       | _ -> acc)
    ) [] decls

let mk_pterm e = (* TODO *)
  let loc = loc e in
  let v = unloc e in
  mkloc loc
    (match v with
     | Ebreak -> Pbreak
     | _ -> Pvar (dumloc "TODO") )

let mk_bval e =
  let loc = loc e in
  let v = unloc e in
  mkloc loc
    (match v with
     | Eliteral l -> (
         match l with
         | Lnumber b -> BVint b
         | Lfloat s -> BVfloat s
         | Laddress s -> BVaddress s
         | Lstring s -> BVstring s
         | Lbool b -> BVbool b
         | Lduration s -> BVduration s
         | Ldate s -> BVdate s)
     | _ -> raise (ModelError ("mk_bval: wrong type for ", loc)))

let builtin_type str =
  match str with
  | "int" -> Some VTint
  | "uint" -> Some VTuint
  | "date" -> Some VTdate
  | "duration" -> Some VTduration
  | "string" -> Some VTstring
  | "address" -> Some VTaddress
  | "tez" -> Some (VTcurrency (Tez, None))
  | "mtez" -> Some (VTcurrency (Mutez, None))
  | _ -> None

let container_to_container (c : ParseTree.container) : Model.container =
  match c with
  | Collection -> Collection
  | Queue -> Queue
  | Stack -> Stack
  | Set -> Set
  | Partition -> Partition

let rec mk_ptyp e =
  let loc, v = deloc e in
  mkloc loc
    (match v with
     | Tref v -> (let b = builtin_type (unloc v) in
                  match b with
                  | Some u -> Tbuiltin u
                  | None -> Tasset v)
     | Tcontainer (t, container) -> Tcontainer ((mk_ptyp t), container_to_container container)
     | Tapp (f, v) -> Tapp (mk_ptyp f, mk_ptyp v)
     | Ttuple l -> Ttuple (List.map mk_ptyp l)
     | _ -> raise (ModelError ("mk_ptyp: unsupported type ", loc)))
(*   | Tvset (vs, t) -> *)


let lident_to_ptyp id = mkloc (loc id) (Tasset id) (* FIXME: complete with other type *)

let mk_decl_for_var loc ((id, typ, dv) : (lident * lident * expr option)) =
  mkloc loc {
    name = id;
    typ = Some (lident_to_ptyp typ);
    default = BatOption.map mk_bval dv;
  }

let mk_decl loc ((id, typ, dv) : (lident * type_t * expr option)) =
  mkloc loc {
    name = id;
    typ = Some (mk_ptyp typ);
    default = BatOption.map mk_bval dv;
  }

let get_variables decls =
  List.fold_left ( fun acc i ->
      (let loc = loc i in
       let decl_u = Location.unloc i in
       match decl_u with
       | Dconstant (id, typ, dv, _) ->
         mkloc loc {decl = mk_decl_for_var loc (id, typ, dv); constant = true }::acc
       | Dvariable (id, typ, _, dv, _) ->
         mkloc loc {decl = mk_decl_for_var loc (id, typ, dv); constant = false }::acc
       | _ -> acc)
    ) [] decls

let get_asset_key opts =
  let default = Location.dumloc "_id" in
  match opts with
  | None -> default
  | Some opts ->
    (let id = (List.fold_left (fun acc i ->
         match i with
         | AOidentifiedby id -> Some id
         | _ -> acc) None opts) in
     match id with
     | Some i -> i
  | _ -> default)

let is_asset_role opts =
  match opts with
  | None -> false
  | Some opts -> List.fold_left (fun acc i ->
         match i with
         | AOasrole -> true
         | _ -> acc) false opts

let get_asset_fields fields =
    match fields with
      | None -> []
      | Some fields -> (List.fold_left (fun acc i ->
          let loc, v = deloc i in
          match v with
          | Ffield (id, typ, dv, _) -> mk_decl loc (id, typ, dv)::acc
        ) [] fields)

let mk_asset loc ((id, fields, _cs, opts, init, _ops) : (lident * field list option * expr list option * asset_option list option * expr option * asset_operation option)) =
  mkloc loc {
    name = id;
    args = get_asset_fields fields;
    key = get_asset_key opts;
    sort = None;
    role = is_asset_role opts;
    init = BatOption.map mk_pterm init;
    preds = None;
  }

let get_assets decls =
  List.fold_left ( fun acc i ->
      (let loc = loc i in
       let decl_u = Location.unloc i in
       match decl_u with
       | Dasset (id, fields, cs, opts, init, ops) -> mk_asset loc (id, fields, cs, opts, init, ops)::acc
       | _ -> acc)
    ) [] decls

let get_enums decls =
  List.fold_left ( fun acc i ->
      (let loc = loc i in
       let decl_u = Location.unloc i in
       match decl_u with
       | Denum (name, list) ->
         mkloc loc {name = name; vals = list }::acc
       | _ -> acc)
    ) [] decls

let parseTree_to_model (pt : ParseTree.model) : Model.model =
  let ptu = Location.unloc pt in
  let decls = match ptu with
  | Mmodel decls -> decls
  | _ -> [] in

  mkloc (loc pt) {
    name          = get_name_model pt;
    roles         = get_roles decls;
    variables     = get_variables decls;
    assets        = get_assets decls;
    functions     = [];
    transactions  = [];
    stmachines    = [];
    enums         = get_enums decls;
    spec          = None;
  }

/* parser */
%{
  open ParseTree
  open Location

  let emit_error loc =
    let str : string = "syntax error" in
    let pos : Position.t list = [Tools.location_to_position loc] in
    Error.error_alert pos str (fun _ -> ())

  let emit_error_msg loc msg =
    let str : string = "syntax error: " ^ msg in
    let pos : Position.t list = [Tools.location_to_position loc] in
    Error.error_alert pos str (fun _ -> ())

  let dummy_action_properties = {
      calledby        = None;
      accept_transfer = false;
      require         = None;
      failif          = None;
      functions       = [];
      spec            = None;
    }

  let rec split_seq e =
    match unloc e with
    | Eseq (a, b) -> (split_seq a) @ (split_seq b)
    | _ -> [e]

%}

%token ACCEPT_TRANSFER
%token ACTION
%token AND
%token ANDEQUAL
%token ARCHETYPE
%token ASSERT
%token ASSET
%token AT
%token AT_ADD
%token AT_REMOVE
%token AT_UPDATE
%token BACK
%token BREAK
%token BUT
%token BY
%token CALLED
%token COLLECTION
%token COLON
%token COLONCOLON
%token COLONEQUAL
%token COMMA
%token CONSTANT
%token CONTRACT
%token DEFINITION
%token DIV
%token DIVEQUAL
%token DOT
%token EFFECT
%token ELSE
%token END
%token ENUM
%token EOF
%token EQUAL
%token EQUIV
%token EXISTS
%token EXTENSION
%token FAILIF
%token FALSE
%token FOR
%token FORALL
%token FROM
%token FUNCTION
%token GREATER
%token GREATEREQUAL
%token IDENTIFIED
%token IF
%token IMPLY
%token IN
%token INITIAL
%token INITIALIZED
%token INSTANCE
%token INVARIANT
%token ITER
%token LBRACE
%token LBRACKET
%token LBRACKETPERCENT
%token LEMMA
%token LESS
%token LESSEQUAL
%token LET
%token LPAREN
%token MATCH
%token MINUS
%token MINUSEQUAL
%token MULT
%token MULTEQUAL
%token NAMESPACE
%token NEQUAL
%token NONE
%token NOT
%token OF
%token ON
%token OPTION
%token OR
%token OREQUAL
%token OTHERWISE
%token PARTITION
%token PERCENT
%token PERCENTRBRACKET
%token PIPE
%token PLUS
%token PLUSEQUAL
%token POSTCONDITION
%token PREDICATE
%token RBRACE
%token RBRACKET
%token RECORD
%token REF
%token REQUIRE
%token RETURN
%token RPAREN
%token SECURITY
%token SEMI_COLON
%token SOME
%token SORTED
%token SPECIFICATION
%token STATES
%token THEN
%token THEOREM
%token TO
%token TRANSFER
%token TRANSITION
%token TRUE
%token UNDERSCORE
%token VARIABLE
%token WHEN
%token WITH

%token INVALID_EXPR
%token INVALID_DECL
%token INVALID_EFFECT

%token <string> IDENT
%token <string> STRING
%token <Big_int.big_int> NUMBER
%token <Big_int.big_int * Big_int.big_int> RATIONAL
%token <Big_int.big_int> MTZ
%token <string> ADDRESS
%token <string> DURATION
%token <string> DATE

%nonassoc prec_transfer

%nonassoc TO IN

%left COMMA SEMI_COLON

%right OTHERWISE
%right THEN ELSE

%nonassoc COLONEQUAL PLUSEQUAL MINUSEQUAL MULTEQUAL DIVEQUAL ANDEQUAL OREQUAL

%right IMPLY
%nonassoc EQUIV

%left OR
%left AND

%nonassoc EQUAL NEQUAL
%nonassoc prec_order
%left GREATER GREATEREQUAL LESS LESSEQUAL

%left PLUS MINUS
%left MULT DIV PERCENT

%right NOT

%type <ParseTree.archetype> main
%type <ParseTree.expr> start_expr

%start main start_expr

%%

%inline loc(X):
| x=X {
    { pldesc = x;
      plloc  = Location.make $startpos $endpos; }
      }

snl(separator, X):
  x = X { [ x ] }
| x = X; separator { [ x ] }
| x = X; separator; xs = snl(separator, X) { x :: xs }

snl2(separator, X):
  x = X; separator; y = X { [ x; y ] }
| x = X; separator; xs = snl2(separator, X) { x :: xs }

%inline paren(X):
| LPAREN x=X RPAREN { x }

%inline braced(X):
| LBRACE x=X RBRACE { x }

%inline bracket(X):
| LBRACKET x=X RBRACKET { x }

start_expr:
| x=expr EOF { x }

main:
 | x=loc(archetype_r) { x }

archetype_r:
 | x=implementation_archetype EOF { x }
 | x=archetype_extension      EOF { x }

archetype_extension:
 | ARCHETYPE EXTENSION id=ident xs=paren(declarations) EQUAL ys=braced(declarations)
     { Mextension (id, xs, ys) }

implementation_archetype:
 | x=declarations { Marchetype x }

%inline declarations:
| xs=declaration+ { xs }

%inline declaration:
| e=loc(declaration_r) { e }

declaration_r:
 | x=archetype          { x }
 | x=constant           { x }
 | x=variable           { x }
 | x=instance           { x }
 | x=enum               { x }
 | x=asset              { x }
 | x=action             { x }
 | x=transition         { x }
 | x=dextension         { x }
 | x=namespace          { x }
 | x=contract           { x }
 | x=function_decl      { x }
 | x=specification_decl { x }
 | x=security_decl      { x }
 | INVALID_DECL         { Dinvalid }

archetype:
| ARCHETYPE exts=option(extensions) x=ident { Darchetype (x, exts) }

vc_decl(X):
| X exts=extensions? x=ident t=type_t z=option(value_options) dv=default_value?
    { (x, t, z, dv, exts) }

constant:
  | x=vc_decl(CONSTANT) { let x, t, z, dv, exts = x in
                          Dvariable (x, t, dv, z, VKconstant, exts) }

variable:
  | x=vc_decl(VARIABLE) { let x, t, z, dv, exts = x in
                          Dvariable (x, t, dv, z, VKvariable, exts) }

instance:
  | INSTANCE exts=option(extensions) v=ident OF t=ident dv=default_value
    { Dinstance (v, t, dv, exts) }

%inline value_options:
| xs=value_option+ { xs }

value_option:
| x=from_value { VOfrom x }
| x=to_value   { VOto x }

%inline default_value:
| EQUAL x=expr { x }

%inline from_value:
| FROM x=ident { x }

%inline to_value:
| TO x=ident { x }

dextension:
| PERCENT x=ident arg=option(simple_expr) { Dextension (x, arg) }

%inline extensions:
| xs=extension+ { xs }

%inline extension:
| e=loc(extension_r) { e }

extension_r:
| LBRACKETPERCENT x=ident arg=option(simple_expr) PERCENTRBRACKET { Eextension (x, arg) }

namespace:
| NAMESPACE x=ident xs=braced(declarations) { Dnamespace (x, xs) }

contract:
| CONTRACT exts=option(extensions) x=ident EQUAL
    xs=braced(signatures)
         { Dcontract (x, xs, exts) }

%inline signatures:
| xs=signature+ { xs }

signature:
| ACTION x=ident                { Ssignature (x, []) }
| ACTION x=ident COLON xs=types { Ssignature (x, xs) }

%inline fun_body:
| e=expr { (None, e) }
| s=specification_fun
      EFFECT e=braced(expr)
        { (Some s, e) }

%inline function_gen:
 | FUNCTION id=ident xs=function_args
     r=function_return? EQUAL LBRACE b=fun_body RBRACE {
  let (s, e) = b in
  {
    name  = id;
    args  = xs;
    ret_t = r;
    spec = s;
    body  = e;
  }
}

function_item:
| f=loc(function_gen)
    { f }

function_decl:
| f=function_gen
    { Dfunction f }

%inline spec_predicate:
| PREDICATE id=ident xs=function_args EQUAL e=braced(expr) { Vpredicate (id, xs, e) }

%inline spec_definition:
| DEFINITION id=ident EQUAL LBRACE a=ident COLON t=type_t PIPE e=expr RBRACE { Vdefinition (id, t, a, e) }

%inline spec_lemma:
| LEMMA id=ident EQUAL x=braced(expr) { Vlemma (id, x) }

%inline spec_theorem:
| THEOREM id=ident EQUAL x=braced(expr) { Vtheorem (id, x) }

%inline spec_variable:
| VARIABLE id=ident t=type_t dv=default_value? { Vvariable (id, t, dv) }

%inline spec_effect:
| EFFECT e=braced(expr) { Veffect e }

%inline invars:
| INVARIANT FOR id=ident xs=braced(expr) { (id, split_seq xs) }

%inline spec_body:
| e=expr xs=invars*  { (e, xs) }

%inline spec_assert:
| ASSERT id=ident EQUAL sp=braced(spec_body)
    { let e, xs = sp in Vassert (id, e, xs) }

%inline spec_postcondition:
| POSTCONDITION id=ident EQUAL sp=braced(spec_body)
    { let e, xs = sp in Vpostcondition (id, e, xs) }

spec_items:
| ds=loc(spec_definition)*
  ps=loc(spec_predicate)*
  xs=loc(spec_lemma)*
  ts=loc(spec_theorem)*
  vs=loc(spec_variable)*
  es=loc(spec_effect)*
  bs=loc(spec_assert)*
  ss=loc(spec_postcondition)*
   { ds @ ps @ xs @ ts @ vs @ es @ bs @ ss }

%inline specification:
| SPECIFICATION exts=option(extensions) LBRACE
    xs=spec_items RBRACE
        { (xs, exts) }

| SPECIFICATION exts=option(extensions) LBRACE
    xs=label_exprs RBRACE
        { let ll = List.map (fun x ->
            let loc, (id, e) = Location.deloc x in
            let lbl = Tools.Option.get id in
            mkloc loc (Vpostcondition (lbl, e, []))) xs in
            (ll, exts) }

specification_fun:
| x=loc(specification) { x }

specification_decl:
| x=loc(specification)      { Dspecification x }

%inline security_item_unloc:
| lbl=ident COLON id=ident args=security_arg+ SEMI_COLON
    { (lbl, id, args) }

%inline security_item:
| x=loc(security_item_unloc) { x }

security_decl_unloc:
| SECURITY exts=option(extensions) LBRACE
    xs=security_item+ RBRACE
        { (xs, exts) }

security_decl:
| x=loc(security_decl_unloc)      { Dsecurity x }

enum:
| STATES exts=extensions? xs=equal_enum_values
    {Denum (EKstate, (xs, exts))}

| ENUM exts=extensions? x=ident xs=equal_enum_values
    {Denum (EKenum x, (xs, exts))}

equal_enum_values:
| /*nothing*/          { [] }
| EQUAL xs=enum_values { xs }

enum_values:
| /*nothing*/    { [] }
| xs=pipe_idents { xs }

%inline pipe_idents:
| xs=pipe_ident+ { xs }

%inline pipe_ident:
| PIPE x=ident opts=enum_options { (x, opts) }

%inline enum_options:
| /* nothing */    { [] }
| xs=enum_option+ { xs }

enum_option:
| INITIAL              { EOinitial }
| WITH xs=braced(label_exprs) { EOspecification (xs) }

types:
| xs=separated_nonempty_list(COMMA, type_t) { xs }

%inline type_t:
| e=loc(type_r) { e }

type_r:
| x=type_s xs=type_tuples { Ttuple (x::xs) }
| x=type_s_unloc          { x }

%inline type_s:
| x=loc(type_s_unloc)     { x }

type_s_unloc:
| x=ident                 { Tref x }
| x=ident RECORD          { Tasset x }
| x=type_s c=container    { Tcontainer (x, c) }
| x=type_s OPTION         { Toption x }
| x=paren(type_r)         { x }

%inline type_tuples:
| xs=type_tuple+ { xs }

%inline type_tuple:
| MULT x=type_s { x }

%inline container:
| COLLECTION { Collection }
| PARTITION  { Partition }

asset:
| ASSET exts=extensions? ops=bracket(asset_operation)? x=ident opts=asset_options?
        fields=asset_fields?
                 apo=asset_post_options
                       {
                         let fs = match fields with | None -> [] | Some x -> x in
                         let os = match opts with | None -> [] | Some x -> x in
                         Dasset (x, fs, os, apo, ops, exts) }

asset_post_option:
| WITH STATES x=ident           { APOstates x }
| WITH xs=braced(label_exprs)   { APOconstraints (xs) }
| INITIALIZED BY e=simple_expr  { APOinit e }

%inline asset_post_options:
 | xs=asset_post_option* { xs }

%inline asset_fields:
| EQUAL fields=braced(fields) { fields }

%inline asset_options:
| xs=asset_option+ { xs }

asset_option:
| IDENTIFIED BY x=ident { AOidentifiedby x }
| SORTED BY x=ident     { AOsortedby x }

%inline fields:
| xs=terminated(field, SEMI_COLON)+ { xs }

field_r:
| x=ident exts=option(extensions)
      COLON y=type_t boption(REF)
          dv=default_value?
    { Ffield (x, y, dv, exts) }

%inline field:
| f=loc(field_r) { f }

%inline ident:
| x=loc(IDENT) { x }

action:
  ACTION exts=option(extensions) x=ident
    args=function_args xs=transitems_eq
      { let a, b = xs in Daction (x, args, a, b, exts) }

transition_to_item:
| TO x=ident y=require_value? z=with_effect? { (x, y, z) }

%inline transitions:
 | xs=transition_to_item+ { xs }

on_value:
 | ON x=ident COLON y=ident { x, y }

transition:
  TRANSITION exts=option(extensions) x=ident
    args=function_args on=on_value? FROM f=expr EQUAL LBRACE xs=action_properties trs=transitions RBRACE
      { Dtransition (x, args, on, f, xs, trs, exts) }

%inline transitems_eq:
| { (dummy_action_properties, None) }
| EQUAL LBRACE xs=action_properties e=effect? RBRACE { (xs, e) }

action_properties:
  sp=specification_fun? cb=calledby? at=boption(ACCEPT_TRANSFER) cs=require? fi=failif? fs=function_item*
  {
    {
      spec            = sp;
      calledby        = cb;
      accept_transfer = at;
      require         = cs;
      failif          = fi;
      functions       = fs;
    }
  }

calledby:
 | CALLED BY exts=option(extensions) x=expr { (x, exts) }

require:
 | REQUIRE exts=option(extensions) xs=braced(label_exprs_or_not)
       { (xs, exts) }

failif:
 | FAILIF exts=option(extensions) xs=braced(label_exprs_or_not)
       { (xs, exts) }

%inline require_value:
| WHEN exts=option(extensions) e=braced(expr) { (e, exts) }

%inline with_effect:
| WITH e=effect { e }

effect:
 | EFFECT exts=option(extensions) e=braced(expr) { (e, exts) }
 | INVALID_EFFECT                                { (mkloc Location.dummy Einvalid, None) }

%inline function_return:
 | COLON ty=type_t { ty }

%inline function_args:
 |                   { [] }
 | xs=function_arg+  { xs }

%inline function_arg:
 | LPAREN id=ident exts=option(extensions)
     COLON ty=type_t RPAREN
       { (id, ty, exts) }

%inline assignment_operator_record:
 | EQUAL                    { ValueAssign }
 | op=assignment_operator_extra { op }

%inline assignment_operator_expr:
 | COLONEQUAL               { ValueAssign }
 | op=assignment_operator_extra { op }

%inline assignment_operator_extra:
 | PLUSEQUAL   { PlusAssign }
 | MINUSEQUAL  { MinusAssign }
 | MULTEQUAL   { MultAssign }
 | DIVEQUAL    { DivAssign }
 | ANDEQUAL    { AndAssign }
 | OREQUAL     { OrAssign }

%inline branchs:
 | xs=branch+ { xs }

branch:
 | xs=patterns IMPLY x=expr { (xs, x) }

%inline patterns:
 | xs=loc(pattern)+ { xs }

pattern:
  | PIPE UNDERSCORE { Pwild }
  | PIPE i=ident    { Pref i }

%inline expr:
 | e=loc(expr_r) { e }

%inline ident_typ_q_item:
 | LPAREN ids=ident+ t=quant_kind RPAREN { List.map (fun x -> (x, t)) ids }

ident_typ_q:
 | xs=ident_typ_q_item+ { List.flatten xs }

%inline colon_type_opt:
|                { None }
| COLON t=type_s { Some t }

%inline colon_ident:
|                { None }
| COLON i=ident  { Some i }

%inline otherwise:
|                  { None }
| OTHERWISE o=expr { Some o }

%inline from_expr:
|                { None }
| FROM e=expr    { Some e }

expr_r:
 | q=quantifier id=ident t=quant_kind COMMA y=expr
     { Equantifier (q, id, t, y) }

 | q=quantifier xs=ident_typ_q COMMA y=expr
    {
      (List.fold_right (fun (i, t) acc ->
           let l = loc i in
           mkloc l (Equantifier (q, i, t, acc))) xs y) |> unloc
    }

 | LET i=ident t=colon_type_opt EQUAL e=expr IN y=expr o=otherwise
     { Eletin (i, t, e, y, o) }

 | e1=expr SEMI_COLON e2=expr
     { Eseq (e1, e2) }

 | ASSERT id=ident
     { Eassert id }

 | BREAK
     { Ebreak }

 | FOR lbl=colon_ident LPAREN x=ident IN y=expr RPAREN body=simple_expr
     { Efor (lbl, x, y, body) }

 | ITER lbl=colon_ident LPAREN x=ident a=from_expr TO b=expr RPAREN body=simple_expr
     { Eiter (lbl, x, a, b, body) }

 | IF c=expr THEN t=expr
     { Eif (c, t, None) }

 | IF c=expr THEN t=expr ELSE e=expr
     { Eif (c, t, Some e) }

 | xs=snl2(COMMA, simple_expr)
     { Etuple xs }

 | x=expr op=assignment_operator_expr y=expr
     { Eassign (op, x, y) }

 | TRANSFER back=boption(BACK) x=simple_expr y=ioption(to_value) %prec prec_transfer
     { Etransfer (x, back, y) }

 | REQUIRE x=simple_expr
     { Erequire x }

 | FAILIF x=simple_expr
     { Efailif x }

 | RETURN x=simple_expr
     { Ereturn x }

 | SOME x=simple_expr
     { Eoption (OSome x) }

 | NONE
     { Eoption ONone }

 | x=order_operations %prec prec_order { x }

 | e1=expr op=loc(bin_operator) e2=expr
     { Eapp ( Foperator op, [e1; e2]) }

 | op=loc(un_operator) x=expr
     { Eapp ( Foperator op, [x]) }

 | x=simple_expr_r
     { x }

order_operation:
 | e1=expr op=loc(ord_operator) e2=expr
     { Eapp ( Foperator op, [e1; e2]) }

order_operations:
  | e=order_operation { e }
  | ops=loc(order_operations) op=loc(ordering_operator) e=expr
    {
      match unloc ops with
      | Eapp (Foperator ({pldesc = `Cmp opa; plloc = lo}), [lhs; rhs]) -> Emulticomp (lhs, [mkloc lo opa, rhs; op, e])
      | Emulticomp (a, l) -> Emulticomp (a, l @ [op, e])
      | _ -> assert false
    }

%inline app_args:
 | LPAREN RPAREN         { [] }
 | LPAREN x=expr RPAREN  { [x] }

%inline simple_expr:
 | x=loc(simple_expr_r) { x }

simple_expr_r:

 | MATCH x=expr WITH xs=branchs END { Ematchwith (x, xs) }

 | id=ident a=app_args
     { Eapp ( Fident id, a) }

 | x=simple_expr DOT y=ident
     { Edot (x, y) }

 | x=simple_expr DOT id=ident a=app_args
     { Emethod (x, id, a) }

 | LBRACKET RBRACKET
     { Earray [] }

 | LBRACKET e=expr RBRACKET
     { Earray (split_seq e) }

 | LBRACE xs=separated_nonempty_list(SEMI_COLON, record_item) RBRACE
     { Erecord xs }

 | x=literal
     { Eliteral x }

 | LPAREN
     s=ioption(postfix(ident, COLONCOLON)) x=ident AT l=ident
   RPAREN
     { Eterm (Some l, s, x) }

 | s=ioption(postfix(ident, COLONCOLON)) x=ident
     { Eterm (None, s, x) }

 | INVALID_EXPR
     { Einvalid }

 | x=paren(expr_r)
     { x }

%inline label_exprs:
| l=label_expr+ { l }

%inline label_exprs_or_not:
| /* empty */ { [] }
| l=label_expr+ { l }

%inline label_expr:
| le=loc(label_expr_unloc) { le }

%inline label_expr_unloc:
| id=ident COLON e=expr SEMI_COLON { (Some id, e) }

/*%inline ident_typs:
 | xs=ident+ COLON ty=type_t
     { List.map (fun x -> (x, ty, None)) xs }

 | xs=ident_typ+
     { List.flatten xs }

%inline ident_typ:
 | LPAREN ids=ident+ COLON ty=type_t RPAREN
     { List.map (fun id -> (id, ty, None)) ids }*/

%inline quant_kind:
| COLON t=type_s      { Qtype t }
| IN    e=simple_expr { Qcollection e }

literal:
 | x=NUMBER     { Lnumber   x }
 | x=RATIONAL   { let n, d = x in Lrational (n, d) }
 | x=MTZ        { Lmtz      x }
 | x=STRING     { Lstring   x }
 | x=ADDRESS    { Laddress  x }
 | x=bool_value { Lbool     x }
 | x=DURATION   { Lduration x }
 | x=DATE       { Ldate     x }

%inline bool_value:
 | TRUE  { true }
 | FALSE { false }

record_item:
 | e=simple_expr { (None, e) }
 | id=ident op=assignment_operator_record e=simple_expr
   { (Some (op, id), e) }

%inline quantifier:
 | FORALL { Forall }
 | EXISTS { Exists }

%inline logical_operator:
 | AND   { And }
 | OR    { Or }
 | IMPLY { Imply }
 | EQUIV { Equiv }

%inline comparison_operator:
 | EQUAL        { Equal }
 | NEQUAL       { Nequal }

%inline ordering_operator:
 | LESS         { Lt }
 | LESSEQUAL    { Le }
 | GREATER      { Gt }
 | GREATEREQUAL { Ge }

%inline arithmetic_operator:
 | PLUS    { Plus }
 | MINUS   { Minus }
 | MULT    { Mult }
 | DIV     { Div }
 | PERCENT { Modulo }

%inline unary_operator:
 | PLUS    { Uplus }
 | MINUS   { Uminus }
 | NOT     { Not }

%inline bin_operator:
| op=logical_operator    { `Logical op }
| op=comparison_operator { `Cmp op }
| op=arithmetic_operator { `Arith op }

%inline un_operator:
| op=unary_operator      { `Unary op }

%inline ord_operator:
| op=ordering_operator   { `Cmp op }

%inline asset_operation_enum:
| AT_ADD    { AOadd }
| AT_REMOVE { AOremove }
| AT_UPDATE { AOupdate }

%inline asset_operation:
| xs=asset_operation_enum+ args=option(simple_expr) { AssetOperation (xs, args) }

%inline security_arg:
 | e=loc(security_arg_unloc) { e }

security_arg_unloc:
| id=ident                           { Sident id }
| a=ident DOT b=ident                { Sdot (a, b) }
| xs=bracket(snl2(OR, security_arg)) { Slist xs }
| x=paren(security_arg_ext_unloc)    { x }

security_arg_ext_unloc:
| id=ident xs=security_arg+          { Sapp (id, xs) }
| id=ident BUT arg=security_arg      { Sbut (id, arg) }
| id=ident TO arg=security_arg       { Sto (id, arg) }
| x=security_arg_unloc               { x }

%inline postfix(X, P):
| x=X P { x }

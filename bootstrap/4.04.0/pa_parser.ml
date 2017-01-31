open Asttypes
open Parsetree
open Longident
open Pa_ocaml_prelude
open Pa_ast
open Pa_lexing
type action =
  | Default 
  | Normal of expression 
  | DepSeq of (expression -> expression) * expression option * expression 
let occur id e =
  Iter.do_local_ident := ((fun s  -> if s = id then raise Exit));
  (try
     (match e with
      | Default  -> ()
      | Normal e -> Iter.iter_expression e
      | DepSeq (_,e1,e2) ->
          (Iter.iter_option Iter.iter_expression e1; Iter.iter_expression e2));
     false
   with | Exit  -> true)
  
let find_locate () =
  try let l = Sys.getenv "LOCATE"  in Some (exp_ident Location.none l)
  with | Not_found  -> None 
let mkpatt _loc (id,p) =
  match (p, (find_locate ())) with
  | (None ,_) -> pat_ident _loc id
  | (Some p,None ) -> ppat_alias _loc p id
  | (Some p,Some _) ->
      ppat_alias _loc (loc_pat _loc (Ppat_tuple [loc_pat _loc Ppat_any; p]))
        id
  
let mkpatt' _loc (id,p) =
  match p with | None  -> pat_ident _loc id | Some p -> ppat_alias _loc p id 
let cache_filter = Hashtbl.create 101 
let filter _loc visible r =
  match ((find_locate ()), visible) with
  | (Some f2,true ) ->
      let f =
        exp_fun _loc "x"
          (exp_fun _loc "str"
             (exp_fun _loc "pos"
                (exp_fun _loc "str'"
                   (exp_fun _loc "pos'"
                      (exp_tuple _loc
                         [exp_apply _loc f2
                            [exp_ident _loc "str";
                            exp_ident _loc "pos";
                            exp_ident _loc "str'";
                            exp_ident _loc "pos'"];
                         exp_ident _loc "x"])))))
         in
      (try let res = Hashtbl.find cache_filter (f, r)  in res
       with
       | Not_found  ->
           let res =
             exp_apply _loc (exp_glr_fun _loc "apply_position") [f; r]  in
           (Hashtbl.add cache_filter (f, r) res; res))
  | _ -> r 
let rec build_action _loc occur_loc ids e =
  let e =
    match ((find_locate ()), occur_loc) with
    | (Some locate2,true ) ->
        exp_fun _loc "__loc__start__buf"
          (exp_fun _loc "__loc__start__pos"
             (exp_fun _loc "__loc__end__buf"
                (exp_fun _loc "__loc__end__pos"
                   (loc_expr _loc
                      (Pexp_let
                         (Nonrecursive,
                           [value_binding _loc (pat_ident _loc "_loc")
                              (exp_apply _loc locate2
                                 [exp_ident _loc "__loc__start__buf";
                                 exp_ident _loc "__loc__start__pos";
                                 exp_ident _loc "__loc__end__buf";
                                 exp_ident _loc "__loc__end__pos"])], e))))))
    | _ -> e  in
  List.fold_left
    (fun e  ->
       fun ((id,x),visible)  ->
         match ((find_locate ()), visible) with
         | (Some _,true ) ->
             loc_expr _loc
               (pexp_fun
                  (nolabel, None, (mkpatt _loc (id, x)),
                    (loc_expr _loc
                       (Pexp_let
                          (Nonrecursive,
                            [value_binding _loc
                               (loc_pat _loc
                                  (Ppat_tuple
                                     [loc_pat _loc
                                        (Ppat_var
                                           (id_loc ("_loc_" ^ id) _loc));
                                     loc_pat _loc (Ppat_var (id_loc id _loc))]))
                               (loc_expr _loc
                                  (Pexp_ident (id_loc (Lident id) _loc)))],
                            e)))))
         | _ ->
             loc_expr _loc
               (pexp_fun (nolabel, None, (mkpatt' _loc (id, x)), e))) e
    (List.rev ids)
  
let apply_option _loc opt visible e =
  let fn e f d =
    match d with
    | None  ->
        {
          Parsetree.pexp_desc =
            (Parsetree.Pexp_apply
               ({
                  Parsetree.pexp_desc =
                    (Parsetree.Pexp_ident
                       {
                         Asttypes.txt =
                           (Longident.Ldot ((Longident.Lident "Earley"), f));
                         Asttypes.loc = _loc
                       });
                  Parsetree.pexp_loc = _loc;
                  Parsetree.pexp_attributes = []
                },
                 [(Asttypes.Nolabel,
                    {
                      Parsetree.pexp_desc =
                        (Parsetree.Pexp_construct
                           ({
                              Asttypes.txt = (Longident.Lident "None");
                              Asttypes.loc = _loc
                            }, None));
                      Parsetree.pexp_loc = _loc;
                      Parsetree.pexp_attributes = []
                    });
                 (Asttypes.Nolabel,
                   {
                     Parsetree.pexp_desc =
                       (Parsetree.Pexp_apply
                          ({
                             Parsetree.pexp_desc =
                               (Parsetree.Pexp_ident
                                  {
                                    Asttypes.txt =
                                      (Longident.Ldot
                                         ((Longident.Lident "Earley"),
                                           "apply"));
                                    Asttypes.loc = _loc
                                  });
                             Parsetree.pexp_loc = _loc;
                             Parsetree.pexp_attributes = []
                           },
                            [(Asttypes.Nolabel,
                               {
                                 Parsetree.pexp_desc =
                                   (Parsetree.Pexp_fun
                                      (Asttypes.Nolabel, None,
                                        {
                                          Parsetree.ppat_desc =
                                            (Parsetree.Ppat_var
                                               {
                                                 Asttypes.txt = "x";
                                                 Asttypes.loc = _loc
                                               });
                                          Parsetree.ppat_loc = _loc;
                                          Parsetree.ppat_attributes = []
                                        },
                                        {
                                          Parsetree.pexp_desc =
                                            (Parsetree.Pexp_construct
                                               ({
                                                  Asttypes.txt =
                                                    (Longident.Lident "Some");
                                                  Asttypes.loc = _loc
                                                },
                                                 (Some
                                                    {
                                                      Parsetree.pexp_desc =
                                                        (Parsetree.Pexp_ident
                                                           {
                                                             Asttypes.txt =
                                                               (Longident.Lident
                                                                  "x");
                                                             Asttypes.loc =
                                                               _loc
                                                           });
                                                      Parsetree.pexp_loc =
                                                        _loc;
                                                      Parsetree.pexp_attributes
                                                        = []
                                                    })));
                                          Parsetree.pexp_loc = _loc;
                                          Parsetree.pexp_attributes = []
                                        }));
                                 Parsetree.pexp_loc = _loc;
                                 Parsetree.pexp_attributes = []
                               });
                            (Asttypes.Nolabel, e)]));
                     Parsetree.pexp_loc = _loc;
                     Parsetree.pexp_attributes = []
                   })]));
          Parsetree.pexp_loc = _loc;
          Parsetree.pexp_attributes = []
        }
    | Some d ->
        {
          Parsetree.pexp_desc =
            (Parsetree.Pexp_apply
               ({
                  Parsetree.pexp_desc =
                    (Parsetree.Pexp_ident
                       {
                         Asttypes.txt =
                           (Longident.Ldot ((Longident.Lident "Earley"), f));
                         Asttypes.loc = _loc
                       });
                  Parsetree.pexp_loc = _loc;
                  Parsetree.pexp_attributes = []
                }, [(Asttypes.Nolabel, d); (Asttypes.Nolabel, e)]));
          Parsetree.pexp_loc = _loc;
          Parsetree.pexp_attributes = []
        }
     in
  let gn e f d =
    match d with
    | None  ->
        {
          Parsetree.pexp_desc =
            (Parsetree.Pexp_apply
               ({
                  Parsetree.pexp_desc =
                    (Parsetree.Pexp_ident
                       {
                         Asttypes.txt =
                           (Longident.Ldot
                              ((Longident.Lident "Earley"), "apply"));
                         Asttypes.loc = _loc
                       });
                  Parsetree.pexp_loc = _loc;
                  Parsetree.pexp_attributes = []
                },
                 [(Asttypes.Nolabel,
                    {
                      Parsetree.pexp_desc =
                        (Parsetree.Pexp_ident
                           {
                             Asttypes.txt =
                               (Longident.Ldot
                                  ((Longident.Lident "List"), "rev"));
                             Asttypes.loc = _loc
                           });
                      Parsetree.pexp_loc = _loc;
                      Parsetree.pexp_attributes = []
                    });
                 (Asttypes.Nolabel,
                   {
                     Parsetree.pexp_desc =
                       (Parsetree.Pexp_apply
                          ({
                             Parsetree.pexp_desc =
                               (Parsetree.Pexp_ident
                                  {
                                    Asttypes.txt =
                                      (Longident.Ldot
                                         ((Longident.Lident "Earley"), f));
                                    Asttypes.loc = _loc
                                  });
                             Parsetree.pexp_loc = _loc;
                             Parsetree.pexp_attributes = []
                           },
                            [(Asttypes.Nolabel,
                               {
                                 Parsetree.pexp_desc =
                                   (Parsetree.Pexp_construct
                                      ({
                                         Asttypes.txt =
                                           (Longident.Lident "[]");
                                         Asttypes.loc = _loc
                                       }, None));
                                 Parsetree.pexp_loc = _loc;
                                 Parsetree.pexp_attributes = []
                               });
                            (Asttypes.Nolabel,
                              {
                                Parsetree.pexp_desc =
                                  (Parsetree.Pexp_apply
                                     ({
                                        Parsetree.pexp_desc =
                                          (Parsetree.Pexp_ident
                                             {
                                               Asttypes.txt =
                                                 (Longident.Ldot
                                                    ((Longident.Lident
                                                        "Earley"), "apply"));
                                               Asttypes.loc = _loc
                                             });
                                        Parsetree.pexp_loc = _loc;
                                        Parsetree.pexp_attributes = []
                                      },
                                       [(Asttypes.Nolabel,
                                          {
                                            Parsetree.pexp_desc =
                                              (Parsetree.Pexp_fun
                                                 (Asttypes.Nolabel, None,
                                                   {
                                                     Parsetree.ppat_desc =
                                                       (Parsetree.Ppat_var
                                                          {
                                                            Asttypes.txt =
                                                              "x";
                                                            Asttypes.loc =
                                                              _loc
                                                          });
                                                     Parsetree.ppat_loc =
                                                       _loc;
                                                     Parsetree.ppat_attributes
                                                       = []
                                                   },
                                                   {
                                                     Parsetree.pexp_desc =
                                                       (Parsetree.Pexp_fun
                                                          (Asttypes.Nolabel,
                                                            None,
                                                            {
                                                              Parsetree.ppat_desc
                                                                =
                                                                (Parsetree.Ppat_var
                                                                   {
                                                                    Asttypes.txt
                                                                    = "y";
                                                                    Asttypes.loc
                                                                    = _loc
                                                                   });
                                                              Parsetree.ppat_loc
                                                                = _loc;
                                                              Parsetree.ppat_attributes
                                                                = []
                                                            },
                                                            {
                                                              Parsetree.pexp_desc
                                                                =
                                                                (Parsetree.Pexp_construct
                                                                   ({
                                                                    Asttypes.txt
                                                                    =
                                                                    (Longident.Lident
                                                                    "::");
                                                                    Asttypes.loc
                                                                    = _loc
                                                                    },
                                                                    (Some
                                                                    {
                                                                    Parsetree.pexp_desc
                                                                    =
                                                                    (Parsetree.Pexp_tuple
                                                                    [
                                                                    {
                                                                    Parsetree.pexp_desc
                                                                    =
                                                                    (Parsetree.Pexp_ident
                                                                    {
                                                                    Asttypes.txt
                                                                    =
                                                                    (Longident.Lident
                                                                    "x");
                                                                    Asttypes.loc
                                                                    = _loc
                                                                    });
                                                                    Parsetree.pexp_loc
                                                                    = _loc;
                                                                    Parsetree.pexp_attributes
                                                                    = []
                                                                    };
                                                                    {
                                                                    Parsetree.pexp_desc
                                                                    =
                                                                    (Parsetree.Pexp_ident
                                                                    {
                                                                    Asttypes.txt
                                                                    =
                                                                    (Longident.Lident
                                                                    "y");
                                                                    Asttypes.loc
                                                                    = _loc
                                                                    });
                                                                    Parsetree.pexp_loc
                                                                    = _loc;
                                                                    Parsetree.pexp_attributes
                                                                    = []
                                                                    }]);
                                                                    Parsetree.pexp_loc
                                                                    = _loc;
                                                                    Parsetree.pexp_attributes
                                                                    = []
                                                                    })));
                                                              Parsetree.pexp_loc
                                                                = _loc;
                                                              Parsetree.pexp_attributes
                                                                = []
                                                            }));
                                                     Parsetree.pexp_loc =
                                                       _loc;
                                                     Parsetree.pexp_attributes
                                                       = []
                                                   }));
                                            Parsetree.pexp_loc = _loc;
                                            Parsetree.pexp_attributes = []
                                          });
                                       (Asttypes.Nolabel, e)]));
                                Parsetree.pexp_loc = _loc;
                                Parsetree.pexp_attributes = []
                              })]));
                     Parsetree.pexp_loc = _loc;
                     Parsetree.pexp_attributes = []
                   })]));
          Parsetree.pexp_loc = _loc;
          Parsetree.pexp_attributes = []
        }
    | Some d ->
        {
          Parsetree.pexp_desc =
            (Parsetree.Pexp_apply
               ({
                  Parsetree.pexp_desc =
                    (Parsetree.Pexp_ident
                       {
                         Asttypes.txt =
                           (Longident.Ldot ((Longident.Lident "Earley"), f));
                         Asttypes.loc = _loc
                       });
                  Parsetree.pexp_loc = _loc;
                  Parsetree.pexp_attributes = []
                }, [(Asttypes.Nolabel, d); (Asttypes.Nolabel, e)]));
          Parsetree.pexp_loc = _loc;
          Parsetree.pexp_attributes = []
        }
     in
  let kn e =
    function
    | None  -> e
    | Some _ ->
        {
          Parsetree.pexp_desc =
            (Parsetree.Pexp_apply
               ({
                  Parsetree.pexp_desc =
                    (Parsetree.Pexp_ident
                       {
                         Asttypes.txt =
                           (Longident.Ldot
                              ((Longident.Lident "Earley"), "greedy"));
                         Asttypes.loc = _loc
                       });
                  Parsetree.pexp_loc = _loc;
                  Parsetree.pexp_attributes = []
                }, [(Asttypes.Nolabel, e)]));
          Parsetree.pexp_loc = _loc;
          Parsetree.pexp_attributes = []
        }
     in
  filter _loc visible
    (match opt with
     | `Once -> e
     | `Option (d,g) -> kn (fn e "option" d) g
     | `Greedy ->
         {
           Parsetree.pexp_desc =
             (Parsetree.Pexp_apply
                ({
                   Parsetree.pexp_desc =
                     (Parsetree.Pexp_ident
                        {
                          Asttypes.txt =
                            (Longident.Ldot
                               ((Longident.Lident "Earley"), "greedy"));
                          Asttypes.loc = _loc
                        });
                   Parsetree.pexp_loc = _loc;
                   Parsetree.pexp_attributes = []
                 }, [(Asttypes.Nolabel, e)]));
           Parsetree.pexp_loc = _loc;
           Parsetree.pexp_attributes = []
         }
     | `Fixpoint (d,g) -> kn (gn e "fixpoint" d) g
     | `Fixpoint1 (d,g) -> kn (gn e "fixpoint1" d) g)
  
let default_action _loc l =
  let l =
    List.filter
      (function | `Normal (("_",_),false ,_,_,_) -> false | _ -> true) l
     in
  let l =
    List.map
      (function
       | `Normal ((id,_),_,_,_,_) -> exp_ident _loc id
       | _ -> assert false) l
     in
  let rec fn =
    function
    | [] -> exp_unit _loc
    | x::[] -> x
    | _::_ as l -> exp_tuple _loc l  in
  fn l 
module Ext(In:Extension) =
  struct
    include In
    let glr_rules = Earley.declare_grammar "glr_rules" 
    let (glr_rule,set_glr_rule) = Earley.grammar_family "glr_rule" 
    let location_name_re = "_loc\\([a-zA-Z0-9_']*\\)" 
    let glr_parser = Earley.declare_grammar "glr_parser" 
    ;;Earley.set_grammar glr_parser
        (Earley.sequence parser_kw glr_rules (fun _default_0  -> fun p  -> p))
    let glr_binding = Earley.declare_grammar "glr_binding" 
    let _ =
      Earley.set_grammar glr_binding
        (Earley.fsequence lident
           (Earley.fsequence
              (Earley.option None (Earley.apply (fun x  -> Some x) pattern))
              (Earley.fsequence
                 (Earley.option None
                    (Earley.apply (fun x  -> Some x)
                       (Earley.sequence (Earley.char ':' ':') typexpr
                          (fun _  -> fun _default_0  -> _default_0))))
                 (Earley.fsequence (Earley.char '=' '=')
                    (Earley.sequence glr_rules
                       (Earley.option []
                          (Earley.sequence and_kw glr_binding
                             (fun _  -> fun _default_0  -> _default_0)))
                       (fun r  ->
                          fun l  ->
                            fun _  ->
                              fun ty  ->
                                fun arg  ->
                                  fun name  -> (name, arg, ty, r) :: l))))))
      
    let glr_struct_item = Earley.declare_grammar "glr_struct_item" 
    ;;Earley.set_grammar glr_struct_item
        (Earley.fsequence_position let_kw
           (Earley.sequence parser_kw glr_binding
              (fun _default_0  ->
                 fun l  ->
                   fun _default_1  ->
                     fun __loc__start__buf  ->
                       fun __loc__start__pos  ->
                         fun __loc__end__buf  ->
                           fun __loc__end__pos  ->
                             let _loc =
                               locate __loc__start__buf __loc__start__pos
                                 __loc__end__buf __loc__end__pos
                                in
                             let rec fn =
                               function
                               | [] -> ([], [])
                               | (name,arg,ty,r)::l ->
                                   let (str1,str2) = fn l  in
                                   let pat_name =
                                     loc_pat _loc
                                       (Ppat_var (id_loc name _loc))
                                      in
                                   let pname =
                                     match (ty, arg) with
                                     | (None ,_) -> pat_name
                                     | (Some ty,None ) ->
                                         let ptyp_ty =
                                           loc_typ _loc (Ptyp_poly ([], ty))
                                            in
                                         loc_pat _loc
                                           (Ppat_constraint
                                              (pat_name, ptyp_ty))
                                     | (Some ty,Some _) ->
                                         let ptyp_ty =
                                           loc_typ _loc (Ptyp_poly ([], ty))
                                            in
                                         loc_pat _loc
                                           (Ppat_constraint
                                              (pat_name,
                                                (loc_typ _loc
                                                   (Ptyp_arrow
                                                      (nolabel,
                                                        (loc_typ _loc
                                                           (Ptyp_var
                                                              "'type_of_arg")),
                                                        ptyp_ty)))))
                                      in
                                   (match arg with
                                    | None  ->
                                        let ddg =
                                          exp_glr_fun _loc "declare_grammar"
                                           in
                                        let strname =
                                          loc_expr _loc
                                            (Pexp_constant
                                               (const_string name))
                                           in
                                        let name =
                                          loc_expr _loc
                                            (Pexp_ident
                                               (id_loc (Lident name) _loc))
                                           in
                                        let e =
                                          loc_expr _loc
                                            (Pexp_apply
                                               (ddg, [(nolabel, strname)]))
                                           in
                                        let l =
                                          value_binding ~attributes:[] _loc
                                            pname e
                                           in
                                        let dsg =
                                          exp_glr_fun _loc "set_grammar"  in
                                        let ev =
                                          loc_expr _loc
                                            (Pexp_apply
                                               (dsg,
                                                 [(nolabel, name);
                                                 (nolabel, r)]))
                                           in
                                        (((loc_str _loc
                                             (Pstr_value (Nonrecursive, [l])))
                                          :: str1),
                                          ((loc_str _loc (pstr_eval ev)) ::
                                          str2))
                                    | Some arg ->
                                        let dgf =
                                          exp_glr_fun _loc "grammar_family"
                                           in
                                        let set_name =
                                          name ^ "__set__grammar"  in
                                        let strname =
                                          loc_expr _loc
                                            (Pexp_constant
                                               (const_string name))
                                           in
                                        let sname =
                                          loc_expr _loc
                                            (Pexp_ident
                                               (id_loc (Lident set_name) _loc))
                                           in
                                        let psname =
                                          loc_pat _loc
                                            (Ppat_var (id_loc set_name _loc))
                                           in
                                        let ptuple =
                                          loc_pat _loc
                                            (Ppat_tuple [pname; psname])
                                           in
                                        let e =
                                          loc_expr _loc
                                            (Pexp_apply
                                               (dgf, [(nolabel, strname)]))
                                           in
                                        let l =
                                          value_binding ~attributes:[] _loc
                                            ptuple e
                                           in
                                        let fam =
                                          loc_expr _loc
                                            (pexp_fun (nolabel, None, arg, r))
                                           in
                                        let ev =
                                          loc_expr _loc
                                            (Pexp_apply
                                               (sname, [(nolabel, fam)]))
                                           in
                                        (((loc_str _loc
                                             (Pstr_value (Nonrecursive, [l])))
                                          :: str1),
                                          ((loc_str _loc (pstr_eval ev)) ::
                                          str2)))
                                in
                             let (str1,str2) = fn l  in str1 @ str2)))
    let extra_prefix_expressions = glr_parser :: extra_prefix_expressions 
    let extra_structure = glr_struct_item :: extra_structure 
    let _ = add_reserved_id "parser" 
    let glr_opt_expr = Earley.declare_grammar "glr_opt_expr" 
    ;;Earley.set_grammar glr_opt_expr
        (Earley.option None
           (Earley.apply (fun x  -> Some x)
              (Earley.fsequence (Earley.char '[' '[')
                 (Earley.sequence expression (Earley.char ']' ']')
                    (fun e  -> fun _  -> fun _  -> e)))))
    let glr_option = Earley.declare_grammar "glr_option" 
    ;;Earley.set_grammar glr_option
        (Earley.alternatives
           [Earley.fsequence (Earley.char '*' '*')
              (Earley.sequence glr_opt_expr
                 (Earley.option None
                    (Earley.apply (fun x  -> Some x) (Earley.char '$' '$')))
                 (fun e  -> fun g  -> fun _  -> `Fixpoint (e, g)));
           Earley.fsequence (Earley.char '+' '+')
             (Earley.sequence glr_opt_expr
                (Earley.option None
                   (Earley.apply (fun x  -> Some x) (Earley.char '$' '$')))
                (fun e  -> fun g  -> fun _  -> `Fixpoint1 (e, g)));
           Earley.fsequence (Earley.char '?' '?')
             (Earley.sequence glr_opt_expr
                (Earley.option None
                   (Earley.apply (fun x  -> Some x) (Earley.char '$' '$')))
                (fun e  -> fun g  -> fun _  -> `Option (e, g)));
           Earley.apply (fun _  -> `Greedy) (Earley.char '$' '$');
           Earley.apply (fun _  -> `Once) (Earley.empty ())])
    let dash =
      Earley.black_box
        (fun str  ->
           fun pos  ->
             let (c,str',pos') = Input.read str pos  in
             if c = '-'
             then
               let (c',_,_) = Input.read str' pos'  in
               (if c' = '>' then Earley.give_up () else ((), str', pos'))
             else Earley.give_up ()) (Charset.singleton '-') false "-"
      
    let glr_sequence = Earley.declare_grammar "glr_sequence" 
    ;;Earley.set_grammar glr_sequence
        (Earley.alternatives
           [Earley.fsequence (Earley.char '{' '{')
              (Earley.sequence glr_rules (Earley.char '}' '}')
                 (fun r  -> fun _  -> fun _  -> (true, r)));
           Earley.sequence_position (Earley.string "EOF" "EOF") glr_opt_expr
             (fun _  ->
                fun opt  ->
                  fun __loc__start__buf  ->
                    fun __loc__start__pos  ->
                      fun __loc__end__buf  ->
                        fun __loc__end__pos  ->
                          let _loc =
                            locate __loc__start__buf __loc__start__pos
                              __loc__end__buf __loc__end__pos
                             in
                          let e =
                            match opt with
                            | None  -> exp_unit _loc
                            | Some e -> e  in
                          ((opt <> None),
                            (exp_apply _loc (exp_glr_fun _loc "eof") [e])));
           Earley.sequence_position (Earley.string "EMPTY" "EMPTY")
             glr_opt_expr
             (fun _  ->
                fun opt  ->
                  fun __loc__start__buf  ->
                    fun __loc__start__pos  ->
                      fun __loc__end__buf  ->
                        fun __loc__end__pos  ->
                          let _loc =
                            locate __loc__start__buf __loc__start__pos
                              __loc__end__buf __loc__end__pos
                             in
                          let e =
                            match opt with
                            | None  -> exp_unit _loc
                            | Some e -> e  in
                          ((opt <> None),
                            (exp_apply _loc (exp_glr_fun _loc "empty") [e])));
           Earley.sequence_position (Earley.string "FAIL" "FAIL")
             (expression_lvl (NoMatch, (next_exp App)))
             (fun _  ->
                fun e  ->
                  fun __loc__start__buf  ->
                    fun __loc__start__pos  ->
                      fun __loc__end__buf  ->
                        fun __loc__end__pos  ->
                          let _loc =
                            locate __loc__start__buf __loc__start__pos
                              __loc__end__buf __loc__end__pos
                             in
                          (false,
                            (exp_apply _loc (exp_glr_fun _loc "fail") [e])));
           Earley.sequence_position (Earley.string "DEBUG" "DEBUG")
             (expression_lvl (NoMatch, (next_exp App)))
             (fun _  ->
                fun e  ->
                  fun __loc__start__buf  ->
                    fun __loc__start__pos  ->
                      fun __loc__end__buf  ->
                        fun __loc__end__pos  ->
                          let _loc =
                            locate __loc__start__buf __loc__start__pos
                              __loc__end__buf __loc__end__pos
                             in
                          (false,
                            (exp_apply _loc (exp_glr_fun _loc "debug") [e])));
           Earley.apply_position
             (fun _  ->
                fun __loc__start__buf  ->
                  fun __loc__start__pos  ->
                    fun __loc__end__buf  ->
                      fun __loc__end__pos  ->
                        let _loc =
                          locate __loc__start__buf __loc__start__pos
                            __loc__end__buf __loc__end__pos
                           in
                        (true, (exp_glr_fun _loc "any")))
             (Earley.string "ANY" "ANY");
           Earley.fsequence_position (Earley.string "CHR" "CHR")
             (Earley.sequence (expression_lvl (NoMatch, (next_exp App)))
                glr_opt_expr
                (fun e  ->
                   fun opt  ->
                     fun _  ->
                       fun __loc__start__buf  ->
                         fun __loc__start__pos  ->
                           fun __loc__end__buf  ->
                             fun __loc__end__pos  ->
                               let _loc =
                                 locate __loc__start__buf __loc__start__pos
                                   __loc__end__buf __loc__end__pos
                                  in
                               let o =
                                 match opt with | None  -> e | Some e -> e
                                  in
                               ((opt <> None),
                                 (exp_apply _loc (exp_glr_fun _loc "char")
                                    [e; o]))));
           Earley.sequence_position
             (Earley.apply_position
                (fun x  ->
                   fun str  ->
                     fun pos  ->
                       fun str'  ->
                         fun pos'  -> ((locate str pos str' pos'), x))
                char_litteral) glr_opt_expr
             (fun c  ->
                let (_loc_c,c) = c  in
                fun opt  ->
                  fun __loc__start__buf  ->
                    fun __loc__start__pos  ->
                      fun __loc__end__buf  ->
                        fun __loc__end__pos  ->
                          let _loc =
                            locate __loc__start__buf __loc__start__pos
                              __loc__end__buf __loc__end__pos
                             in
                          let e = exp_char _loc_c c  in
                          let o = match opt with | None  -> e | Some e -> e
                             in
                          ((opt <> None),
                            (exp_apply _loc (exp_glr_fun _loc "char") [e; o])));
           Earley.fsequence_position (Earley.string "STR" "STR")
             (Earley.sequence (expression_lvl (NoMatch, (next_exp App)))
                glr_opt_expr
                (fun e  ->
                   fun opt  ->
                     fun _  ->
                       fun __loc__start__buf  ->
                         fun __loc__start__pos  ->
                           fun __loc__end__buf  ->
                             fun __loc__end__pos  ->
                               let _loc =
                                 locate __loc__start__buf __loc__start__pos
                                   __loc__end__buf __loc__end__pos
                                  in
                               let o =
                                 match opt with | None  -> e | Some e -> e
                                  in
                               ((opt <> None),
                                 (exp_apply _loc (exp_glr_fun _loc "string")
                                    [e; o]))));
           Earley.sequence_position (Earley.string "ERROR" "ERROR")
             (expression_lvl (NoMatch, (next_exp App)))
             (fun _  ->
                fun e  ->
                  fun __loc__start__buf  ->
                    fun __loc__start__pos  ->
                      fun __loc__end__buf  ->
                        fun __loc__end__pos  ->
                          let _loc =
                            locate __loc__start__buf __loc__start__pos
                              __loc__end__buf __loc__end__pos
                             in
                          (true,
                            {
                              Parsetree.pexp_desc =
                                (Parsetree.Pexp_apply
                                   ({
                                      Parsetree.pexp_desc =
                                        (Parsetree.Pexp_ident
                                           {
                                             Asttypes.txt =
                                               (Longident.Ldot
                                                  ((Longident.Lident "Earley"),
                                                    "error_message"));
                                             Asttypes.loc = _loc
                                           });
                                      Parsetree.pexp_loc = _loc;
                                      Parsetree.pexp_attributes = []
                                    },
                                     [(Asttypes.Nolabel,
                                        {
                                          Parsetree.pexp_desc =
                                            (Parsetree.Pexp_fun
                                               (Asttypes.Nolabel, None,
                                                 {
                                                   Parsetree.ppat_desc =
                                                     (Parsetree.Ppat_construct
                                                        ({
                                                           Asttypes.txt =
                                                             (Longident.Lident
                                                                "()");
                                                           Asttypes.loc =
                                                             _loc
                                                         }, None));
                                                   Parsetree.ppat_loc = _loc;
                                                   Parsetree.ppat_attributes
                                                     = []
                                                 }, e));
                                          Parsetree.pexp_loc = _loc;
                                          Parsetree.pexp_attributes = []
                                        })]));
                              Parsetree.pexp_loc = _loc;
                              Parsetree.pexp_attributes = []
                            }));
           Earley.sequence_position
             (Earley.apply_position
                (fun x  ->
                   fun str  ->
                     fun pos  ->
                       fun str'  ->
                         fun pos'  -> ((locate str pos str' pos'), x))
                string_litteral) glr_opt_expr
             (fun s  ->
                let (_loc_s,s) = s  in
                fun opt  ->
                  fun __loc__start__buf  ->
                    fun __loc__start__pos  ->
                      fun __loc__end__buf  ->
                        fun __loc__end__pos  ->
                          let _loc =
                            locate __loc__start__buf __loc__start__pos
                              __loc__end__buf __loc__end__pos
                             in
                          ((opt <> None),
                            (if (String.length s) = 0 then Earley.give_up ();
                             (let e = exp_string _loc_s s  in
                              let opt =
                                match opt with | None  -> e | Some e -> e  in
                              exp_apply _loc (exp_glr_fun _loc "string")
                                [e; opt]))));
           Earley.fsequence_position (Earley.string "RE" "RE")
             (Earley.sequence (expression_lvl (NoMatch, (next_exp App)))
                glr_opt_expr
                (fun e  ->
                   fun opt  ->
                     fun _  ->
                       fun __loc__start__buf  ->
                         fun __loc__start__pos  ->
                           fun __loc__end__buf  ->
                             fun __loc__end__pos  ->
                               let _loc =
                                 locate __loc__start__buf __loc__start__pos
                                   __loc__end__buf __loc__end__pos
                                  in
                               let opt =
                                 match opt with
                                 | None  ->
                                     exp_apply _loc (exp_ident _loc "groupe")
                                       [exp_int _loc 0]
                                 | Some e -> e  in
                               match e.pexp_desc with
                               | Pexp_ident { txt = Lident id } ->
                                   let id =
                                     let l = String.length id  in
                                     if
                                       (l > 3) &&
                                         ((String.sub id (l - 3) 3) = "_re")
                                     then String.sub id 0 (l - 3)
                                     else id  in
                                   (true,
                                     (exp_lab_apply _loc
                                        (exp_glrstr_fun _loc "regexp")
                                        [((labelled "name"),
                                           (exp_string _loc id));
                                        (nolabel, e);
                                        (nolabel,
                                          (exp_fun _loc "groupe" opt))]))
                               | _ ->
                                   (true,
                                     (exp_apply _loc
                                        (exp_glrstr_fun _loc "regexp")
                                        [e; exp_fun _loc "groupe" opt]))));
           Earley.sequence_position (Earley.string "BLANK" "BLANK")
             glr_opt_expr
             (fun _  ->
                fun opt  ->
                  fun __loc__start__buf  ->
                    fun __loc__start__pos  ->
                      fun __loc__end__buf  ->
                        fun __loc__end__pos  ->
                          let _loc =
                            locate __loc__start__buf __loc__start__pos
                              __loc__end__buf __loc__end__pos
                             in
                          let e =
                            match opt with
                            | None  -> exp_unit _loc
                            | Some e -> e  in
                          ((opt <> None),
                            (exp_apply _loc
                               (exp_glr_fun _loc "with_blank_test") [e])));
           Earley.sequence_position dash glr_opt_expr
             (fun _default_0  ->
                fun opt  ->
                  fun __loc__start__buf  ->
                    fun __loc__start__pos  ->
                      fun __loc__end__buf  ->
                        fun __loc__end__pos  ->
                          let _loc =
                            locate __loc__start__buf __loc__start__pos
                              __loc__end__buf __loc__end__pos
                             in
                          let e =
                            match opt with
                            | None  -> exp_unit _loc
                            | Some e -> e  in
                          ((opt <> None),
                            (exp_apply _loc
                               (exp_glr_fun _loc "no_blank_test") [e])));
           Earley.sequence_position
             (Earley.apply_position
                (fun x  ->
                   fun str  ->
                     fun pos  ->
                       fun str'  ->
                         fun pos'  -> ((locate str pos str' pos'), x))
                regexp_litteral)
             (Earley.apply_position
                (fun x  ->
                   fun str  ->
                     fun pos  ->
                       fun str'  ->
                         fun pos'  -> ((locate str pos str' pos'), x))
                glr_opt_expr)
             (fun s  ->
                let (_loc_s,s) = s  in
                fun opt  ->
                  let (_loc_opt,opt) = opt  in
                  fun __loc__start__buf  ->
                    fun __loc__start__pos  ->
                      fun __loc__end__buf  ->
                        fun __loc__end__pos  ->
                          let _loc =
                            locate __loc__start__buf __loc__start__pos
                              __loc__end__buf __loc__end__pos
                             in
                          let opt =
                            match opt with
                            | None  ->
                                exp_apply _loc (exp_ident _loc "groupe")
                                  [exp_int _loc 0]
                            | Some e -> e  in
                          (true,
                            (exp_lab_apply _loc
                               (exp_glrstr_fun _loc "regexp")
                               [((labelled "name"),
                                  (exp_string _loc_s (String.escaped s)));
                               (nolabel, (exp_string _loc_s s));
                               (nolabel, (exp_fun _loc_opt "groupe" opt))])));
           Earley.apply_position
             (fun id  ->
                let (_loc_id,id) = id  in
                fun __loc__start__buf  ->
                  fun __loc__start__pos  ->
                    fun __loc__end__buf  ->
                      fun __loc__end__pos  ->
                        let _loc =
                          locate __loc__start__buf __loc__start__pos
                            __loc__end__buf __loc__end__pos
                           in
                        (true,
                          (loc_expr _loc (Pexp_ident (id_loc id _loc_id)))))
             (Earley.apply_position
                (fun x  ->
                   fun str  ->
                     fun pos  ->
                       fun str'  ->
                         fun pos'  -> ((locate str pos str' pos'), x))
                value_path);
           Earley.fsequence (Earley.string "(" "(")
             (Earley.sequence expression (Earley.string ")" ")")
                (fun e  -> fun _  -> fun _  -> (true, e)))])
    let glr_ident = Earley.declare_grammar "glr_ident" 
    ;;Earley.set_grammar glr_ident
        (Earley.alternatives
           [Earley.sequence (pattern_lvl (true, ConstrPat))
              (Earley.char ':' ':')
              (fun p  ->
                 fun _  ->
                   match p.ppat_desc with
                   | Ppat_alias (p,{ txt = id }) ->
                       ((Some true), (id, (Some p)))
                   | Ppat_var { txt = id } ->
                       ((Some (id <> "_")), (id, None))
                   | Ppat_any  -> ((Some false), ("_", None))
                   | _ -> ((Some true), ("_", (Some p))));
           Earley.apply (fun _  -> (None, ("_", None))) (Earley.empty ())])
    let fopt x y = match x with | Some x -> x | None  -> y 
    let glr_left_member = Earley.declare_grammar "glr_left_member" 
    ;;Earley.set_grammar glr_left_member
        (Earley.apply List.rev
           (Earley.fixpoint1 []
              (Earley.apply (fun x  -> fun y  -> x :: y)
                 (Earley.fsequence glr_ident
                    (Earley.sequence glr_sequence glr_option
                       (fun ((cst,s) as _default_0)  ->
                          fun opt  ->
                            fun ((cst',id) as _default_1)  ->
                              `Normal
                                (id, (fopt cst' ((opt <> `Once) || cst)), s,
                                  opt)))))))
    let glr_let = Earley.declare_grammar "glr_let" 
    let _ =
      Earley.set_grammar glr_let
        (Earley.alternatives
           [Earley.fsequence_position let_kw
              (Earley.fsequence rec_flag
                 (Earley.fsequence let_binding
                    (Earley.sequence in_kw glr_let
                       (fun _default_0  ->
                          fun l  ->
                            fun lbs  ->
                              fun r  ->
                                fun _default_1  ->
                                  fun __loc__start__buf  ->
                                    fun __loc__start__pos  ->
                                      fun __loc__end__buf  ->
                                        fun __loc__end__pos  ->
                                          let _loc =
                                            locate __loc__start__buf
                                              __loc__start__pos
                                              __loc__end__buf __loc__end__pos
                                             in
                                          fun x  ->
                                            loc_expr _loc
                                              (Pexp_let (r, lbs, (l x)))))));
           Earley.apply (fun _  -> fun x  -> x) (Earley.empty ())])
      
    let glr_cond = Earley.declare_grammar "glr_cond" 
    ;;Earley.set_grammar glr_cond
        (Earley.alternatives
           [Earley.sequence when_kw expression
              (fun _default_0  -> fun e  -> Some e);
           Earley.apply (fun _  -> None) (Earley.empty ())])
    let build_rule (_loc,occur_loc,def,l,condition,action) =
      let (iter,action) =
        match action with
        | Normal a -> (false, a)
        | Default  -> (false, (default_action _loc l))
        | DepSeq (def,cond,a) ->
            (true,
              ((match cond with
                | None  -> def a
                | Some cond ->
                    def
                      (loc_expr _loc
                         (Pexp_ifthenelse
                            (cond, a,
                              (Some
                                 (exp_apply _loc (exp_glr_fun _loc "fail")
                                    [exp_unit _loc]))))))))
         in
      let rec fn first ids l =
        match l with
        | [] -> assert false
        | (`Normal (id,_,e,opt,occur_loc_id))::[] ->
            let e = apply_option _loc opt occur_loc_id e  in
            let f =
              match ((find_locate ()), (first && occur_loc)) with
              | (Some _,true ) -> "apply_position"
              | _ -> "apply"  in
            (match action.pexp_desc with
             | Pexp_ident { txt = Lident id' } when
                 ((fst id) = id') && (f = "apply") -> e
             | _ ->
                 exp_apply _loc (exp_glr_fun _loc f)
                   [build_action _loc occur_loc ((id, occur_loc_id) :: ids)
                      action;
                   e])
        | (`Normal (id,_,e,opt,occur_loc_id))::(`Normal
                                                  (id',_,e',opt',occur_loc_id'))::[]
            ->
            let e = apply_option _loc opt occur_loc_id e  in
            let e' = apply_option _loc opt' occur_loc_id' e'  in
            let f =
              match ((find_locate ()), (first && occur_loc)) with
              | (Some _,true ) -> "sequence_position"
              | _ -> "sequence"  in
            exp_apply _loc (exp_glr_fun _loc f)
              [e;
              e';
              build_action _loc occur_loc ((id, occur_loc_id) ::
                (id', occur_loc_id') :: ids) action]
        | (`Normal (id,_,e,opt,occur_loc_id))::ls ->
            let e = apply_option _loc opt occur_loc_id e  in
            let f =
              match ((find_locate ()), (first && occur_loc)) with
              | (Some _,true ) -> "fsequence_position"
              | _ -> "fsequence"  in
            exp_apply _loc (exp_glr_fun _loc f)
              [e; fn false ((id, occur_loc_id) :: ids) ls]
         in
      let res = fn true [] l  in
      let res =
        if iter then exp_apply _loc (exp_glr_fun _loc "iter") [res] else res
         in
      (def, condition, res) 
    let (glr_action,glr_action__set__grammar) =
      Earley.grammar_family "glr_action" 
    ;;glr_action__set__grammar
        (fun alm  ->
           Earley.alternatives
             [Earley.sequence (Earley.string "->>" "->>") (glr_rule alm)
                (fun _  ->
                   fun r  -> let (a,b,c) = build_rule r  in DepSeq (a, b, c));
             Earley.fsequence arrow_re
               (Earley.sequence
                  (if alm then expression else expression_lvl (Let, Seq))
                  no_semi
                  (fun action  ->
                     fun _default_0  -> fun _default_1  -> Normal action));
             Earley.apply (fun _  -> Default) (Earley.empty ())])
    let _ =
      set_glr_rule
        (fun alm  ->
           Earley.fsequence_position glr_let
             (Earley.fsequence glr_left_member
                (Earley.sequence glr_cond (glr_action alm)
                   (fun condition  ->
                      fun action  ->
                        fun l  ->
                          fun def  ->
                            fun __loc__start__buf  ->
                              fun __loc__start__pos  ->
                                fun __loc__end__buf  ->
                                  fun __loc__end__pos  ->
                                    let _loc =
                                      locate __loc__start__buf
                                        __loc__start__pos __loc__end__buf
                                        __loc__end__pos
                                       in
                                    let l =
                                      fst
                                        (List.fold_right
                                           (fun x  ->
                                              fun (res,i)  ->
                                                match x with
                                                | `Normal (("_",a),true ,c,d)
                                                    ->
                                                    (((`Normal
                                                         ((("_default_" ^
                                                              (string_of_int
                                                                 i)), a),
                                                           true, c, d, false))
                                                      :: res), (i + 1))
                                                | `Normal (id,b,c,d) ->
                                                    let occur_loc_id =
                                                      ((fst id) <> "_") &&
                                                        (occur
                                                           ("_loc_" ^
                                                              (fst id))
                                                           action)
                                                       in
                                                    (((`Normal
                                                         (id, b, c, d,
                                                           occur_loc_id)) ::
                                                      res), i)) l ([], 0))
                                       in
                                    let occur_loc = occur "_loc" action  in
                                    (_loc, occur_loc, def, l, condition,
                                      action)))))
      
    let apply_def_cond _loc arg =
      let (def,cond,e) = build_rule arg  in
      match cond with
      | None  -> def e
      | Some c ->
          def
            (loc_expr _loc
               (Pexp_ifthenelse
                  (c, e,
                    (Some
                       (exp_apply _loc (exp_glr_fun _loc "fail")
                          [exp_unit _loc])))))
      
    let build_alternatives _loc ls =
      match ls with
      | [] -> exp_apply _loc (exp_glr_fun _loc "fail") [exp_unit _loc]
      | r::[] -> apply_def_cond _loc r
      | elt1::elt2::_ ->
          let l =
            List.fold_right
              (fun r  ->
                 fun y  ->
                   let (def,cond,e) = build_rule r  in
                   match cond with
                   | None  -> def (exp_Cons _loc e y)
                   | Some c ->
                       def
                         (loc_expr _loc
                            (Pexp_let
                               (Nonrecursive,
                                 [value_binding _loc (pat_ident _loc "y") y],
                                 (loc_expr _loc
                                    (Pexp_ifthenelse
                                       (c,
                                         (exp_Cons _loc e
                                            (exp_ident _loc "y")),
                                         (Some (exp_ident _loc "y")))))))))
              ls (exp_Nil _loc)
             in
          exp_apply _loc (exp_glr_fun _loc "alternatives") [l]
      
    let _ =
      Earley.set_grammar glr_rules
        (Earley.fsequence_position
           (Earley.option None
              (Earley.apply (fun x  -> Some x) (Earley.char '|' '|')))
           (Earley.sequence
              (Earley.apply List.rev
                 (Earley.fixpoint []
                    (Earley.apply (fun x  -> fun y  -> x :: y)
                       (Earley.sequence (glr_rule false)
                          (Earley.char '|' '|') (fun r  -> fun _  -> r)))))
              (glr_rule true)
              (fun rs  ->
                 fun r  ->
                   fun _default_0  ->
                     fun __loc__start__buf  ->
                       fun __loc__start__pos  ->
                         fun __loc__end__buf  ->
                           fun __loc__end__pos  ->
                             let _loc =
                               locate __loc__start__buf __loc__start__pos
                                 __loc__end__buf __loc__end__pos
                                in
                             build_alternatives _loc (rs @ [r]))))
      
  end
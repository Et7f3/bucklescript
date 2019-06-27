(* Copyright (C) 2015-2016 Bloomberg Finance L.P.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * In addition to the permissions granted to you by the LGPL, you may combine
 * or link a "work that uses the Library" with a publicly distributed version
 * of this file to produce a combined library or application, then distribute
 * that combined work under the terms of your choosing, with no requirement
 * to comply with the obligations normally placed on you by section 4 of the
 * LGPL version 3 (or the corresponding section of a later version of the LGPL
 * should you choose to use a later version).
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA. *)

type state = {
  mutable rule_id : int ;  
  mutable rule_names : String_set.t 
}



(** To make it re-entrant across multiple ninja files, 
    We must reset [rule_id]
    could be improved later
             1. instead of having a global id, having a unique id per rule name
             2. the rule id is increased only when actually used
*)
let ask_name (name : string) : string = name



type t = { 
  mutable used : bool; 
  rule_name : string; 
  name : out_channel -> string 
}

let get_name (x : t) oc = x.name oc
let print_rule oc ~description ?(restat : unit option)  ?dyndep ~command   name  =
  output_string oc "rule "; output_string oc name ; output_string oc "\n";
  output_string oc "  command = "; output_string oc command; output_string oc "\n";
  Ext_option.iter dyndep (fun f ->
      output_string oc "  dyndep = "; output_string oc f; output_string oc  "\n"
  );
  (if restat <>  None then   
      output_string oc "  restat = 1\n");

  output_string oc "  description = " ; output_string oc description; output_string oc "\n"




(** allocate an unique name for such rule*)
let define
    ~command
    ?dyndep
    ?restat
    ?(description = "\027[34mBuilding\027[39m \027[2m${out}\027[22m") (* blue, dim *)
    name : t 
  =
  let rule_name = ask_name name  in 
  let rec self = {
    used  = false;
    rule_name ;
    name = fun oc ->
      if not self.used then
        begin
          print_rule oc ~description  ?dyndep ?restat ~command rule_name;
          self.used <- true
        end ;
      rule_name
  } in self


(** FIXME: We don't need set [-o ${out}] when building ast 
    since the default is already good -- it does not*)
let build_ast_and_module_sets =
  define
    ~command:"$bsc  $pp_flags $ppx_flags $warnings $bsc_flags -c -o $out -bs-syntax-only -bs-binary-ast $in"
    "build_ast_and_module_sets"


let build_ast_and_module_sets_from_re =
  define
    ~command:"$bsc -pp \"$refmt $refmt_flags\" $reason_react_jsx  $ppx_flags $warnings $bsc_flags -c -o $out -bs-syntax-only -bs-binary-ast -impl $in"
    "build_ast_and_module_sets_from_re"

let build_ast_and_module_sets_from_rei =
  define
    ~command:"$bsc -pp \"$refmt $refmt_flags\" $reason_react_jsx $ppx_flags $warnings $bsc_flags  -c -o $out -bs-syntax-only -bs-binary-ast -intf $in"
    "build_ast_and_module_sets_from_rei"

let copy_resources =    
  define 
    ~command:(
      if Ext_sys.is_windows_or_cygwin then
        "cmd.exe /C copy /Y $in $out > null" 
      else "cp $in $out"
    )
    "copy_resource" 


      
let build_bin_deps =
  define
    ~restat:()
    ~command:"$bsdep $g_ns -g $bsb_dir_group $in"
    "build_deps"


(* only generate mll no mli generated *)
(* actually we would prefer generators in source ?
   generator are divided into two categories:
   1. not system dependent (ocamllex,ocamlyacc)
   2. system dependent - has to be run on client's machine
*)


(**************************************)
(* below are rules not local any more *)
(**************************************)

(* [g_lib_incls] are fixed for libs *)
let ml_cmj_js =
  define
    ~command:"$bsc $g_pkg_flg -bs-read-cmi  $g_pkg_incls $g_lib_incls $bsc_extra_includes $warnings $bsc_flags $gentypeconfig -o $out -c  $in $postbuild"
    ~dyndep:"$in_e.d"
    ~restat:() (* Always restat when having mli *)
    "ml_cmj_only"
    
let re_cmj_js =
  define
    ~command:"$bsc $g_pkg_flg -bs-read-cmi  -bs-re-out -bs-super-errors $g_pkg_incls $g_lib_incls $bsc_extra_includes $warnings $bsc_flags $gentypeconfig -o $out -c  $in $postbuild"
    ~dyndep:"$in_e.d"
    ~restat:() (* Always restat when having mli *)
    "re_cmj_only"


let ml_cmj_cmi_js =
  define
    ~command:"$bsc $g_pkg_flg $g_pkg_incls $g_lib_incls $bsc_extra_includes $warnings $bsc_flags $gentypeconfig -o $out -c  $in $postbuild"
    ~dyndep:"$in_e.d" 
    ~restat:() (* may not need it in the future *)
    "ml_cmj_cmi" (* the compiler should never consult [.cmi] when [.mli] does not exist *)

let re_cmj_cmi_js =
  define
    ~command:"$bsc $g_pkg_flg  -bs-re-out -bs-super-errors $g_pkg_incls $g_lib_incls $bsc_extra_includes $warnings $bsc_flags $gentypeconfig -o $out -c  $in $postbuild"
    ~dyndep:"$in_e.d" 
    ~restat:() (* may not need it in the future *)
    "re_cmj_cmi" (* the compiler should never consult [.cmi] when [.mli] does not exist *)

    
let ml_cmi =
  define
    ~command:"$bsc $g_pkg_flg  $g_pkg_incls $g_lib_incls $bsc_extra_includes $warnings $bsc_flags $gentypeconfig -o $out -c  $in"
    ~dyndep:"$in_e.d"
    ~restat:()
    "ml_cmi" (* the compiler should always consult [.cmi], current the vanilla ocaml compiler only consult [.cmi] when [.mli] found*)

let re_cmi =
  define
    ~command:"$bsc $g_pkg_flg  -bs-re-out -bs-super-errors $g_pkg_incls $g_lib_incls $bsc_extra_includes $warnings $bsc_flags $gentypeconfig -o $out -c  $in"
    ~dyndep:"$in_e.d"
    ~restat:()
    "re_cmi" (* the compiler should always consult [.cmi], current the vanilla ocaml compiler only consult [.cmi] when [.mli] found*)
    
let build_package = 
  define
    ~command:"$bsc -w -49 -no-alias-deps -bs-cmi-only -c $in"
    ~restat:()
    "build_package"


type command = string

let make_custom_rules (custom_rules : command String_map.t) = 

  build_ast_and_module_sets.used <- false ;
  build_ast_and_module_sets_from_re.used <- false ;  
  build_ast_and_module_sets_from_rei.used <- false ;
  build_bin_deps.used <- false;
  copy_resources.used <- false ;

  ml_cmj_js.used <- false;
  ml_cmj_cmi_js.used <- false ;
  ml_cmi.used <- false ;

  re_cmj_cmi_js.used <- false;
  re_cmj_js.used <- false;
  re_cmi.used <- false;

  build_package.used <- false;    
  String_map.mapi custom_rules begin fun name command -> 
    define ~command ("custom_" ^ name)
  end



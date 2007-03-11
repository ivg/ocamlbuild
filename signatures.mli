(***********************************************************************)
(*                             ocamlbuild                              *)
(*                                                                     *)
(*  Nicolas Pouillard, Berke Durak, projet Gallium, INRIA Rocquencourt *)
(*                                                                     *)
(*  Copyright 2007 Institut National de Recherche en Informatique et   *)
(*  en Automatique.  All rights reserved.  This file is distributed    *)
(*  under the terms of the Q Public License version 1.0.               *)
(*                                                                     *)
(***********************************************************************)

(* $Id$ *)
(* Original author: Nicolas Pouillard *)
(** This module contains all module signatures that the user
    could use to build an ocamlbuild plugin. *)

module type OrderedTypePrintable = sig
  type t
  val compare : t -> t -> int
  val print : Format.formatter -> t -> unit
end

module type SET = sig
  include Set.S
  val find : (elt -> bool) -> t -> elt
  val map : (elt -> elt) -> t -> t
  val of_list : elt list -> t
  val print : Format.formatter -> t -> unit
end

module type LIST = sig
  (* Added functions *)
  val print : (Format.formatter -> 'a -> 'b) -> Format.formatter -> 'a list -> unit
  val filter_opt : ('a -> 'b option) -> 'a list -> 'b list
  val union : 'a list -> 'a list -> 'a list

  (* Original functions *)
  include Std_signatures.LIST
end

module type STRING = sig
  val print : Format.formatter -> string -> unit
  val chomp : string -> string

  (** [before s n] returns the substring of all characters of [s]
     that precede position [n] (excluding the character at
     position [n]).
     This is the same function as {!Str.string_before}. *)
  val before : string -> int -> string

  (** [after s n] returns the substring of all characters of [s]
     that follow position [n] (including the character at
     position [n]).
     This is the same function as {!Str.string_after}. *)
  val after : string -> int -> string

  val first_chars : string -> int -> string
  (** [first_chars s n] returns the first [n] characters of [s].
     This is the same function as {!before} ant {!Str.first_chars}. *)

  val last_chars : string -> int -> string
  (** [last_chars s n] returns the last [n] characters of [s].
      This is the same function as {!Str.last_chars}. *)

  val eq_sub_strings : string -> int -> string -> int -> int -> bool

  (** [is_prefix u v] is u a prefix of v ? *)
  val is_prefix : string -> string -> bool
  (** [is_suffix u v] : is v a suffix of u ? *)
  val is_suffix : string -> string -> bool

  (** [contains_string s1 p2 s2] Search in [s1] starting from [p1] if it
      contains the [s2] string. Returns [Some position] where [position]
      is the begining of the string [s2] in [s1], [None] otherwise. *)
  val contains_string : string -> int -> string -> int option

  (** [subst patt repl text] *)
  val subst : string -> string -> string -> string

  (** [tr patt repl text] *)
  val tr : char -> char -> string -> string

  val rev : string -> string

  (** The following are original functions from the [String] module. *)
  include Std_signatures.STRING
end

module type TAGS = sig
  include Set.S with type elt = string
  val of_list : string list -> t
  val print : Format.formatter -> t -> unit
  val does_match : t -> t -> bool
  module Operators : sig
    val ( ++ ) : t -> elt -> t
    val ( -- ) : t -> elt -> t
    val ( +++ ) : t -> elt option -> t
    val ( --- ) : t -> elt option -> t
  end
end

module type PATHNAME = sig
  type t = string
  val concat : t -> t -> t
  val compare : t -> t -> int
  val equal : t -> t -> bool
  val exists : t -> bool
  val mk : string -> t
  val define_context : string -> string list -> unit
  val include_dirs_of : string -> string list
  val copy : t -> t -> unit
  val to_string : t -> string
  val print : Format.formatter -> t -> unit
  val current_dir_name : t
  val parent_dir_name : t
  val read : t -> string
  val same_contents : t -> t -> bool
  val basename : t -> t
  val dirname : t -> t
  val is_relative : t -> bool
  val readlink : t -> t
  val readdir : t -> t array
  val is_link : t -> bool
  val is_directory : t -> bool

  val add_extension : string -> t -> t
  val check_extension : t -> string -> bool

  val get_extension : t -> string
  val remove_extension : t -> t
  val update_extension : string -> t -> t

  val get_extensions : t -> string
  val remove_extensions : t -> t
  val update_extensions : string -> t -> t

  val print_path_list : Format.formatter -> t list -> unit
  val pwd : t
  val parent : t -> t
  (** [is_prefix x y] is [x] a pathname prefix of [y] *)
  val is_prefix : t -> t -> bool
  val is_implicit : t -> bool
  module Operators : sig
    val ( / ) : t -> t -> t
    val ( -.- ) : t -> string -> t
  end
end

(** Provides an abstract type for easily building complex shell commands without making
    quotation mistakes.  *)
module type COMMAND = sig
  type tags

  (** The type [t] is basically a sequence of command specifications.  This avoids having to
      flatten lists of lists.  *)
  type t = Seq of t list | Cmd of spec | Nop

  (** The type for command specifications. *)
  and spec =
    | N                       (** No operation. *)
    | S of spec list          (** A sequence.  This gets flattened in the last stages *)
    | A of string             (** An atom. *)
    | P of string             (** A pathname. *)
    | Px of string            (** A pathname, that will also be given to the call_with_target hook. *)
    | Sh of string            (** A bit of raw shell code, that will not be escaped. *)
    | T of tags               (** A set of tags, that describe properties and some semantics
                                  information about the command, afterward these tags will be
                                  replaced by command [spec]s (flags for instance). *)
    | V of string             (** A virtual command, that will be resolved at execution using [resolve_virtuals] *)
    | Quote of spec           (** A string that should be quoted like a filename but isn't really one. *)

  (*type v = [ `Seq of v list | `Cmd of vspec | `Nop ]
  and vspec =
    [ `N
    | `S of vspec list
    | `A of string
    | `P of string (* Pathname.t *)
    | `Px of string (* Pathname.t *)
    | `Sh of string
    | `Quote of vspec ]

  val spec_of_vspec : vspec -> spec
  val vspec_of_spec : spec -> vspec
  val t_of_v : v -> t
  val v_of_t : t -> v*)

  (** Will convert a string list to a list of atoms by adding [A] constructors. *)
  val atomize : string list -> spec

  (** Will convert a string list to a list of paths by adding [P] constructors. *)
  val atomize_paths : string list -> spec

  (** Run the command. *)
  val execute : ?quiet:bool -> ?pretend:bool -> t -> unit

  (** Run the commands in the given list, if possible in parallel.
      See the module [Executor]. *)
  val execute_many : ?quiet:bool -> ?pretend:bool -> t list -> (bool list * exn) option

  (** [setup_virtual_command_solver virtual_command solver]
        the given solver can raise Not_found if it fails to find a valid
        command for this virtual command. *)
  val setup_virtual_command_solver : string -> (unit -> spec) -> unit

  (** Search the given command in the command path and return its absolute
      pathname. *)
  val search_in_path : string -> string

  (** Simplify a command by flattening the sequences and resolving the tags
      into command-line options. *)
  val reduce : spec -> spec

  (** Print a command. *)
  val print : Format.formatter -> t -> unit

  (** Convert a command to a string. *)
  val to_string : t -> string

  (** Build a string representation of a command that can be passed to the
      system calls. *)
  val string_of_command_spec : spec -> string
end

(** A self-contained module implementing extended shell glob patterns who have an expressive power
    equal to boolean combinations of regular expressions.  *)
module type GLOB = sig

  (** A globber is a boolean combination of basic expressions indented to work on
      pathnames.  Known operators
      are [or], [and] and [not], which may also be written [|], [&] and [~].  There are
      also constants [true] and [false] (or [1] and [0]).  Expression can be grouped
      using parentheses.
      - [true] matches anything,
      - [false] matches nothing,
      - {i basic} [or] {i basic} matches strings matching either one of the basic expressions,
      - {i basic} [and] {i basic} matches strings matching both basic expressions,
      - not {i basic} matches string that don't match the basic expression,
      - {i basic} matches strings that match the basic expression.

      A basic expression can be a constant string enclosed in double quotes, in which
      double quotes must be preceded by backslashes, or a glob pattern enclosed between a [<] and a [>],
      - ["]{i string}["] matches the literal string {i string},
      - [<]{i glob}[>] matches the glob pattern {i glob}. 

      A glob pattern is an anchored regular expression in a shell-like syntax.  Most characters stand for themselves.
      Character ranges are given in usual shell syntax between brackets.  The star [*] stands for any sequence of
      characters.  The joker '?' stands for exactly one, unspecified character.  Alternation is achieved using braces [{].
      - {i glob1}{i glob2} matches strings who have a prefix matching {i glob1} and the corresponding suffix
        matching {i glob2}.
      - [a] matches the string consisting of the single letter [a].
      - [{]{i glob1},{i glob2}[}] matches strings matching {i glob1} or {i glob2}.
      - [*] matches all strings, including the empty one.
      - [?] matches strings of length 1.
      - [\[]{i c1}-{i c2}{i c3}-{i c4}...[\]] matches characters in the range {i c1} to {i c2} inclusive,
        or in the range {i c3} to {i c4} inclusive.  For instance [\[a-fA-F0-9\]] matches hexadecimal digits.
        To match the dash, put it at the end.
  *)

  (** The type representing globbers.  Do not attempt to compare them, as they get on-the-fly optimizations. *)
  type globber

  (** [parse ~dir pattern] will parse the globber pattern [pattern], optionally prefixing its patterns with [dir]. *)
  val parse : ?dir:string -> string -> globber

  (** A descriptive exception raised when an invalid glob pattern description is given. *)
  exception Parse_error of string

  (** [eval g u] returns [true] if and only if the string [u] matches the given glob expression.  Avoid reparsing
      the same pattern, since the automaton implementing the pattern is optimized on the fly.  The first few evaluations
      are done using a time-inefficient but memory-efficient algorithm.  It then compiles the pattern into an efficient
      but more memory-hungry data structure. *)
  val eval : globber -> string -> bool
end

(** Module for modulating the logging output with the logging level. *)
module type LOG = sig
  (** Current logging (debugging) level. *)
  val level : int ref

  (** [dprintf level fmt args...] formats the logging information [fmt]
      with the arguments [args...] on the logging output if the logging
      level is greater than or equal to [level]. The default level is 1.
      More obscure debugging information should have a higher logging
      level. Youre formats are wrapped inside these two formats
      ["@\[<2>"] and ["@\]@."]. *)
  val dprintf : int -> ('a, Format.formatter, unit) format -> 'a

  (** Equivalent to calling [dprintf] with a level [< 0]. *)
  val eprintf : ('a, Format.formatter, unit) format -> 'a

  (** Same as dprintf but without the format wrapping. *)
  val raw_dprintf : int -> ('a, Format.formatter, unit) format -> 'a
end

module type OUTCOME = sig
  type ('a,'b) t =
    | Good of 'a
    | Bad of 'b

  val wrap : ('a -> 'b) -> 'a -> ('b, exn) t
  val ignore_good : ('a, exn) t -> unit
  val good : ('a, exn) t -> 'a
end

module type MISC = sig
  val opt_print :
    (Format.formatter -> 'a -> unit) -> Format.formatter -> 'a option -> unit
  val the : 'a option -> 'a
  val getenv : ?default:string -> string -> string
  val with_input_file : ?bin:bool -> string -> (in_channel -> 'a) -> 'a
  val with_output_file : ?bin:bool -> string -> (out_channel -> 'a) -> 'a
  val with_temp_file : string -> string -> (string -> 'a) -> 'a
  val read_file : string -> string
  val copy_chan : in_channel -> out_channel -> unit
  val copy_file : string -> string -> unit
  val print_string_list : Format.formatter -> string list -> unit

  (** A shortcut to force lazy value (See {Lazy.force}). *)
  val ( !* ) : 'a Lazy.t -> 'a

  (** The right associative application.
      Useful when writing to much parentheses:
      << f (g x ... t) >> becomes << f& g x ... t >>
      << f (g (h x)) >>   becomes << f& g& h x >> *)
  val ( & ) : ('a -> 'b) -> 'a -> 'b

  (** [r @:= l] is equivalent to [r := !r @ l] *)
  val ( @:= ) : 'a list ref -> 'a list -> unit

  val memo : ('a -> 'b) -> ('a -> 'b)
end

module type OPTIONS = sig
  type command_spec

  val build_dir : string ref
  val include_dirs : string list ref
  val exclude_dirs : string list ref
  val nothing_should_be_rebuilt : bool ref
  val ocamlc : command_spec ref
  val ocamlopt : command_spec ref
  val ocamldep : command_spec ref
  val ocamldoc : command_spec ref
  val ocamlyacc : command_spec ref
  val ocamllex : command_spec ref
  val ocamlrun : command_spec ref
  val ocamlmklib : command_spec ref
  val ocamlmktop : command_spec ref
  val hygiene : bool ref
  val sanitize : bool ref
  val sanitization_script : string ref
  val ignore_auto : bool ref
  val plugin : bool ref
  val just_plugin : bool ref
  val native_plugin : bool ref
  val make_links : bool ref
  val nostdlib : bool ref
  val program_to_execute : bool ref
  val must_clean : bool ref
  val catch_errors : bool ref
  val internal_log_file : string option ref
  val use_menhir : bool ref
  val show_documentation : bool ref

  val targets : string list ref
  val ocaml_libs : string list ref
  val ocaml_cflags : string list ref
  val ocaml_lflags : string list ref
  val ocaml_ppflags : string list ref
  val ocaml_yaccflags : string list ref
  val ocaml_lexflags : string list ref
  val program_args : string list ref
  val ignore_list : string list ref
  val tags : string list ref
  val show_tags : string list ref

  val ext_obj : string ref
  val ext_lib : string ref
  val ext_dll : string ref
end

module type ARCH = sig
  type 'a arch = private
    | Arch_dir of string * 'a * 'a arch list
    | Arch_dir_pack of string * 'a * 'a arch list
    | Arch_file of string * 'a

  val dir : string -> unit arch list -> unit arch
  val dir_pack : string -> unit arch list -> unit arch
  val file : string -> unit arch

  type info = private {
    current_path : string;
    include_dirs : string list;
    for_pack : string;
  }

  val annotate : 'a arch -> info arch

  val print : (Format.formatter -> 'a -> unit) -> Format.formatter -> 'a arch -> unit
  val print_include_dirs : Format.formatter -> string list -> unit
  val print_info : Format.formatter -> info -> unit

  val iter_info : ('a -> unit) -> 'a arch -> unit
  val fold_info : ('a -> 'b -> 'b) -> 'a arch -> 'b -> 'b

  val iter_include_dirs : info arch -> (string -> unit) -> unit

  val mk_tables :
    info arch -> (string, string list) Hashtbl.t * (string, string) Hashtbl.t
  val print_table :
    (Format.formatter -> 'a -> unit) -> Format.formatter -> (string, 'a) Hashtbl.t -> unit
end

(** This module contains the functions and values that can be used by plugins. *)
module type PLUGIN = sig
  module Pathname  : PATHNAME
  module Tags      : TAGS
  module Command   : COMMAND with type tags = Tags.t
  module Outcome   : OUTCOME
  module String    : STRING
  module List      : LIST
  module StringSet : Set.S with type elt = String.t
  module Options   : OPTIONS with type command_spec = Command.spec
  module Arch      : ARCH
  include MISC

  val ( / ) : Pathname.t -> Pathname.t -> Pathname.t
  val ( -.- ) : Pathname.t -> string -> Pathname.t

  val ( ++ ) : Tags.t -> Tags.elt -> Tags.t
  val ( -- ) : Tags.t -> Tags.elt -> Tags.t
  val ( +++ ) : Tags.t -> Tags.elt option -> Tags.t
  val ( --- ) : Tags.t -> Tags.elt option -> Tags.t

  type env = Pathname.t -> Pathname.t
  type builder = Pathname.t list list -> (Pathname.t, exn) Outcome.t list
  type action = env -> builder -> Command.t

  val rule : string ->
    ?tags:string list ->
    ?prods:string list ->
    ?deps:string list ->
    ?prod:string ->
    ?dep:string ->
    ?insert:[`top | `before of string | `after of string | `bottom] ->
    action -> unit

  val file_rule : string ->
    ?tags:string list ->
    prod:string ->
    ?deps:string list ->
    ?dep:string ->
    ?insert:[`top | `before of string | `after of string | `bottom] ->
    cache:(env -> string) ->
    (env -> out_channel -> unit) -> unit

  val custom_rule : string ->
    ?tags:string list ->
    ?prods:string list ->
    ?prod:string ->
    ?deps:string list ->
    ?dep:string ->
    ?insert:[`top | `before of string | `after of string | `bottom] ->
    cache:(env -> string) ->
    (env -> cached:bool -> unit) -> unit

  (** [copy_rule name ?insert source destination] *)
  val copy_rule : string ->
    ?insert:[`top | `before of string | `after of string | `bottom] ->
    string -> string -> unit

  (** [dep tags deps] Will build [deps] when [tags] will be activated. *)
  val dep : Tags.elt list -> Pathname.t list -> unit

  val flag : Tags.elt list -> Command.spec -> unit

  (** [non_dependency module_path module_name]
       Example: 
         [non_dependency "foo/bar/baz" "Goo"]
       Says that the module [Baz] in the file [foo/bar/baz.*] does not depend on [Goo]. *)
  val non_dependency : Pathname.t -> string -> unit

  (** [use_lib module_path lib_path]*)
  val use_lib : Pathname.t -> Pathname.t -> unit

  (** [ocaml_lib <options> library_pathname]
      Declare an ocaml library.

      Example: ocaml_lib "foo/bar"
        This will setup the tag use_bar tag.
        At link time it will include:
          foo/bar.cma or foo/bar.cmxa
        If you supply the ~dir:"boo" option -I boo
          will be added at link and compile time. 
        Use ~extern:true for non-ocamlbuild handled libraries.
        Use ~byte:false or ~native:false to disable byte or native mode.
        Use ~tag_name:"usebar" to override the default tag name. *)
  val ocaml_lib :
    ?extern:bool ->
    ?byte:bool ->
    ?native:bool ->
    ?dir:Pathname.t ->
    ?tag_name:string ->
    Pathname.t -> unit

  (** [expand_module include_dirs module_name extensions]
      Example:
        [expand_module ["a";"b";"c"] "Foo" ["cmo";"cmi"] =
         ["a/foo.cmo"; "a/Foo.cmo"; "a/foo.cmi"; "a/Foo.cmi";
          "b/foo.cmo"; "b/Foo.cmo"; "b/foo.cmi"; "b/Foo.cmi";
          "c/foo.cmo"; "c/Foo.cmo"; "c/foo.cmi"; "c/Foo.cmi"]] *)
  val expand_module :
    Pathname.t list -> Pathname.t -> string list -> Pathname.t list

  val string_list_of_file : Pathname.t -> string list

  val module_name_of_pathname : Pathname.t -> string

  val mv : Pathname.t -> Pathname.t -> Command.t
  val cp : Pathname.t -> Pathname.t -> Command.t
  val ln_f : Pathname.t -> Pathname.t -> Command.t
  val ln_s : Pathname.t -> Pathname.t -> Command.t
  val rm_f : Pathname.t -> Command.t
  val touch : Pathname.t -> Command.t
  val chmod : Command.spec -> Pathname.t -> Command.t
  val cmp : Pathname.t -> Pathname.t -> Command.t

  (** [hide_package_contents pack_name]
      Don't treat the given package as an open package.
      So a module will not be replaced during linking by
      this package even if it contains that module. *)
  val hide_package_contents : string -> unit

  val tag_file : Pathname.t -> Tags.elt list -> unit

  val tag_any : Tags.elt list -> unit

  val tags_of_pathname : Pathname.t -> Tags.t

  type hook = 
    | Before_hygiene
    | After_hygiene
    | Before_options
    | After_options
    | Before_rules
    | After_rules

  val dispatch : (hook -> unit) -> unit
end
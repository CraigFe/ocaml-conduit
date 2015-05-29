(*
 * Copyright (c) 2012-2015 Anil Madhavapeddy <anil@recoil.org>
 * Copyright (c)      2015 Thomas Gazagnaire <thomas@gazagnaire.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 *)

(** Functorial connection establishment interface that is compatible with
    the Mirage libraries.
  *)

module Flow: V1_LWT.FLOW
(** Dynamic flows. *)

type callback = Flow.flow -> unit Lwt.t
(** The type for callback values. *)

module type Handler = sig
  (** The signature for runtime handlers *)

  type t
  (** The type for runtime handlers. *)

  type client with sexp
  (** The type for client configuration values. *)

  type server with sexp
  (** The type for server configuration values. *)

  val connect: t -> client -> Flow.flow Lwt.t
  (** Connect a conduit using client configuration. *)

  val listen: t -> server -> callback -> unit Lwt.t
  (** Listen to a conduit using a server configuration. *)

end

(** {1 TCP} *)

(** The type for client connections. *)

type tcp_client = [ `TCP of Ipaddr.t * int ] (** address and destination port *)
and tcp_server  = [ `TCP of int ]                          (** listening port *)

(** {1 VCHAN} *)

IFDEF HAVE_VCHAN THEN
type vchan = [
  | `Vchan of [
      | `Direct of int * Vchan.Port.t                   (** domain id, port *)
      | `Domain_socket of string * Vchan.Port.t (** Vchan Xen domain socket *)
    ]
] with sexp
module type VCHAN = Vchan.S.ENDPOINT with type port = Vchan.Port.t
module type XS = Xs_client_lwt.S
ELSE
type vchan = [`Vchan of [`None]]
module type VCHAN = sig type t end
module type XS = sig end
ENDIF

(** {1 TLS} *)

IFDEF HAVE_MIRAGE_TLS THEN
type 'a tls_client = [ `TLS of Tls.Config.client * 'a ]
type 'a tls_server = [ `TLS of Tls.Config.server * 'a ]
ELSE
type 'a tls_client = [`TLS of [`None]]
type 'a tls_server = [`TLS of [`None]]
ENDIF


type client = [ tcp_client | vchan | client tls_client ] with sexp
(** The type for client configuration values. *)

type server = [ tcp_server | vchan | server tls_server ] with sexp
(** The type for server configuration values. *)

val client: Conduit.endp -> client Lwt.t
(** Resolve a conduit endpoint into a client configuration. *)

val server: Conduit.endp -> server Lwt.t
(** Resolve a confuit endpoint into a server configuration. *)

module type S = sig
  (** The signature for Conduit implementations. *)

  type t
  (** The type for conduit values. *)

  val empty: t
  (** The empty conduit. *)

  val with_tcp: t -> (module V1_LWT.STACKV4 with type t = 'a) -> 'a -> t Lwt.t
  (** Extend a conduit with an implementation for TCP. *)

  val with_tls: t -> t Lwt.t
  (** Extend a conduit with an implementation for TLS. *)

  val with_vchan: t -> (module XS) -> (module VCHAN) -> bytes -> t Lwt.t
  (** Extend a conduit with an implementation for VCHAN. *)

  val connect: t -> client -> Flow.flow Lwt.t
  (** Connect a conduit using a client configuration value. *)

  val listen: t -> server -> callback -> unit Lwt.t
  (** Configure a server using a conduit configuration value. *)

end

include S

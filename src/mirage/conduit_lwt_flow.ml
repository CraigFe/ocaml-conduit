open Lwt.Infix

type flow = Conduit_lwt.flow

type error = Conduit_lwt.error

type write_error = [ Mirage_flow.write_error | Conduit_lwt.error ]

let pp_error = Conduit_lwt.pp_error

let pp_write_error ppf = function
  | #Mirage_flow.write_error as err -> Mirage_flow.pp_write_error ppf err
  | #Conduit_lwt.error as err -> Conduit_lwt.pp_error ppf err

let read flow =
  let raw = Cstruct.create 0x1000 in
  Conduit_lwt.recv flow raw >>= function
  | Ok `End_of_flow -> Lwt.return_ok `Eof
  | Ok (`Input len) -> Lwt.return_ok (`Data (Cstruct.sub raw 0 len))
  | Error _ as err -> Lwt.return err

let write flow raw =
  let rec go x =
    if Cstruct.len x = 0
    then Lwt.return_ok ()
    else
      Conduit_lwt.send flow x >>= function
      | Error _ as err -> Lwt.return err
      | Ok len -> go (Cstruct.shift x len) in
  go raw

let writev flow cs =
  let rec go = function
    | [] -> Lwt.return_ok ()
    | x :: r -> (
        write flow x >>= function
        | Ok () -> go r
        | Error _ as err -> Lwt.return err) in
  go cs

let close flow = Conduit_lwt.close flow >>= fun _ -> Lwt.return_unit

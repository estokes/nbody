module Vector = struct
  type t =
    { mutable x: float;
      mutable y: float;
      mutable z: float }

  let (+) a b = {x = a.x +. b.x; y = a.y +. b.y; z = a.z +. b.z}
  let (<+) a b =
    a.x <- a.x +. b.x;
    a.y <- a.y +. b.y;
    a.z <- a.z +. b.z
  let (-) a b = {x = a.x -. b.x; y = a.y -. b.y; z = a.z -. b.z}
  let ( * ) v a = {x = v.x *. a; y = v.y *. a; z = v.z *. a}
  let (<*) v a =
    v.x <- v.x *. a;
    v.y <- v.y *. a;
    v.z <- v.z *. a

  let normalize v = v * (1. /. sqrt (v.x *. v.x +. v.y *. v.y +. v.z *. v.z))

  let distance_squared p1 p2 =
    (p1.x -. p2.x) ** 2. +. (p1.y -. p2.y) ** 2. +. (p1.z -. p2.z) ** 2.

  let distance p1 p2 = sqrt (distance_squared p1 p2)

  let direction v1 v2 = normalize (v2 - v1)
end

module Body = struct
  type t =
    { position: Vector.t;
      velocity: Vector.t;
      mass: float }

  let gravity b1 b2 =
    let g = 6.673e-11 in
    let rsquared = Vector.distance_squared b1.position b2.position in
    g *. ((b1.mass *. b2.mass) /. rsquared)

  let apply_force on towards magnitude duration =
    let dir = Vector.direction on.position towards.position in
    let a = magnitude /. on.mass in
    Vector.(dir <* (a *. duration));
    Vector.(on.velocity <+ dir)

  let update_position b duration =
    Vector.(b.position <+ (b.velocity * duration))
end

type t = Body.t array

let step1 universe duration =
  let len = Array.length universe - 1 in
  for i=0 to len do
    for j=0 to len do
      if i != j then begin
        let b1 = universe.(i) in
        let b2 = universe.(j) in
        Body.apply_force b1 b2 (Body.gravity b1 b2) duration
      end
    done
  done;
  for i = 0 to len do
    Body.update_position universe.(i) duration
  done

module Two_body_test = struct
    (* This test simulates a 1000kg object in a roughly circular orbit
       around the moon *)
    let big =
      {Body.
       position = {Vector.x=0.;y=0.;z=0.};
       velocity = {Vector.x=0.;y=0.;z=0.};
       mass = 7.34e22}

    let small =
      {Body.
       position = {Vector.x=1750000.;y=0.;z=0.};
       velocity = {Vector.x=0.;y=1673.;z=0.};
       mass = 1000.}

    let universe = [|big; small|]

    let go () =
      for i=1 to 6000 do
        step1 universe 0.1;
        let dist = Vector.distance big.Body.position small.Body.position in
        if dist < 1737100. then
          failwith (Printf.sprintf "collision at step %d" i)
      done;
      let dist = Vector.distance big.Body.position small.Body.position in
      ((dist -. 1737000.) /. 1000., small)
end

module Many_body_test = struct
  let go step size =
    let universe =
      Random.init 1232;
      let pos () = Random.float 1000000000. in
      let v () = Random.float 500. in
      let mass () = Random.float 1e22 in
      Array.init size (fun _ ->
        {Body.
         position = {Vector.x = pos (); y = pos (); z = pos ()};
         velocity = {Vector.x = v (); y = v (); z = v ()};
         mass = mass () })
    in
    for i = 1 to 6000 do
      step universe 0.1
    done
end

let () = Many_body_test.go step1 1000

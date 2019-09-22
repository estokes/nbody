open System
#r "Mono.Simd"

[<Struct>]
type vector = 
    val mutable x: float
    val mutable y: float
    val mutable z: float
    new(X, Y, Z) = {x=X;y=Y;z=Z}
    static member (+) (a: vector, b: vector) =
        vector(a.x + b.x, a.y + b.y, a.z + b.z)
    static member (-) (a: vector, b: vector) =
        vector(a.x - b.x, a.y - b.y, a.z - b.z)
    static member ( *. ) (a: vector, b: vector) = a.x * b.x + a.y * b.y + a.z * b.z
    static member ( * ) (v: vector, a) = vector(v.x * a, v.y * a, v.z * a)
    static member ( * ) (a: float, v: vector) = v * a

type body = 
    { mutable position: vector
      mutable velocity: vector
      mass: float }

type universe = list<body>

let distance_squared (p1: vector) (p2: vector) = 
  (p1.x - p2.x) ** 2. + (p1.y - p2.y) ** 2. + (p1.z - p2.z) ** 2.

let distance p1 p2 = sqrt (distance_squared p1 p2)

let gravity b1 b2 =
    let G = 6.673e-11
    G*((b1.mass*b2.mass) / (distance_squared b1.position b2.position))

let normalize (v : vector) = v * (1. / sqrt(v.x * v.x + v.y * v.y + v.z * v.z))
let direction v1 v2 = normalize (v2 - v1)

let apply_force on towards magnitude duration =
    let direction = direction on.position towards.position
    let a = magnitude / on.mass
    on.velocity <- on.velocity + (direction * (a * duration))

let update_position b duration =
    b.position <- b.position + b.velocity * duration

(* > Many_body_test.go step1 100;;
Real: 00:00:17.752, CPU: 00:00:17.799, GC gen0: 463, gen1: 4, gen2: 1 *)
let step1 universe duration =
    for b1 in universe do
        for b2 in universe do
            if not (LanguagePrimitives.PhysicalEquality b1 b2) then
                apply_force b1 b2 (gravity b1 b2) duration
    for b in universe do
        update_position b duration

(* > Many_body_test.go step2 100;;
Real: 00:00:47.341, CPU: 00:01:41.478, GC gen0: 6377, gen1: 3228, gen2: 1 *)
let step2 universe duration =
    List.map (fun b1 -> 
        List.map (fun b2 ->
            async {
                if not (LanguagePrimitives.PhysicalEquality b1 b2) then
                    apply_force b1 b2 (gravity b1 b2) duration
                return ()
            }) universe) universe
    |> List.concat
    |> Async.Parallel
    |> Async.RunSynchronously
    |> (ignore : unit [] -> unit)
    for b in universe do
        update_position b duration

(* > Many_body_test.go step3 100;;
Real: 00:00:11.018, CPU: 00:00:33.493, GC gen0: 1847, gen1: 11, gen2: 0 *)
let step3 universe duration =
    List.map (fun b1 ->
        async {
            for b2 in universe do
                if not (LanguagePrimitives.PhysicalEquality b1 b2) then
                    apply_force b1 b2 (gravity b1 b2) duration
            return ()
        }) universe
    |> Async.Parallel
    |> Async.RunSynchronously
    |> (ignore : unit [] -> unit)
    for b in universe do
        update_position b duration

(* > Many_body_test.go step4 100;;
Real: 00:00:09.102, CPU: 00:00:24.960, GC gen0: 1369, gen1: 2, gen2: 1 *)
let step4 universe duration =
    let nprocs = 4
    let gsize = List.length universe / nprocs
    let (_, _, groups) =
        List.fold (fun (i, cur, acc) e ->
            if i % gsize = 0 then (i + 1, [], (e :: cur) :: acc)
            else (i + 1, e :: cur, acc)) (0, [], []) universe
    List.map (fun g ->
        async {
            for b1 in g do
                for b2 in universe do
                    if not (LanguagePrimitives.PhysicalEquality b1 b2) then
                        apply_force b1 b2 (gravity b1 b2) duration                    
            return ()
        }) groups
    |> Async.Parallel
    |> Async.RunSynchronously
    |> (ignore : unit [] -> unit)
    for b in universe do
        update_position b duration

(* > Many_body_test.go step5 100;;
Real: 00:00:05.647, CPU: 00:00:19.141, GC gen0: 462, gen1: 1, gen2: 0 *)
let step5 universe duration =
    let universe = Array.ofList universe
    Array.Parallel.iter (fun b1 ->
        for b2 in universe do
            if not (LanguagePrimitives.PhysicalEquality b1 b2) then
                apply_force b1 b2 (gravity b1 b2) duration)
        universe
    for b in universe do
        update_position b duration

(* > Many_body_test.go step6 100;;
Real: 00:00:06.314, CPU: 00:00:21.325, GC gen0: 552, gen1: 3, gen2: 1 *)  
let step6 universe duration =
    let universe = Array.ofList universe
    Array.Parallel.iter (fun b1 ->
        Array.Parallel.iter (fun b2 ->
            if not (LanguagePrimitives.PhysicalEquality b1 b2) then
                apply_force b1 b2 (gravity b1 b2) duration)
            universe)
        universe
    for b in universe do
        update_position b duration
       
module Two_body_test =
    (* This test simulates a 1000kg object in a roughly circular orbit 
       around the moon *)
    let big = 
        {position = vector(x=0.,y=0.,z=0.)
         velocity = vector(x=0.,y=0.,z=0.)
         mass = 7.34e22}

    let small = 
        {position = vector(x=1750000.,y=0.,z=0.)
         velocity = vector(x=0.,y=1673.,z=0.)
         mass = 1000.}
           
    let universe = [big; small]

    let go () =
        for i=1 to 6000 do 
            step4 universe 0.1
            if distance big.position small.position < 1737100. then 
                failwith ("collision at step " + i.ToString())
        ((distance big.position small.position - 1737000.)/1000., small)

module Many_body_test = 
    let go step size =
        let universe =
            let r = new System.Random(1232)
            let pos () = r.NextDouble () * 1000000000.
            let v () = r.NextDouble () * 500.
            let mass () = r.NextDouble () * 1e22
            List.init size (fun _ -> 
                {position = vector(x = pos (), y = pos (), z = pos ())
                 velocity = vector(x = v (), y = v (), z = v ())
                 mass = mass ()})    
        for i = 1 to 6000 do
            step universe 0.1
        (* not sure what to check here ... *)

[<EntryPoint>]
let main argv =
    Many_body_test.go step5 1000
    0

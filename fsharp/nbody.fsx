open System
open System.Threading.Tasks

(*
    static member (+) (a: vector, b: vector) =
        vector(a.x + b.x, a.y + b.y, a.z + b.z)
    static member (-) (a: vector, b: vector) =
        vector(a.x - b.x, a.y - b.y, a.z - b.z)
    static member ( *. ) (a: vector, b: vector) = a.x * b.x + a.y * b.y + a.z * b.z
    static member ( * ) (v: vector, a) = vector(v.x * a, v.y * a, v.z * a)
    static member ( * ) (a: float, v: vector) = v * a
 *)

[<Struct>]
type vector = 
    val mutable x: float
    val mutable y: float
    val mutable z: float
    new(x, y, z) = {x = z; y = y; z = z}

[<Struct>]
type body =
    val mutable velocity: vector
    val mutable position: vector
    val mutable mass: float
    new(v, p, m) = {velocity=v; position=p; mass=m}
    override o.ToString() =
        sprintf "{position: %A; velocity: %A; mass: %A"
            o.position o.velocity o.mass

type universe = body[]

let distance p1 p2 =
    let distance_squared (p1: vector) (p2: vector) = 
        (p1.x - p2.x) ** 2. + (p1.y - p2.y) ** 2. + (p1.z - p2.z) ** 2.
    sqrt (distance_squared p1 p2)

let apply_gravity (u: body[]) (on: int) (towards: int) duration =
    let force =
        let G = 6.673e-11
        G*((u.[on].mass * u.[towards].mass) /
           ((u.[on].position.x - u.[towards].position.x) ** 2.
            + (u.[on].position.y - u.[towards].position.y) ** 2.
            + (u.[on].position.z - u.[towards].position.z) ** 2.))
    let direction =
        let v = u.[towards].position - u.[on].position
        v <* (1. / sqrt(v.x * v.x + v.y * v.y + v.z * v.z))
        v
    let a = force / u.[on].mass
    u.[on].velocity <+ (direction * (a * duration))

let update_position (u: body[]) (b: int) duration =
    u.[b].position <+ u.[b].velocity * duration

(* > Many_body_test.go step1 100;;
Real: 00:00:17.752, CPU: 00:00:17.799, GC gen0: 463, gen1: 4, gen2: 1 *)
let step1 (universe: body[]) duration =
    for i=0 to universe.Length - 1 do
        for j=0 to universe.Length - 1 do
            if not (i = j) then
                apply_gravity universe i j duration
    for i=0 to universe.Length - 1 do
        update_position universe i duration

(* > Many_body_test.go step5 100;;
Real: 00:00:05.647, CPU: 00:00:19.141, GC gen0: 462, gen1: 1, gen2: 0 *)
let step5 (universe: body[]) duration =
    Parallel.For(0, universe.Length, fun i ->
        for j = 0 to universe.Length - 1 do
            if not (i = j) then
               apply_gravity universe i j duration)
    |> ignore
    for i=0 to universe.Length - 1 do
        update_position universe i duration

module Two_body_test =
    (* This test simulates a 1000kg object in a roughly circular orbit 
       around the moon *)
    let big =
        body(velocity = vector(x=0.,y=0.,z=0.),
             position = vector(x=0.,y=0.,z=0.),
             mass = 7.34e22)

    let small = 
        body(position = vector(x=1750000.,y=0.,z=0.),
             velocity = vector(x=0.,y=1673.,z=0.),
             mass = 1000.)
           
    let universe = [|big; small|]

    let go () =
        for i=1 to 6000 do 
            step5 universe 0.1
            if distance big.position small.position < 1737100. then 
                failwith ("collision at step " + i.ToString())
        ((distance universe.[0].position universe.[1].position - 1737000.)/1000.,
          universe.[1])

module Many_body_test = 
    let go step size =
        let universe =
            let r = new System.Random(1232)
            let pos () = r.NextDouble () * 1000000000.
            let v () = r.NextDouble () * 500.
            let mass () = r.NextDouble () * 1e22
            Array.init size (fun _ -> 
                body(position = vector(x = pos (), y = pos (), z = pos ()),
                     velocity = vector(x = v (), y = v (), z = v ()),
                     mass = mass ()))
        for i = 1 to 6000 do
            step universe 0.1
        (* not sure what to check here ... *)

[<EntryPoint>]
let main argv =
    Many_body_test.go step5 1000
    0

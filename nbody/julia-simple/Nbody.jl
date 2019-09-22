# julia> @time Nbody.many_body_test(1000)
# elapsed time: 287.064034175 seconds (2469400 bytes allocated)

# 4 cores hyperthreading on
# julia> @time Nbody.many_body_test1(1000)
# elapsed time: 67.893861901 seconds (506163992 bytes allocated, 0.32% gc time)

module Nbody

immutable Vector
    x :: Float64
    y :: Float64
    z :: Float64
end

+(a :: Vector, b :: Vector) = Vector(a.x + b.x, a.y + b.y, a.z + b.z)
-(a :: Vector, b :: Vector) = Vector(a.x - b.x, a.y - b.y, a.z - b.z)
*(a :: Vector, b :: Float64) = Vector(a.x * b, a.y * b, a.z * b)
*(a :: Float64, b :: Vector) = b * a
dotp(a :: Vector, b :: Vector) =  a.x * b.x + a.y * b.y + a.z * b.z

immutable Body
    position :: Vector
    velocity :: Vector
    mass :: Float64
end

function distance_squared(v1 :: Vector, v2 :: Vector)
    (v1.x - v2.x) ^ 2. + (v1.y - v2.y) ^ 2. + (v1.z - v2.z) ^ 2.
end

distance(v1 :: Vector, v2 :: Vector) = sqrt(distance_squared(v1, v2))

function gravity(b1 :: Body, b2 :: Body)
    G = 6.673e-11
    (G * b1.mass * b2.mass) / distance_squared(b1.position, b2.position)
end

normalize(v :: Vector) = v * (1.0 / sqrt(v.x * v.x + v.y * v.y + v.z * v.z))
direction(v1 :: Vector, v2 :: Vector) = normalize(v2 - v1)

function apply_force(on :: Body, towards :: Body, 
                     magnitude :: Float64, duration :: Float64)
    a = magnitude / on.mass
    dir = direction(on.position, towards.position)
    deltav =  dir * (a * duration)
    Body(on.position, on.velocity + deltav, on.mass)
end

function update_position(b :: Body, duration :: Float64)
    Body(b.position + (b.velocity * duration), b.velocity, b.mass)
end

function update_velocities(universe :: Array{Body, 1}, duration :: Float64)
    len = length(universe)
    for i in 1:len
        acc = universe[i]
        for j in 1:len
            if i != j then
                b1 = universe[i]
                b2 = universe[j]
                acc = apply_force(b1, b2, gravity(b1, b2), duration)
            end
        end
        universe[i] = acc
    end
end

function update_velocities(universe :: SharedArray{Body, 1},  
                           duration :: Float64)
    len = length(universe)
    id = myid()
    nprocs = length(procs())

    for i in 1:len
        if (i % nprocs) + 1 == id then
            acc = universe[i]
            for j in 1:len
                if i != j then
                    b1 = universe[i]
                    b2 = universe[j]
                    acc = apply_force(b1, b2, gravity(b1, b2), duration)
                end                
            end
            universe[i] = acc
        end
    end
end

function update_positions(universe :: AbstractArray{Body, 1},
                          duration :: Float64)
    for i in 1:length(universe)
        universe[i] = update_position(universe[i], duration)
    end
end

function two_body_test()
    step_duration = 0.1
    universe = 
    [ Body(Vector(0., 0., 0.), Vector(0., 0., 0.), 7.34e22),
      Body(Vector(1750000., 0., 0.), Vector(0., 1673., 0.), 1000.) ]
    () -> begin
        d = 0
        for i in 1:6000
            update_velocities(universe, step_duration)
            update_positions(universe, step_duration)
            d = distance(universe[1].position, universe[2].position)
            if d < 1737100. then
                error("collision at step $i")
            end
        end
        ((d - 1737100) / 1000, universe[2])
    end
end

function many_body_test(size :: Int64)
    step_duration = 0.1
    universe = begin
        r = MersenneTwister(1232)
        vec = (s) -> Vector(rand(r) * s, rand(r) * s, rand(r) * s)
        u = Array(Body, size)
        for i in 1:size
            u[i] = Body(vec(1e9), vec(500.), rand(r) * 1e22)
        end
        u
    end

    for i in 1:6000
        update_velocities(universe, step_duration)
        update_positions(universe, step_duration)
    end
end

function many_body_test1(size :: Int64)
    step_duration = 0.1
    universe = begin
        r = MersenneTwister(1232)
        vec = (s) -> Vector(rand(r) * s, rand(r) * s, rand(r) * s)
        u = SharedArray(Body, size, pids=procs())
        for i in 1:size
            u[i] = Body(vec(1e9), vec(500.), rand(r) * 1e22)
        end
        u
    end

    for i in 1:6000
        @sync begin
            for w in workers()
                @async remotecall_wait(w, update_velocities, universe,
                                       step_duration)
            end
            @async update_velocities(universe, step_duration)
        end
        update_positions(universe, step_duration)
    end
end

end # module

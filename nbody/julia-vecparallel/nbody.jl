# with sqrt 1 core doubles: elapsed time: 257.528459039 seconds (331288 bytes allocated)
# with rsqrtss 1 core doubles: elapsed time: 249.983302256 seconds (331288 bytes allocated)
# with rsqrtss 1 core singles: elapsed time: 203.386449756 seconds (279320 bytes allocated)
# with sqrt 1 core singles: elapsed time: 203.27939849 seconds (279320 bytes allocated)
# partly vectorized on 1 core: elapsed time: 64.84706095 seconds (24637120 bytes allocated)

module Nbody

immutable Universe
    # each column is a vector in R3. The combination of one column of
    # each array represents a body.
    position :: SharedArray{Float32, 2}
    velocity :: SharedArray{Float32, 2}
    mass :: SharedArray{Float32, 1}
    tmp :: SharedArray{Float32, 1} # used for intermediate vectorized ops
end

function gravity(position :: SharedArray{Float32, 2}, 
                 mass :: SharedArray{Float32, 1}, 
                 accel :: SharedArray{Float32, 1},
                 i :: Int64)
    @inbounds begin
        G = 6.673e-11 # gravity
        x = position[1, i]
        y = position[2, i]
        z = position[3, i]

        @simd for j = 1:size(position, 2)
            r1 = x - position[1, j]
            r2 = y - position[2, j]
            r3 = z - position[3, j]
            rsquared = r1*r1 + r2*r2 + r3*r3
            accel[j] = (G * mass[j]) / rsquared
        end

        accel[i] = 0f0
    end
    nothing
end

function update_velocities(universe :: Universe, duration :: Float32)
    len = size(universe.position, 2)
    position = universe.position
    velocity = universe.velocity
    mass = universe.mass
    accel = universe.tmp
    id = myid()
    nprocs = length(procs())

    for i = 1:len
        if (i % nprocs) + 1 == id then
            x = position[1, i]
            y = position[2, i]
            z = position[3, i]
            
            # compute gravitational forces, this will fill the accel array with
            # an acceleration on i for each body j
            gravity(position, mass, accel, i)

            for j = 1:len
                if j != i then
                    # compute the direction of the force vector i -> j
                    dir_x = position[1, j] - x
                    dir_y = position[2, j] - y
                    dir_z = position[3, j] - z

                    # compute the inverse magnitude of the force vector so we can normalize
                    # to a unit vector. Right now the magnitude is the distance between the
                    # two bodies, but we want a unit vector that points from i -> j.
                    normfact = 1f0 / sqrt(dir_x * dir_x + dir_y * dir_y + dir_z * dir_z)

                    # now normalize the vector
                    dir_x = dir_x * normfact
                    dir_y = dir_y * normfact
                    dir_z = dir_z * normfact

                    # now apply the deltav using the direction vector and the acceleration
                    velocity[1, i] += dir_x * accel[j] * duration
                    velocity[2, i] += dir_y * accel[j] * duration
                    velocity[3, i] += dir_z * accel[j] * duration
                end
            end
        end
    end
    nothing
end

function update_positions(universe :: Universe, duration :: Float32)
    BLAS.axpy!(duration, universe.velocity, universe.position)
    nothing
end

function two_body_test()
    step_duration = 1f-1
    position = SharedArray(Float32, 3, 2)
    velocity = SharedArray(Float32, 3, 2)
    mass = SharedArray(Float32, 2)
    tmp = SharedArray(Float32, 2)
    # the moon
    position[1, 1] = 0f0
    position[2, 1] = 0f0
    position[3, 1] = 0f0
    velocity[1, 1] = 0f0
    velocity[2, 1] = 0f0
    velocity[3, 1] = 0f0
    mass[1] = 7.34f22
    # a small asteroid
    position[1, 2] = 0f0
    position[2, 2] = 1.75f6
    position[3, 2] = 0f0
    velocity[1, 2] = 0f0
    velocity[2, 2] = 1.673f3
    velocity[3, 2] = 0f0
    mass[2] = 1f3
    universe = Universe(position, velocity, mass, tmp)
    () -> begin
        d = 0
        for i in 1:6000
            @sync begin
                for w in workers()
                    @async remotecall_wait(w, update_velocities, universe, step_duration)
                end
                @async update_velocities(universe, step_duration)
            end
            update_positions(universe, step_duration)
            d = sqrt(  (universe.position[1, 1] - universe.position[1, 2]) ^ 2f0
                     + (universe.position[2, 1] - universe.position[2, 2]) ^ 2f0
                     + (universe.position[3, 1] - universe.position[3, 2]) ^ 2f0)
            if d < 1.7371f6 then
                error("collision at step $i")
            end
        end
        ((d - 1.7371f6) / 1f3, universe)
    end
end

function many_body_test(size :: Int64)
    step_duration = 1f-1
    universe = begin
        r = MersenneTwister(1232)
        vec = (a, i, s) -> begin 
            a[1, i] = rand(r) * s 
            a[2, i] = rand(r) * s
            a[3, i] = rand(r) * s
        end
        position = SharedArray(Float32, 3, size)
        velocity = SharedArray(Float32, 3, size)
        mass = SharedArray(Float32, size)
        tmp = SharedArray(Float32, size)
        for i in 1:size
            vec(position, i, 1f9)
            vec(velocity, i, 5f2)
            mass[i] = rand(r) * 1f22
        end
        Universe(position, velocity, mass, tmp)
    end

    for i in 1:6000
        @sync begin
            for w in workers()
                @async remotecall_wait(w, update_velocities, universe, step_duration)
            end
            @async update_velocities(universe, step_duration)
        end
        update_positions(universe, step_duration)
    end
end

end # module

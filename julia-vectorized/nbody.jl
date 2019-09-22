# with sqrt 1 core doubles: elapsed time: 257.528459039 seconds (331288 bytes allocated)
# with rsqrtss 1 core doubles: elapsed time: 249.983302256 seconds (331288 bytes allocated)
# with rsqrtss 1 core singles: elapsed time: 203.386449756 seconds (279320 bytes allocated)
# with sqrt 1 core singles: elapsed time: 203.27939849 seconds (279320 bytes allocated)
# vectorized on 1 core: elapsed time: 53.75447063 seconds (247464 bytes allocated)

module Nbody

immutable Universe
    # each column is a vector in R3. The combination of one column of
    # each array represents a body.
    position :: Array{Float32, 2}
    velocity :: Array{Float32, 2}
    mass :: Array{Float32, 1}
    accel :: Array{Float32, 1} # temporary intermediate result
    normfact :: Array{Float32, 1} # temporary intermediate result
end

function gravity(position :: Array{Float32, 2}, 
                 mass :: Array{Float32, 1}, 
                 accel :: Array{Float32, 1},
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

function normalize(position :: Array{Float32, 2}, norm :: Array{Float32, 1}, i :: Int64)
    len = size(position, 2)
    @inbounds begin
        x = position[1, i]
        y = position[2, i]
        z = position[3, i]

        @simd for j = 1:len
            dir_x = position[1, j] - x
            dir_y = position[2, j] - y
            dir_z = position[3, j] - z
            norm[j] = dir_x * dir_x + dir_y * dir_y + dir_z * dir_z
        end

        # manually vectorize computation of the inverse square root since julia's vectorizer can't
        steps = div(len, 4)
        for j = 1:steps
            ccall((:rsqrtps, "./rsqrtps.so"), Void, (Int64, Ptr{Float32}), (j - 1) * 4, norm)
        end

        # ok, this is a bit odd as we're using a much more accurate sqrt function to finish off
        # the end bits.
        for j = (4*steps + 1):len
            norm[j] = 1f0 / sqrt(norm[j])
        end
        
        norm[i] = 0f0
    end
end

function update_velocities(universe :: Universe, duration :: Float32)
    len = size(universe.position, 2)
    position = universe.position
    velocity = universe.velocity
    mass = universe.mass    
    accel = universe.accel
    normfact = universe.normfact

    @inbounds for i = 1:len
        x = position[1, i]
        y = position[2, i]
        z = position[3, i]
        
        # compute gravitational forces, this will fill the accel array with
        # an acceleration on i for each body j
        gravity(position, mass, accel, i)
        normalize(position, normfact, i)

        @simd for j = 1:len
            # compute the direction of the force vector i -> j
            dir_x = position[1, j] - x
            dir_y = position[2, j] - y
            dir_z = position[3, j] - z

            # now apply the deltav using the direction vector and the acceleration
            velocity[1, i] += dir_x * normfact[j] * accel[j] * duration
            velocity[2, i] += dir_y * normfact[j] * accel[j] * duration
            velocity[3, i] += dir_z * normfact[j] * accel[j] * duration
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
    universe =
      Universe([0f0 1.75f6; 0f0 0f0; 0f0 0f0],
               [0f0 0f0; 0f0 1.673f3; 0f0 0f0],
               [7.34f22, 1f3],
               [0f0, 0f0],
               [0f0, 0f0])
    () -> begin
        d = 0
        for i in 1:6000
            update_velocities(universe, step_duration)
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
        position = Array(Float32, 3, size)
        velocity = Array(Float32, 3, size)
        mass = Array(Float32, size)
        accel = Array(Float32, size)
        normfact = Array(Float32, size)
        for i in 1:size
            vec(position, i, 1f9)
            vec(velocity, i, 5f2)
            mass[i] = rand(r) * 1f22
        end
        Universe(position, velocity, mass, accel, normfact)
    end

    for i in 1:6000
        update_velocities(universe, step_duration)
        update_positions(universe, step_duration)
    end
end

end # module

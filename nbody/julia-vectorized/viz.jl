#! /usr/bin/env julia
using OpenGL
@OpenGL.version "1.0"
@OpenGL.load
using GLUT

include("Nbody1.jl")

# intialize variables

global window

function build_universe(size :: Int64)
    r = MersenneTwister(1232)
    vec = (a, i, s) -> begin
        a[1, i] = rand(r) * s * (randbool() ? : 1f0 : -1f0)
        a[2, i] = rand(r) * s * (randbool() ? : 1f0 : -1f0)
        a[3, i] = 0f0
#        a[3, i] = rand(r) * s * (randbool() ? : 1f0 : -1f0)
    end
    position = Array(Float32, 3, size)
    velocity = Array(Float32, 3, size)
    mass = Array(Float32, size)
    accel = Array(Float32, size)
    for i in 1:size
        vec(position, i, 1f9)
        vec(velocity, i, 0f0)
#        mass[i] = rand(r) * 1f23
        mass[i] = 1f23
    end
    Nbody.Universe(position, velocity, mass, accel)
end

global universe = build_universe(100)

# global universe = Nbody.Universe([0f0 1.75f6; 0f0 0f0; 0f0 0f0],
#                                  [0f0 0f0; 0f0 1.673f3; 0f0 0f0],
#                                  [7.34f22, 1f3],
#                                  [0f0, 0f0])


width  = 1280
height = 1024

# function to init OpenGL context

function initGL(w::Integer,h::Integer)
    glViewport(0,0,w,h)
    glClearColor(0.0, 0.0, 0.0, 0.0)
    glClearDepth(1.0)			 
    glDepthFunc(GL_LESS)	 
    glEnable(GL_DEPTH_TEST)
    glShadeModel(GL_SMOOTH)

    glMatrixMode(GL_PROJECTION)
    glLoadIdentity()

    gluPerspective(100,w/h,0.1,100.0)

    glMatrixMode(GL_MODELVIEW)
end

# prepare Julia equivalents of C callbacks that are typically used in GLUT code

function ReSizeGLScene(w::Int32,h::Int32)
    if h == 0
        h = 1
    end

    glViewport(0,0,w,h)

    glMatrixMode(GL_PROJECTION)
    glLoadIdentity()

    gluPerspective(100,w/h,0.1,100.0)

    glMatrixMode(GL_MODELVIEW)
   
    return nothing
end

_ReSizeGLScene = cfunction(ReSizeGLScene, Void, (Int32, Int32))

scale(x :: Float32) = x / 1f8

function DrawGLScene()
    global universe
    pos = universe.position
    for i=1:200 # 20 seconds
        Nbody.update_velocities(universe, 1f-1)
        Nbody.update_positions(universe, 1f-1)
    end

    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT)
    glLoadIdentity()

    glColor(1.0,1.0,1.0)

    glTranslate(0.0, 0.0, -10.0)

    glBegin(GL_POINTS)
      for i = 1:size(pos, 2)
          glVertex(scale(pos[1, i]), scale(pos[2, i]), scale(pos[3, i]))
      end
    glEnd()

    glutSwapBuffers()
   
    return nothing
end
   
_DrawGLScene = cfunction(DrawGLScene, Void, ())

function keyPressed(the_key::Char,x::Int32,y::Int32)
    if the_key == int('q')
        glutDestroyWindow(window)
    else 
        print("key: $the_key\n")
    end

    return nothing # keyPressed returns "void" in C. this is a workaround for Julia's "automatically return the value of the last expression in a function" behavior.
end

_keyPressed = cfunction(keyPressed, Void, (Char, Int32, Int32))

# run GLUT routines

glutInit()
glutInitDisplayMode(GLUT_RGBA | GLUT_DOUBLE | GLUT_ALPHA | GLUT_DEPTH)
glutInitWindowSize(width, height)
glutInitWindowPosition(0, 0)

window = glutCreateWindow("NeHe Tut 2")

glutDisplayFunc(_DrawGLScene)
#glutFullScreen()

glutIdleFunc(_DrawGLScene)
glutReshapeFunc(_ReSizeGLScene)
glutKeyboardFunc(_keyPressed)

initGL(width, height)

glutMainLoop()

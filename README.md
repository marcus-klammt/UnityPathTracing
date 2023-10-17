# About

This path tracer works by manipulating the camera buffer by replacing the render texture with our own, which we create via a surface shader, which creates a path traced image of our objects in the scene. Currently, this project only supports spheres as scene objects. 

# Screenshots
![Capture](https://github.com/marcus-klammt/UnityPathTracing/assets/55520137/41aa57ec-1386-41e3-8ccf-d0953abdde53)
![Capture1](https://github.com/marcus-klammt/UnityPathTracing/assets/55520137/4a84e57f-ade7-4e32-a67c-c5af5f2057e5)
![Capture4](https://github.com/marcus-klammt/UnityPathTracing/assets/55520137/b7606fc1-a618-4b48-abe4-b48b58888298)

  
# Features

* True path tracing with user input for per-pixel samples, bounces, and much more
* Uses a temporal denoiser, with two types. One is a temporary temporal buffer, using only 10 frames of data before moving onto new frames. The other option deletes no data. The first option should be used while setting up a scene, while the second option should be used for final render images
* Supports a basic skybox, which uses a scenes directional light
* Materials have a smoothness value, with a value of 1 being a perfectly reflected ray
* Non-skybox lighting depends on emission lighting from the material properties
* Supports different shadow colors

# Limitations

* Temporal denoising produces a ton of ghosting, even on the first option, and should not be used in any real-time applications
* Only supports sphere objects
* Each object must have a PathTracedObject.cs attached to it
* Performance is generally not amazing
* Shadow coloring is based on pixel color, not light intensity


# Pre-requisites 
* Requires Unity 2020.3.37f1

# Credits

* The rendering pipeline is based on Sebastian Lague's ray tracing video, which is based on Ray Tracing in One Weekend.
Shader Helper is also from the same source.

  

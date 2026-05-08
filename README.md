HOW TO USE

Step 1
Download the project

Step 2
Open the project in a version of Godot that supports compute shaders

Step 3
Run the project

Step 4 (Optional)
Modify the settings in the node.gd script (line 84-91 for agent behavior, line 98-99 for pheromone behavior)


WHAT IS THIS?

This is a project that simulates boids on the GPU using compute shaders. Due to this architecture, it is able to run extremely fast. 
Each boid is instructed to follow the trail of pheromone and leave pheromone where it travels, leading to an ant colony type activities.
This is heavily inspired by Sebastian Lague's video on boids: https://www.youtube.com/watch?v=X-iSQQgOd1A. It goes into the details of how boids work.
This code was AI generated.

# Scent Pathfinding Method

Using this method from this site, but adapted for 3D:
* [Enemy AI: chasing a player without Navigation2D or A* pathfinding](https://abitawake.com/news/articles/enemy-ai-chasing-a-player-without-navigation2d-or-a-star-pathfinding)
* While made for 2D, this provides an excellent step-by-step method of getting it set up.

This method however actually works *better* for 3D since you can change enemy behavior based on the Z-axis.
* Can allow enemies to jump over fences.
* Stop following the player if the player reached a height too high to follow.

Benefits to using this method:
* No need to create a Navigation node in the scene for pathfinding.
* Works better for enemies to appear to not know their surroundings well.
    * Why would a zombie know the intricate layout of an old abandoned castle for instance?
    * Many games make unintelligent creatures seem far more intelligent than they are because they can magically know every single turn they need to take to get to the player even if they are entirely across the map.
* Instead, this method works more like the player leaving a trail.
    * This practically works the same as a scent trail that the player is leaving behind, but I like to use the term "Breadcrumb" better because it is more accurate to what it is.
    * Still, I think this may be more widely known as the "Scent" method.

# Setup for the Scent Method of pathfinding
## (everything needed for the video -- including setup before the scent method)
* Have an array(s) of scents stored somewhere that the enemies can access.
    * Possibly need multiple arrays stored in various places.
    * One for each target that the enemy is following.
    * For the tutorial, I will store this array inside a singleton, but it may be better to store this inside the player?
        * Probably will store inside the player for this video since it should be one per target.
        * May need to have a function that the enemies know that the player will have.
            * Store a constant inside a singleton that will throw an error if the target the enemy is following does not have a Scent array???
* Need to create a Scent scene
    * Have the scent add itself to the target's Scent array
    * Use push front to push the most recent one to the front of the array
    * Draw the shapes at first to see how well they are spaced out
    * Important functions:
```py
# Removes a scent if the limit is reached
func removeScent():
  if FollowerTracker.scents.size() > max_scents:
    FollowerTracker.scents.erase(global_transform.origin)
    queue_free()
    
func decayRemove():
  FollowerTracker.scents.erase(global_transform.origin)
  queue_free()
```
* Need to add signals for:
    * Scent Limit
    * Scent Addition
* Need to add reference to Scent scene in player script so that way the player spawns them.
    * Other potential targets will need this as well of course.
    * Create a timer to spawn the Scents at intervals (0.35 seconds good value?)
        * Ensure you pick a good time based off of your:
            * Player's movement speed
            * Scale of your game
                * Smaller scales will need smaller times.
        * Can choose between spawning on scent timer only, or only when moving *and* when the timeout happens
        * Connect the timer to an addScent function.
            * Emit the Scent Addition signal inside that function
* Have a string for "Scent" stored somewhere
    * Why this is needed?
        * Possibly for groups for enemies to react differently to the player group versus the scent group?
* Need to create a function that iterates through the scents and finds the correct one.
    * Enemy will iterate through each Scent and return the index of the one it finds from a ray shot:
```cpp
// Sorry for C++ for anyone reading this, but here is how I implemented this
// function in case you want to add this as a module

// I will also add a version of this project with the C++ directory I use to
// make this work and will make a sequel to this that showcases how to speed
// this up using modules.
int AI::followScentTrail(const Array& vec3s)
{
    // iterating through the index of each scent
    for (int idx = 0; idx < vec3s.size(); idx++)
    {
        // shoot a ray towards each scent, and see if one hits
        Dictionary scentResult = rayShot(get_global_transform().origin, vec3s[idx]);
        if (scentResult.size() > 0)
        {
            // if the group we collided with is a Scent, then return that index
            Spatial* scent = Object::cast_to<Spatial>(scentResult["collider"]);
            if (scent != NULL && scent->is_in_group(scentGroup))
            {
                return idx;
            }
        }
    }
    return -1; // no scent found
}
```
* The `rayShot` method can be found here:
```py
# Shortcut function so that I don't have to remember how to write this
func rayShot(vec1 : Vector3, vec2 : Vector3):
  var space_state = get_world().direct_space_state
  return space_state.intersect_ray(vec1, vec2, [self])
```
* **NOTE**: Probably needs to be updated for Godot 4.6.x?


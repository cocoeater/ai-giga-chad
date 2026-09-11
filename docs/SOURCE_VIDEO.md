# Source video research: "4D Animations"

## Metadata
- **Title:** 4D Animations
- **Channel:** Default Cube (CG Matter / cgmatter.com)
- **URL:** https://www.youtube.com/watch?v=7iXkP3jI3YE
- **Uploaded:** 2025-12-05
- **Length:** 3:05
- **Views:** ~883,202 (at research time)
- **Likes:** ~33,353
- **Category:** Film & Animation
- **Description:** .blend files for the project are on https://www.cgmatter.com/member (members only)

## Core concept (this is the key to recreating it)
Stop thinking of an animation as "a 3D object + a time dimension." Think of it
as a single **4-dimensional spatial object** (X, Y, Z + time) that always
exists. Playing the animation = taking a flat 3D **cross-section** of that 4D
object and sliding it through.

The animation is made of **points**, and crucially **every point gets its own
independent timeline (playhead)**. Normally all playheads are in sync. The
effects come from moving each point's personal playhead independently.

## Effects shown, in order (timestamps approx.)
1. **0:00–0:25 Normal scrubbing** — play forward/backward, 2x, 4x = cross-section moving at different speeds.
2. **0:25–1:05 The 4D idea** — frames are just slices of one 4D object; one point shown with its own timeline.
3. **~1:05–1:25 LINEAR TIME DISPLACEMENT** — point timelines staggered along a spatial gradient (some in the future, some in the past). Looks like a wave/shear sweeping through the object. Same family as his old 2D displacement videos.
4. **~1:25–1:45 "TENET EFFECT"** — one half of the object plays forward in time, the other half plays backward.
5. **~1:45–2:15 NOISE TIME OFFSET** — each point's time offset driven by random/noise field. Looks like Nightcrawler teleporting or Harry Potter Apparition warping.
6. **~2:15–2:40 SIDEWAYS THROUGH TIME** — cross-section rotated 90°: each point exists at EVERY moment at once → you see the entire swept path/trail of every point; filling the timeline shows every state the object was ever in (a 4D sculpture).
7. **~2:40–2:55 SLIDING WINDOW** — a small rectangular window swept across the time axis, like an MRI slice.
8. **~2:55–3:05 INTERPOLATION + MRI** — samples between integer frames are interpolated so motion is perfectly smooth; the whole thing is the 3D→time-axis equivalent of an MRI brain scan.

## Implementation recipe (engine-agnostic)
1. **Bake** the base animation: for every point p and every frame f, store
   position P[p][f] (the 4D dataset, fully predetermined).
2. At render time each point samples:
   `frame(p) = globalTime * dir(p) + offset(p)`
   - linear sweep:  `offset(p) = k * dot(axis, position(p))`
   - Tenet:         `dir(p) = sign(dot(axis, position(p)))`
   - noise warp:    `offset(p) = k * noise(position(p) * frequency)`
   - sideways/trails: render MANY frame samples per point at once (a window of f), e.g. clones or a trail/ribbon.
3. Interpolate between baked frames: lerp P[p][floor(f)] -> P[p][ceil(f)].

## Roblox-specific mapping
- Roblox can't do per-vertex geometry nodes like Blender; represent the
  animated object as many small Parts (point cloud / blocky/voxel model), or
  as a rig of Parts with baked CFrames per frame.
- Bake to a Lua table: `Data[partIndex][frame] = CFrame`.
- A single RenderStepped loop writes each part's CFrame from its personal
  sampled frame.
- Sideways/trail mode: clone the parts per sampled frame (transparency
  gradient), or use Trail/Beam instances.

## Full transcript
Here's a dumb little animation and the corresponding timeline that when I hit
play, it just kind of goes forwards. Similarly, if I play it backwards, we go
backwards on the timeline. Fast forward means take the cross-section, go
twice as fast. 4x means go four times as fast. We're used to stuff like that.
Now, a question I have is what happens when we take the timeline and go
sideways or we spin around it? Does that make any sense? Does it mean
anything? It turns out yes. If we stop thinking of this animation as a 3D
thing with like a time dimension, but think of it as this like four-dimensional
spatial thing that always exists, you could think of going across the timeline
as taking cross-sections of this four-dimensional object. So, we're just
extracting various frames essentially. But because we're doing this on the
computer, we have some control. This animation is composed of points
essentially that are moving. I can take a single one of these points and it has
its own timeline. Again, it can go forwards in time, backwards. It's just one
point of the animation. Of course, every point gets its own independent
timeline that usually are in sync. They all move together, but it doesn't have
to be the case. So, I'm going to stagger the points so that some exist in the
future, some in the present, and there's kind of this linear gradient. Well, in
that case, we get this kind of time displacement in 3D kind of animation.
We're just taking a different cross-section. It's nothing fancy. But it reminds
me of these displacement things I did a while ago in 2D. We're used to that.
Well, that leads to the question, what are interesting cross-sections we can
take now that we have each point individually? Well, what if one half goes
forwards and the other half goes backwards? I call this like the Tenet effect.
Or what if instead of kind of like a linear displacement through time? We just
kind of have it randomized through some kind of like noise offset or something
like that. Now, we get this very cool, I don't know, I kind of think of it as
like the Nightcrawler teleporting or the Harry Potter warping, whatever it's
called. They call it apparition or apparating. But that still doesn't answer
the question of what is like going sideways through time. So far, we've only
done offsets. Well, if I look at a single point and kind of take its sideways
cross-section, that means it exists at every point in time all at once. We're
taking the cross-section of everywhere that it's been. Do this for all the
points. And this is what a horizontal cross-section would look like. Just kind
of going through the points. I guess if I was to fill in this timeline
completely, we get, you know, every state that it's ever been in. If I take
kind of like a little rectangle here... I take a little rectangle and it's like
a sliding window. Then we get various... you see what it is. So what's another
interesting thing to do? Well, at the moment these cross-sections, these
transformations we're doing, they're kind of discrete. And what I mean by
that is if you go forwards or backwards a frame and you scrub, it's in one
state and then it's in another. But there's no way to kind of interpolate in
between. It's kind of like this discrete jumping motion. Well, if we know it's
predetermined where every single point's going to be on a frame and the next
frame and the previous one, we can easily do a nice interpolation, letting us
create all kinds of just perfectly smooth things. It also reminds me of an MRI
scan where we take a three-dimensional brain and kind of look at this
animation where we substitute one axis for time of this video playing. This is
just one dimension higher and I don't really have any other thoughts on it.
Bye.

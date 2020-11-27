# doodle-jump

The last 100m of CSC258, Doodle Jump in MIPS Assembly.

This README is a WIP, currently has a few notes and ideas tossed around, nothing substantial in terms of code just yet. I will update this page as is necessary to reflect the state of the code.

## Character Movement
### Screen Wrap
In the demo, the doodle seems to wrap around the screen immediately. It's worth mentioning that we have to check for this condition on either side of the screen.

- Supposed we're on the right side of the screen, one more move to the right results in a wrap around, so we're at position `31 + 4y`, where y (row) is in [0, 31].
- We can't simply add 4 to our position to move to the next 'block', as this would move the character down a row. Instead, we have to send the right side of the character to the left most column, i.e `0 + 4y` (y is the row).

- On the other hand, if we're at `0 + 4y` and we move left, the leftmost part of the character must move to `31 + 4y` (the rightmost column).

We need to check our position everytime we try to move left/right.

### Up/Down Movement
I don't think this is too difficult to implement. This is really just a while loop (or 2) that increments and then decrements the doodle's position. I'll figure out the details later, need to focus on drawing the assets on the screen first, as well as (left/right) movement.

To be a bit more specific, moving *up* should be super easy, since the doodle will have a defined jump height. Falling down is a bit more complicated, since we might land on a platform with variable height, or hit the bottom of the screen. More on this in the collision detection section.

When the doodle is rising, if we go through a platform, we want the doodle to pass behind it, i.e, focus on repainting the doodle, not the platform.

### Collision Detection
After seeing the demo, it's pretty clear collision detection only occurs while the doodle is in free-fall. This means we can pass through platforms when we're rising, it also means we don't have to waste CPU cycles doing unnecessary collision detection, since we only check in the "falling" loop.

In the demo, if any part of the bottom of the doodle hits the platform, the doodle will jump. So if `2/3` of the doodle is hanging over the edge of the platform, but at least *1* bottom block touches the top of the platform, the doodle jumps.

## Painting the Canvas

### Drawing Platforms
In the demo, the platforms were always at the same height. The lowest platform on the map is at the bottom of the display, the highest platform is (seemingly) 1 block beneath the doodle's `max_height`. This simplifies things considerably.

- The only time we ever need to think about platform height is when redrawing the map, and in this case, if platform `p_i` is at position `i = {1, 2, 3}`, then in general, `p_i -> p_{i-1}`, thus `p_1` (bottom platform) disappears, and a new platform enters from the top.
- If we have defined heights, it's just a matter of writing a loop that increments the current row to the destination row. Keep in mind the fact that the lower you are on the screen, the higher your row # is.

### Redrawing after a high jump
Sometimes the doodle will jump high enough to warrent moving the map. In this case, as is done in the demo, we will stall the doodle at a defined `max_height` and move the map until the jump loop has completed and the doodle starts to fall.

One benefit of this approach (combined with our "collision detection on fall" idea) is that the doodle will never jump *above* the map, even in the case where the doodle lands on a platform positioned at the `max_height`. In this scenario, the doodle would just stay put while the map updated once more.

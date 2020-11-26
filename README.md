# doodle-jump
---
## Character Movement

### Screen Wrap
In the demo, the doodle seems to wrap around the screen immediately. It's worth mentioning that we have to check for this condition on either side of the screen.

    - Supposed we're on the right side of the screen, one more move to the right results in a wrap around, so we're at position `31 + 4y`, where y (row) is in [0, 31].
    - We can't simply add 4 to our position to move to the next 'block', as this would move the character down a row. Instead, we have to send the right side of the character to the left most column, i.e `0 + 4y` (y is the row).

    - On the other hand, if we're at `0 + 4y` and we move left, the leftmost part of the character must move to `31 + 4y` (the rightmost column).

We need to check our position everytime we try to move left/right.

### Up/Down Movement
I don't think this is too difficult to implement. This is really just a while loop (or 2) that increments and then decrements the doodle's position. I'll figure out the details later, need to focus on drawing the assets on the screen first, + left right movement.

To be a bit more specific, moving **up** should be super easy, since the doodle will have a defined jump height. Falling down is a bit more complicated, since we might land on a platform with variable height, or hit the bottom of the screen. More on this in the collision detection section.

### Collision Detection
After seeing the demo, it's pretty clear collision detection only occurs while the doodle is in free-fall. This means we can pass through platforms when we're rising, it also means we don't have to waste CPU cycles doing unnecessary collision detection, since we only check in the "falling" loop.

---
## Painting the Canvas
### Redrawing after a high jump
Sometimes the doodle will jump high enough to warrent moving the map. In this case, as is done in the demo, we will stall the doodle at a defined `max_height` and move the map until the jump loop has completed and the doodle starts to fall.

One benefit of this approach (combined with our "collision detection on fall" idea) is that the doodle will never jump *above* the map, even in the case where the doodle lands on a platform positioned at the `max_height`. In this scenario, the doodle would just stay put while the map updated once more.

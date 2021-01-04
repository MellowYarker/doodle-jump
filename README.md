# doodle-jump

A Doodle Jump like game written in 32 bit MIPS Assembly for CSC258 - Computer Organization.

To run the program, install [MARS](http://courses.missouristate.edu/kenvollmar/mars/download.htm) (MIPS Assembler and Runtime Simulator), you'll need Java 9+.

Just a bit of context, the game runs alright but depending on your hardware it can be a bit glitchy. Also keep in mind that MARS is a simulation environment running on Java so after some time the performance will take a pretty substantial hit.

## Setup
1. Open MARS, then navigate to the toolbar and select `File`, find `doodlejump.s` and open it.
2. Once the file has loaded, click the screwdriver and wrench icon next to the play button. This assembles the program.
3. Back up by the toolbar, select `Tools`, then `Keyboard and Display MMIO Simulator`. A window should open, click the *Connect to MIPS* button.
4. Click `Tools` one last time, then open `Bitmap Display`. Make sure your settings match the image below then click *Connect to MIPS*.
- ![alt text](https://github.com/MellowYarker/doodle-jump/blob/main/media/images/bitmap.png)
5. Finally, press the *green* play button beside the screwdriver and wrench icon. One last thing, make sure the execution speed slider is set to *Run speed at max (no interaction)*, otherwise you'll see the frames get painted.

## How to play
You can move the doodle left or right by pressing `j` or `k` respectively. Once the program is running (after *step 5* in the **Setup** section), press `s` to start the game. If your doodle character dies, you can press `s` to restart. Finally, you can shoot by pressing `spacebar`, though there aren't any enemies so... yeah.

## About the Game
The following gifs are not representative of the game speed. They're considerably slower.

### Platform Types
There are 4 types of platforms in the game. Green platforms are the default platforms, they don't do anything special, so there's not much to say.

**Disappearing Platforms**
- These platforms will disappear after your character lands on them. Make sure to position yourself so that you can land on the next platform quickly.
![alt text](https://github.com/MellowYarker/doodle-jump/blob/main/media/gifs/disappearing_platform.gif)

**Shifting Platforms**
- These platforms will shift randomly to the side once your character lands on them.
![alt text](https://github.com/MellowYarker/doodle-jump/blob/main/media/gifs/shift_platform.gif)

**Moving Platforms**
- These platforms are by far the trickiest. They constantly move across the screen and bounce off the walls.
![alt text](https://github.com/MellowYarker/doodle-jump/blob/main/media/gifs/moving_platform.gif)

### Wrapping Through the Screen
There will be times when getting to the next platform is nearly impossible going the usual route, instead, you will have to go through the wall.
![alt text](https://github.com/MellowYarker/doodle-jump/blob/main/media/gifs/screen_wrap.gif)

### Shooting
Mad at the moving platforms? Press `space` to let out some steam. Don't worry, it won't break the platforms :)
![alt text](https://github.com/MellowYarker/doodle-jump/blob/main/media/gifs/space_to_shoot.gif)

## MILESTONES
A relic that I've decided to leave untouched. My progress journal,
- [x] Milestone 1
-   Draw at least three platforms.
-   Make the doodle jump and fall.
-   Redraw the map when the doodle jumps to the maximum height.
- [x] Milestone 2
-   Handle keyboard input so when the user presses: (*j* => move left) | (*k* => move right)
-   Allow the doodle to move through the sides of the screen.
- [x] Milestone 3
-   Randomize the platform locations.
-   Start game when player presses *s* key.
-   End the game when the doodle falls into an invalid area.
- [x] Milestone 4
-   Upgrade to 512x512 display
-   Add score counter to display
-   Add game over/retry at end game
- [x] Milestone 5
-   Add gravity.
-   Add 3 new platform types (horizontal movement, disappear when landed on, shift when landed on).
-   Added sound effects.
-   Gave doodle the ability to shoot.

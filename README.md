# doodle-jump

A Doodle Jump like game written in 32 bit MIPS Assembly for CSC258 - Computer Organization.

To run the program, install [MARS](http://courses.missouristate.edu/kenvollmar/mars/download.htm) (MIPS Assembler and Runtime Simulator), you'll need Java 9+.

Just a bit of context, the game runs alright but depending on your hardware it can be a bit glitchy. Also keep in mind that MARS is a simulation environment running on Java so after some time the performance will take a pretty substantial hit.

## Setup
1. Open MARS, then navigate to the toolbar and select `File`, find `doodlejump.s` and open it.
2. Once the file has loaded, click the screwdriver and wrench icon next to the play button. This assembles the program.
3. Back up by the toolbar, select `Tools`, then `Keyboard and Display MMIO Simulator`. A window should open, click the *Connect to MIPS* button.
4. Click `Tools` one last time, then open `Bitmap Display`. Make sure your settings match the image below then click *Connect to MIPS*.
### Todo: Insert image here.
5. Finally, press the *green* play button beside the screwdriver and wrench icon. One last thing, make sure the execution speed slider is set to *Run speed at max (no interaction)*, otherwise you'll see the frames get painted.

## How to play
You can move the doodle left or right by pressing `j` or `k` respectively. Once the program is running (after *step 5* in the **Setup** section), press `s` to start the game. If your doodle character dies, you can press `s` to restart. Finally, you can shoot by pressing `spacebar`, though there aren't any enemies so... yeah.

## About the Game
### Platform Types
todo: put a gif
### Wrapping Through the Screen
todo: put a gif
### Shooting
todo: put a gif

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

######################################################################
#
# CSC258H5S Fall 2020 Assembly Final Project
# University of Toronto, St. George
#
# Student: Milan Miladinovic, <student number>
#
# Bitmap Display Configuration:
#   - Unit width in pixels: 8
#   - Unit height in pixels: 8
#   - Display width in pixels: 512
#   - Display height in pixels: 512
#   - Base Address for Display: 0x10008000 ($gp)
#
# Which milestone is reached in this submission?
#   - Milestone 4
#
# Which approved additional features have been implemented?
#   1. (fill in the feature, if any)
#   2. (fill in the feature, if any)
#   3. (fill in the feature, if any)
#   ... (add more if necessary)
#
# Any additional information that the TA needs to know:
#   - (write here, if any)
#
#####################################################################
.data
    # Timers
    jump_sleep_time:    .word 80               # ms to sleep between drawing
    platform_sleep:     .word 10

    # Colours
    background:         .word 0xDAEAFC         # Background colour of the display
    doodle_colour:      .word 0xF9C09F
    platform_colour:    .word 0x00ff00

    # IO Addresses
    displayAddress:     .word 0x10008000
    keyPress:           .word 0xffff0000
    keyValue:           .word 0xffff0004

    # Program constants
    block_size:         .word 8
    display_width:      .word 512

    platform_width:     .word 12
    #num_platforms:      .word 3
    num_platforms:      .word 4
    #platform_distance:  .word 20                # vertical distance between platforms
    platform_distance:  .word 18                # vertical distance between platforms

    ROW_WIDTH:          .word 252               # This is for a 512 x 512 display.
    ROW_BELOW:          .word 256               # same column, one row below

    # Array of 3 platforms.
    #   - in both platform_arr and row_arr, the first entry is the bottom platform.
    #   - platform_arr stores the leftmost column index (col * 4, col in [0, 31-platform_width])
    #   - row_arr stores the row index (row*128, row in [0, 31])
    #       - we pick 128 because that's the index of the first block after the 1st row
    #platform_arr:       .word 0:3
    #row_arr:            .word 16128, 11008, 5888    # Store the row_indexes of each platform. Add these to displayAddress.

    platform_arr:       .word 0:4
    row_arr:            .word 16128, 11520, 6912, 2304    # Store the row_indexes of each platform. Add these to displayAddress.

    # Doodle Character
    #   - We will only store the bottom left of the doodle, the rest can easily be calculated on the fly.
    #   - We will store it's offset as a value in [0, 4092], so we have to add it to the base of the display
    #     when drawing.
    doodle_origin:      .word 0                 # Storing [0, 4092] makes bounds/collision detection easier.
    bounce_height:      .word 24                # Doodle can jump up 14 rows.
    candidate_platform: .word 0                 # Index [0 (bottom), 1, 2(top)] of the closest platform that we can fall on to. If -1, game is over (fell under map)

    score:              .word 0                 # Game score.

.text
    MAIN:
        # setup
        lw $s0, displayAddress 	# $s0 stores the base address for display, we never change it.

        # flags that indicate whether we've finished setting up or not.
        li $s5, 0   # 0 => have yet to draw platforms, 1 => starting platforms have been drawn.
        li $s7, 0   # 0 => have yet to draw doodle,    1 => starting doodle has been drawn.

        lw $a0, background      # paint the background white.
        jal FUNCTION_DRAW_BACKGROUND
        j SETUP_GAME

    # If we ever enter the game loop, just start falling.
    GAME_LOOP:
        # Rather than have a main loop, I've decided to just
        # alternate between falling and jumping. While running
        # those sections of code, we will check for user input
        # and redraw the map as necessary.
        j FALL

    # argument: $a0 = colour
    FUNCTION_DRAW_BACKGROUND:
        add $t0, $zero, $a0

        li $t1, 0
        lw $t2, block_size
        lw $t3, display_width

        mult $t2, $t3
        mflo $t2                # i < $t2 = display_width * block_size

        DRAW_BACKGROUND_LOOP:
            # first, we want to make sure we're not at the last block
            beq $t1, $t2, FINISH_BACKGROUND

            # Colour the block
            li $t3, 4
            mult $t1, $t3
            mflo $t3
            add $t3, $t3, $s0

            sw $t0, 0($t3)
            addi $t1, $t1, 1    # increment our counter.

            # go to the top of the loop.
            j DRAW_BACKGROUND_LOOP
        FINISH_BACKGROUND:
            jr $ra

    SETUP_GAME:
        # We always have 3 platforms visible.
        li $t2, 0

        # if $s5 is 0, draw the platforms, otherwise skip
        beq $s5, $t2, SET_PLATFORMS
        # if $s7 is 0, draw the doodle, otherwise skip
        beq $s7, $t2, SET_DOODLE

        # We don't need these values anymore, we will never enter the setup section again.
        li $s5, 0
        li $s7, 0

        # Wait for the signal "s" to start the game.
        IDLE:
            jal FUNCTION_READ_KEYBOARD_INPUT
            add $t0, $zero, $v0
            li $t1, 2
            beq $t0, $t1, GAME_LOOP
            j IDLE

    # In SET_PLATFORMS we determine the horizontal position of each platform.
    SET_PLATFORMS:
        la $t9, platform_arr    # our array of platform origins
        lw $s1 num_platforms
        li $t2, 0               # current platform

        GENERATE_STARTING_PLATFORMS:
            beq $s1, $t2, DRAW_STARTING_PLATFORMS

            # Generate this platform
            li $t3, 4
            mult $t2, $t3
            mflo $t3            # current offset in platform_arr

            add $t3, $t3, $t9   # platform_arr[$t2]

            lw $a0, platform_width
            addi $sp, $sp, -4
            sw $t2, 0($sp)      # store our loop var on the stack

            jal FUNCTION_GENERATE_RANDOM_PLATFORM

            lw $t2, 0($sp)      # get the loop var back from the stack
            addi $sp, $sp, 4

            add $t0, $zero, $v0 # column * 4
            sw $t0, 0($t3)      # platform_arr[$t2] = $t0

            add $t2, $t2, 1     # increment index
            j GENERATE_STARTING_PLATFORMS

        DRAW_STARTING_PLATFORMS:
            # put the platform colour on the stack before drawing.
            lw $t2, platform_colour
            addi $sp, $sp, -4
            sw $t2, 0($sp)

            jal FUNCTION_DRAW_PLATFORM_LOOP

            # set $s5 to 1 to indicate we have drawn the starting platforms.
            li $s5, 1
            j SETUP_GAME

    # In SET_DOODLE, we want to initiate the doodle above the bottom platform.
    # Since the platforms have been validated, we don't need to check any bounds.
    SET_DOODLE:
        lw $t0, platform_arr
        lw $t1, row_arr
        lw $t2, doodle_colour
        la $t3, doodle_origin

        add $t0, $t0, $t1       # $t0 = offset of the 1st block of the bottom platform
        lw $t1, ROW_BELOW
        addi $t1, $t1, -8
        sub $t0, $t0, $t1       # 1 row above, 3 blocks to the right

        # TODO: If we change the doodle_origin data structure, update the doodle's boundary here.
        sw $t0, 0($t3)          # doodle_origin = 3rd block of bottom platform

        # move the doodle's colour onto the stack
        addi $sp, $sp, -4
        sw $t2, 0($sp)
        jal FUNCTION_DRAW_DOODLE
        li $s7, 1      # $s7 = 1, so we have finished drawing the initial doodle.
        j SETUP_GAME

    # Read the keyboard input.
    #   If no/undefined keyboard input, $v0 == 0, $v1 == 0
    #   If we get keyboard input:
    #
    #   Case 1: Doodle movement (j or k key)
    #           $v0 == 1,
    #           $v1 == -1 for (j) move left, 1 for (k) move right

    #   Case 2: Restart Game (s key)
    #           $v0 == 2
    #           $v1 == 0
    #
    #   TODO: Add more values as we get to MS4+
    FUNCTION_READ_KEYBOARD_INPUT:
        lw $t0, keyPress
        lw $t0, 0($t0)
        beq $t0, 1, KEYBOARD_INPUT

        # No input
        j UNDEFINED_KEY_PRESS

        KEYBOARD_INPUT:
            lw $t1, keyValue    # location of key value
            lw $t1, 0($t1)      # value of the key that was pressed
            # j = 0x6a
            # k = 0x6b
            # s = 0x73
            beq $t1, 0x6a, HANDLE_J
            beq $t1, 0x6b, HANDLE_K
            beq $t1, 0x73, HANDLE_S
            j UNDEFINED_KEY_PRESS

            HANDLE_J:
                li $v0, 1           # Horizontal movement, $v0 = 1
                li $v1, -1
                jr $ra

            HANDLE_K:
                li $v0, 1           # Horizontal movement, $v0 = 1
                li $v1, 1
                jr $ra

            HANDLE_S:
                li $v0, 2           # Start/Restart game.
                li $v1, 0
                jr $ra

            # Essentially the same as not pressing a key at all, we don't care for it.
            UNDEFINED_KEY_PRESS:
                li $v0, 0
                li $v1, 0
                jr $ra

    # Draw the doodle starting from the bottom left block
    # We have to consider if the doodle is wrapping around the edge of the screen.
    #       Assuming a 512 x 512 display with block size 8, simple way to determine
    #       if a block is in the right most column is checking if:
    #           (OFFSET / 4) === 63 (mod 64).
    #
    #       The reasoning for the equation is as follows.
    #           Suppose a, b, and C are given integers.
    #           Then C = a*x + b*y  has integer solutions x and y <==> gcd(a, b) | C.
    #       In our case, C = OFFSET, a = 4, b = 256, as OFFSET = 4*col + 256*row.
    #       Since gcd(4, 256) = 4, and we know 4 | OFFSET, we have:
    #           C / 4 = x + 64y
    #           K = x + 64y
    #
    #       Thus, rearranging the equation we see:
    #           y = (K - x)/64
    #       Then K === x (mod 64). Since we want to know if we're in the 63 column,
    #       we let x = 63, which gives the equation:
    #           K === 63 (mod 64), where K is C (the offset) divided by 4.
    FUNCTION_DRAW_DOODLE:
        lw $t0, 0($sp)          # $t0 = the colour we're using
        addi $sp, $sp, 4

        lw $t1, doodle_origin

        # Draw the left side of the doodle
        add $t2, $t1, $s0       # recall $s0 = displayAddress
        lw $t3, ROW_BELOW

        sub $t3, $t2, $t3
        sw $t0, 0($t2)
        sw $t0, 0($t3)

        # Now we perform some bounds checks.
        # First, check if the left side of the doodle is on the edge.
        lw $t3, display_width
        lw $t4, block_size
        div $t3, $t4
        mflo $t3

        addi $t4, $zero, 4
        div $t1, $t4
        mflo $t4                # doodle_origin / 4 = K

        div $t4, $t3
        mfhi $t2                # K (mod 64)

        subi $t3, $t3, 1        # last column

        # Branch if K === 63 (mod 64)
        beq $t2, $t3, LEFT_ON_EDGE

        # It's safe to draw the middle of the doodle at this point.
        lw $t2, ROW_WIDTH
        sub $t2, $t1, $t2       # middle piece

        lw $t3, ROW_WIDTH
        lw $t4, ROW_BELOW
        add $t3, $t3, $t4

        sub $t3, $t1, $t3       # top piece, one row above middle.
        add $t2, $t2, $s0
        add $t3, $t3, $s0
        sw $t0, 0($t2)
        sw $t0, 0($t3)

        # Check if the middle of the doodle is on the edge.
        addi $t2, $t1, 4

        lw $t3, display_width
        lw $t4, block_size
        div $t3, $t4
        mflo $t3

        lw $t3, display_width
        lw $t4, block_size
        div $t3, $t4
        mflo $t3

        li $t4, 4
        div $t2, $t4
        mflo $t4                # (doodle_origin + 4) / 4 = K

        div $t4, $t3
        mfhi $t2                # K (mod) 63

        subi $t3, $t3, 1        # last column

        # Branch if K === 63 (mod 64)
        beq $t2, $t3, MIDDLE_ON_EDGE

        # TODO: If we change the doodle_origin data structure, *USE* the doodle boundary here.
        # At this point, we just complete a normal doodle drawing.
        addi $t2, $t1, 8        # bottom right

        lw $t3, ROW_BELOW
        sub $t3, $t2, $t3       # top right

        add $t2, $t2, $s0
        add $t3, $t3, $s0

        sw $t0, 0($t2)
        sw $t0, 0($t3)

        j END_DOODLE_DRAWING

        # the left side of the doodle is on the right edge of the map
        LEFT_ON_EDGE:
            # We have to draw the middle and right side of the doodle
            # on the left side of the map

            # "right side" of doodle
            # Take doodle origin and send it to the left side
            # TODO: If we change the doodle_origin data structure, *USE* the doodle boundary here.
            addi $t2, $t1, 8
            lw $t3, ROW_BELOW
            sub $t2, $t2, $t3           # bottom right

            sub $t3, $t2, $t3           # top right

            # centre
            lw $t5, ROW_BELOW
            addi $t4, $t1, 4
            sub $t4, $t4, $t5
            sub $t4, $t4, $t5           # middle block
            sub $t5, $t4, $t5           # top block

            add $t2, $t2, $s0
            add $t3, $t3, $s0
            add $t4, $t4, $s0
            add $t5, $t5, $s0

            # Draw each block
            sw $t0, 0($t2)
            sw $t0, 0($t3)
            sw $t0, 0($t4)
            sw $t0, 0($t5)

            j END_DOODLE_DRAWING

        MIDDLE_ON_EDGE:

            # TODO: If we change the doodle_origin data structure, *USE* the doodle boundary here.
            lw $t3, ROW_BELOW
            addi $t2, $t1, 8
            sub $t2, $t2, $t3           # bottom "right"
            sub $t3, $t2, $t3           # top "right"

            add $t2, $t2, $s0
            add $t3, $t3, $s0

            sw $t0, 0($t2)
            sw $t0, 0($t3)

            j END_DOODLE_DRAWING

        END_DOODLE_DRAWING:
            jr $ra

    # We take in 1 argument, if $a0 == 1 we update.
    # We also read a value off the stack -1 means go left, +1 means move right.
    #   The value doesn't matter if $a0 != 1, it's junk but we pop it anyways.
    FUNCTION_UPDATE_DOODLE:
        lw $t0, 0($sp)                  # Get the direction off the stack
        addi $sp, $sp, 4
        bne $a0, 1, END_UPDATE_DOODLE   # $a0 != 1 means we don't update

        # Update the doodle
        lw $t1, doodle_origin

        # set up for bounds check
        lw $t2, display_width
        lw $t4, block_size
        div $t2, $t4
        mflo $t2

        li $t4, 4
        div $t2, $t4
        mflo $t4                        # (doodle_origin) / 4 = K

        div $t4, $t3
        mfhi $t2                # K (mod) 64

        # First, figure out if we're going right or left.
        li $t5, -1
        beq $t0, $t5, MOVE_LEFT
        j MOVE_RIGHT

        MOVE_LEFT:
            # Now we have to check to make sure the doodle isn't on the left edge of the screen.
            # doodle_origin/4 % 64 == 0
            add $t3, $zero, $zero
            beq $t2, $t3, LEFT_EDGE # doodle's on the left edge
            j NORMAL_MOVEMENT

            # Move the doodle's origin to the right side of the screen.
            LEFT_EDGE:
                lw $t2, ROW_WIDTH
                add $t1, $t2, $t1

                # TODO: If we change the doodle_origin data structure, CHANGE the doodle boundary here.
                la $t2, doodle_origin
                sw $t1, 0($t2)
                j END_UPDATE_DOODLE

        MOVE_RIGHT:
            # We have to check to make sure the doodle isn't on the right most edge of the screen.
            # doodle_origin / 4 % 64 == 63
            subi $t3, $t2, 1            # last column
            beq $t2, $t3, RIGHT_EDGE
            j NORMAL_MOVEMENT

            # Move the doodle's origin to the left side of the screen.
            RIGHT_EDGE:
                lw $t2, ROW_WIDTH
                sub $t1, $t1, $t2

                # TODO: If we change the doodle_origin data structure, CHANGE the doodle boundary here.
                la $t2, doodle_origin
                sw $t1, 0($t2)
                j END_UPDATE_DOODLE

        NORMAL_MOVEMENT:
            # General case for movement
            li $t2, 4
            mult $t0, $t2
            mflo $t0                # Offset (+/-4)

            # TODO: If we change the doodle_origin data structure, CHANGE the doodle boundary here.
            la $t2, doodle_origin
            add $t1, $t1, $t0           # doodle_origin += offset
            sw $t1, 0($t2)
            j END_UPDATE_DOODLE

        END_UPDATE_DOODLE:
            jr $ra

    # In FUNCTION_DRAW_PLATFORM_LOOP, we get each platform
    # from platform_arr and draw it using the colour on the stack.
    FUNCTION_DRAW_PLATFORM_LOOP:
        lw $t7, 0($sp)              # get the colour off the stack
        addi $sp, $sp, 4            # reset the stack pointer

        # Throughout FUNCTION_DRAW_PLATFORM_LOOP, $s2 will be the offset for the arrays.
        li $s2, 0
        la $t8, row_arr             # our array of row indexes
        la $t9, platform_arr        # our array of platform origins

        GET_PLATFORM:
            lw $t1, num_platforms   # loop condition
            li $t2, 4
            mult $t1, $t2
            mflo $t1                # $t1 = num_platforms * 4

            # While i < num_platforms * 4, required because the next element is at arr[i + 4]
            beq $s2, $t1, COMPLETE_PLATFORM

            # Draw the current platform from our array.
            li $t2, 0   # current block being drawn.
            lw $t3, platform_width
            li $t4, 4
            mult $t3, $t4
            mflo $t3                # required for loop condition, 4*platform width

            # 1. get the row_index from row_arr[i]
            add $t4, $t8, $s2       # addr(row_arr[i])
            lw $t5, 0($t4)

            # 2. add the row index to the base of the display, positions us in the display.
            add $t5, $t5, $s0       # $t5 holds row_arr[i]'s actual position in the display

            # 3. get the column index from platform_arr[i]
            add $t4, $t9, $s2       # addr(platform_arr[i])
            lw $t6, 0($t4)          # $t6 = platform_arr[i]

            # 4. add the column index to the position in the display to get to the current block
            add $t6, $t6, $t5       # $t6 = platform_arr[i] + row in display, i.e the leftmost block of this platform. This is the curent block.

            DRAW_CURRENT_PLATFORM:
                # while i < platform_width, draw this platform
                beq $t2, $t3, NEXT_PLATFORM
                sw $t7, 0($t6)      # draw the block the chosen colour

                # increment the block and go to the loop condition
                addi $t2, $t2, 4
                addi $t6, $t6, 4    # Draw this block next.
                j DRAW_CURRENT_PLATFORM

            NEXT_PLATFORM:
                # increment our offset by 4
                addi $s2, $s2, 4
                j GET_PLATFORM

            COMPLETE_PLATFORM:
                jr $ra


    # Generate a random platform.
    # Arg: $a0 = width of this platform
    FUNCTION_GENERATE_RANDOM_PLATFORM:
        add $t0, $zero, $a0      # $t0 = width of this platform.
        lw $t1, display_width
        lw $t2, block_size

        div $t1, $t2
        mflo $t1
        subi $t1, $t1, 2        # we want to be 2 blocks from the wall TODO: may change if we change doodle_origin data structure.
        sub $t1, $t1, $t0

        # random(2, 61 - platform width)
        li $a0, 0
        add $a1, $zero, $t1
        li $v0, 42
        syscall

        addi $t0, $a0, 2    # Gives range [2, 63 - platform width]
        li $t1, 4
        mult $t0, $t1
        mflo $t0            # $t0 is the offset of the new platform column.
        add $v0, $zero, $t0
        jr $ra

    # the doodle has hit max height and so we have to move the platforms down.
    UPDATE_PLATFORMS:
        # Update the game score.
        la $t0, score
        lw $t1, 0($t0)
        addi $t1, $t1, 1
        sw $t1, 0($t0)

        li $s3, 0           # $s3 will be our loop counter, we loop 10x

        # We also check if the doodle has moved while moving the map.
        MOVE_PLATFORMS:
            # sleep
            li $v0 32
            lw $a0, platform_sleep
            syscall

            lw $t0, platform_distance
            beq $s3, $t0, COMPLETE_PLATFORM_UPDATE

            addi $s3, $s3, 1    # increment $s3 here since we're already passed the branch operation

            # 1. Erase the current platforms.
            # put the platform colour on the stack before drawing.
            lw $t0, background
            addi $sp, $sp, -4
            sw $t0, 0($sp)

            jal FUNCTION_DRAW_PLATFORM_LOOP

            # We might be moving the doodle, and since we're redrawing the
            # platforms, if the doodle passes through a platform it's body might
            # get overwritten. May as well erase and redraw it.
            lw $t0, background
            addi $sp, $sp, -4
            sw $t0, ($sp)
            jal FUNCTION_DRAW_DOODLE

            # Check for keyboard input
            jal FUNCTION_READ_KEYBOARD_INPUT
            add $a0, $zero, $v0
            add $t1, $zero, $v1
            addi $sp, $sp, -4
            sw $t1, 0($sp)                  # store $v1 on the stack (we only update if $a0 == 1)
            jal FUNCTION_UPDATE_DOODLE      # the doodle will update if there's an update to perform

            # Redraw the doodle.
            lw $t1, doodle_colour
            addi $sp, $sp, -4
            sw $t1, ($sp)
            jal FUNCTION_DRAW_DOODLE

            # 2. Calculate the new positions
            li $t0, 0
            la $t8, row_arr
            la $t9, platform_arr

            # The algorithm works as follows.
            # First, we increase each platform's row by 1.
            # for i in range(len(arr)):
            #   arr[i] = arr[i] + 1
            # if our bottom row is off the screen
            # for i in range(len(arr) - 1)
            #   arr[i] = arr[i + 1]
            # Generate a new top platform.
            CALCULATE_NEW_PLATFORM_ROWS:
                lw $t1, num_platforms
                # while i < # platforms
                beq $t0, $t1, CHECK_PLATFORM_OVERFLOW

                li $t2, 4
                mult $t0, $t2
                mflo $t2            # current offset (0, 4, 8, etc)

                add $t3, $t8, $t2   # $t3 = addr(row_arr[i])

                lw $t4, 0($t3)      # $t4 = row_arr[i]
                lw $t2, ROW_BELOW
                add $t4, $t4, $t2   # $t4 += 1 row

                sw $t4, 0($t3)      # row_arr[i] += 1 row

                # increment and jump to loop condition
                addi $t0, $t0, 1
                j CALCULATE_NEW_PLATFORM_ROWS

            # Check if the bottom platform has fallen off the map.
            # If it has, move all the old platforms in the arrays and
            # generate a new platform.
            CHECK_PLATFORM_OVERFLOW:
                # Check if we've gone past the last block on the display.
                lw $t0, 0($t8)          # 0($t8) = row_arr[0]
                lw $t1, display_width
                lw $t2, block_size

                div $t1, $t2
                mflo $t1

                lw $t2, ROW_BELOW
                mult $t1, $t2
                mflo $t2                # $t2 = offset of first block past last block on display.

                # if row_arr[0] != $t2, draw the new platforms
                bne $t0, $t2, DRAW_NEW_PLATFORMS

                # We went past the last block so rearrange the array.
                li $t1, 0
                lw $t2, num_platforms
                addi $t2, $t2, -1       # We will modify all but the final platform

                # In this loop, we perform row_arr[i] = row_arr[i + 1]
                # for every platform excluding the last.
                # This is how we shift the middle to the bottom, the top to the middle, etc.
                SWAP_PLATFORMS_LOOP:
                    beq $t1, $t2, GENERATE_TOP_PLATFORM
                    li $t3, 4
                    mult $t1, $t3
                    mflo $t3

                    # update row_arr
                    add $t4, $t3, $t8   # offset into row_arr
                    addi $t5, $t4, 4    # offset + 4 is the next platform

                    lw $t0, 0($t5)      # $t0 = row_arr[i + 1]
                    sw $t0, 0($t4)      # row_arr[i] = $t0

                    # update platform_arr
                    add $t4, $t3, $t9   # offset into platform_arr
                    addi $t5, $t4, 4    # offset + 4 is the next platform

                    lw $t0, 0($t5)      # $t0 = platform_arr[i + 1]
                    sw $t0, 0($t4)      # platform_arr[i] = $t0

                    addi $t1, $t1, 1    # increment counter.
                    j SWAP_PLATFORMS_LOOP

                # Using the 2nd from the top platform's row and platform_distance,
                # generate a new top platform.
                GENERATE_TOP_PLATFORM:
                    # 1. Get the second last platform's row
                    lw $t0, num_platforms
                    addi $t0, $t0, -2
                    li $t1, 4
                    mult $t0, $t1
                    mflo $t1            # index of 2nd last platform

                    add $t1, $t1, $t8  # $t1 = addr(row_arr[2nd last])
                    lw $t0, 0($t1)      # $t0 = row_arr[2nd_last]

                    # Since the row_arr array contains offsets in the 0th column, we can divide by the
                    # ROW_BELOW constant to get the row value.
                    lw $t1, ROW_BELOW
                    div $t0, $t1
                    mflo $t0            # $t0 = row [0, 63] if 512x512 display with size 8 blocks.

                    # 2. Determine where the top platform should go.
                    lw $t2, platform_distance
                    sub $t0, $t0, $t2  # $t2 = row of 2nd last platform - distance between platforms

                    # $t0 holds our current platform row
                    mult $t1, $t0
                    mflo $t2

                    lw $t0, num_platforms
                    addi $t0, $t0, -1
                    li $t1, 4
                    mult $t0, $t1
                    mflo $t1            # index of last platform

                    add $t1, $t1, $t8   # $t1 = addr(row_arr[last])
                    sw $t2, 0($t1)      # row_arr[last] = new row

                    # store $t1 on the stack because we seem to overwrite it in FUNCTION_GENERATE_RANDOM_PLATFORM
                    addi $sp, $sp, -4
                    sw $t1, 0($sp)
                    lw $a0, platform_width

                    jal FUNCTION_GENERATE_RANDOM_PLATFORM
                    add $t0, $zero, $v0

                    # Pop the old $t1 value off the stack
                    lw $t1, 0($sp)
                    addi $sp, $sp, 4

                    # Get the array offset-index back
                    sub $t1, $t1, $t8

                    # Get offset into platform_arr
                    add $t1, $t1, $t9
                    sw $t0, 0($t1)
                    j DRAW_NEW_PLATFORMS

            DRAW_NEW_PLATFORMS:
                # put the platform colour on the stack before drawing.
                lw $t0, platform_colour
                addi $sp, $sp, -4
                sw $t0, 0($sp)
                jal FUNCTION_DRAW_PLATFORM_LOOP

                # Now that we finished drawing the new platforms, go back to the main loop
                # to see if any work is left.
                j MOVE_PLATFORMS

        COMPLETE_PLATFORM_UPDATE:
            # after everything has finished
            j GAME_LOOP

    # TODO: instead of hardcoding where the doodle starts and ends, lets store the doodle's
    #       boundary in an array in memory. The first element is the left most valid block,
    #       the second element is the right most valid block. This way we can update the doodle's
    #       size and shape without worrying that the collision detection may break.
    #
    # Collision detection algorithm.
    # Called only when falling.
    # We rely on the `candidate_platform` variable here.
    #
    # Returns:
    #    0 if no collision
    #    1 if collision detected
    #   -1 if we fell past the candidate platform
    FUNCTION_COLLISION_DETECTION:
        # First, we want to determine if we're 1 row above the platform
        la $t8, row_arr
        lw $t0, candidate_platform
        li $t1, 4
        mult $t0, $t1
        mflo $t0
        add $t4, $t0, $t8   # $t4 = addr(row_arr[candidate_platform])
        lw $t0, 0($t4)      # $t0 = row_arr[candidate_platform]

        lw $t2, ROW_BELOW
        sub $t2, $t0, $t2   # $t2 = leftmost block of 1 row above the platform

        addi $t3, $t0, -4   # $t3 = rightmost block of 1 row above the platform

        # if $t2 <= doodle <= $t3, the doodle is 1 row above the platform.
        lw $t4, doodle_origin   # position of the leftmost block of the doodle.
        sub $t2, $t4, $t2       # if $t2 > 0, then $t2 <= doodle
        sub $t3, $t3, $t4       # if $t3 > 0, then doodle <= $t3

        # Add 1 to both because they could be 0
        addi $t2, $t2, 1
        addi $t3, $t3, 1

        # Check that $t2 <= doodle
        CHECK_LEFT:
            bgtz $t2, CHECK_RIGHT
            j NO_COLLISION

        # Check that doodle <= $t3
        CHECK_RIGHT:
            bgtz $t3, VERIFY_COLLISION
            j NO_COLLISION

        # At this point, we know the doodle is 1 row above the platform.
        # We want to check if it's actually touching.
        VERIFY_COLLISION:
            # if the right leg of the doodle is above the left edge of the platform
            # and if the left leg of the doodle is above the right edge of the platform
            # we have a collision.

            # In math: if (x[candidate_platform] <= doodle + 8*4) AND (doodle <= x[candidate_platform] + 8*4) => COLLISION!

            # 1. Get the platform's horizontal data.
            la $t8, row_arr
            la $t9, platform_arr
            lw $t0, candidate_platform
            li $t1, 4
            mult $t0, $t1
            mflo $t0
            add $t4, $t0, $t9       # $t4 = addr(platform_arr[candidate_platform])
            add $t5, $t0, $t8       # $t5 = addr(row_arr[candidate_platform])
            lw $t0, 0($t4)          # $t0 = platform_arr[candidate_platform]
            lw $t1, 0($t5)          # $t1 = row_arr[candidate_platform]

            add $t0, $t0, $t1       # $t0 is now the leftmost block of the platform

            lw $t4, doodle_origin

            lw $t5, ROW_BELOW
            add $t4, $t4, $t5       # This way we compare the doodle's horiztonal position against the platform on the same row.
            # addi $t4, $t4, 512      # This way we compare the doodle's horiztonal position against the platform on the same row.
            addi $t1, $t4, 8        # $t1 = doodle's right leg offset

            lw $t2, platform_width
            li $t5, 4
            mult $t2, $t5
            mflo $t2
            sub $t2, $t2, $t5

            add $t2, $t0, $t2       # $t2 = right edge of platform

            # if $t0 <= $t1 (doodle's right leg) and
            # if $t4 (doodle's left leg) <= $t2 (right edge)
            # we have a collision
            sub $t1, $t1, $t0       # if $t1 >= 0 we collided
            sub $t2, $t2, $t4       # if $t2 >= 0 we collided

            # Add 1 to both because they could be 0
            addi $t1, $t1, 1
            addi $t2, $t2, 1

            VERIFY_COLLISION_BOUNDS:
                bgtz $t1, CHECK_LEFT_LEG
                j FELL_PAST_PLATFORM

            CHECK_LEFT_LEG:
                bgtz $t2, COLLISION
                j FELL_PAST_PLATFORM

        COLLISION:
            li $v0, 1
            jr $ra

        NO_COLLISION:
            li $v0, 0
            jr $ra

        FELL_PAST_PLATFORM:
            li $v0, -1
            jr $ra

    FALL:
        jal FUNCTION_COLLISION_DETECTION
        add $s4, $zero, $v0        # 1 if collision occured, 0 if no platform nearby, -1 if fell past platform.
        li $t1, 1

        beq $s4, $t1, JUMP

        # We're falling at this point, deal with it.
        # First, lets check if we fell past the platform, since it could mean game over.
        li $t1, -1
        beq $s4, $t1, DECREMENT_CANDIDATE_PLATFORM
        j HANDLE_FALL

        DECREMENT_CANDIDATE_PLATFORM:
            # if this is the bottom platform, get ready to end the game.
            lw $t0, candidate_platform
            li $t1, 0           # unnecessary, but just to be safe.
            beq $t0, $t1, PREPARE_END_GAME

            # Otherwise, just decrement the candidate_platform
            addi $t0, $t0, -1
            la $t1, candidate_platform
            sw $t0, 0($t1)
            j HANDLE_FALL

        PREPARE_END_GAME:
            li $s5, 5           # $s5 == -1 then we will end the game after the next drawing.
            j HANDLE_FALL


        HANDLE_FALL:
            # add a small sleep.
            li $v0, 32
            lw $a0, jump_sleep_time
            syscall

            # First, we erase our doodle, then redraw.
            lw $t0, background
            addi $sp, $sp, -4
            sw $t0, ($sp)
            jal FUNCTION_DRAW_DOODLE

            # Check if the player wants to move the doodle.
            jal FUNCTION_READ_KEYBOARD_INPUT
            add $a0, $zero, $v0
            add $t1, $zero, $v1
            addi $sp, $sp, -4
            sw $t1, 0($sp)                  # store $v1 on the stack (we only update if $a0 == 1)
            jal FUNCTION_UPDATE_DOODLE      # the doodle will update if there's an update to perform

            # We need to send our friend the doodle down 1 row.
            la $t2, doodle_origin
            lw $t1, 0($t2)
            lw $t3, ROW_BELOW
            add $t1, $t1, $t3       # doodle position - 1 row
            sw $t1, 0($t2)          # update doodle_origin

            # Draw the doodle in the new position.
            lw $t0, doodle_colour
            addi $sp, $sp, -4
            sw $t0, ($sp)
            jal FUNCTION_DRAW_DOODLE

            li $t0, 5
            beq $s5, $t0, GAME_END  # If we fell past the last platform, end the game.

            # Redraw platform
            # TODO: When we move the map (doodle hit max height), the doodle may be "inside"
            #       the top platform. Therefore, when it falls, as we erase it, we erase
            #       the platform as well, so we're taking this into account by redrawing it here.
            # There has to be a more efficient way to do this, I don't want to draw in a bunch of edge
            # cases, it's adding complexity.
            lw $t0, platform_colour
            addi $sp, $sp, -4
            sw $t0, ($sp)
            jal FUNCTION_DRAW_PLATFORM_LOOP

            j FALL

    JUMP:
        li $s1, 0                   # $s1 will be our counter that lets us know how many more times we have to move the doodle up
        la $t8, row_arr

        BOUNCE_LOOP:
            # add a small sleep.
            li $v0, 32
            lw $a0, jump_sleep_time
            syscall

            lw $t0, bounce_height   # highest we can jump
            beq $s1, $t0, FALL

            addi $s1, $s1, 1        # increment our counter

            # Make it so that the highest the doodle goes is 1 above the middle platform.
            lw $t0, num_platforms
            li $t1, 2
            div $t0, $t1
            mflo $t0
            mfhi $t1
            add $t0, $t0, $t1

            li $t1, 4
            mult $t0, $t1
            mflo $t0

            add $t1, $t0, $t8
            lw $t0, 0($t1)

            lw $t1, ROW_WIDTH
            add $t0, $t0, $t1       # get last block of the top platforms row.

            # if doodle <= $t0, we have to redraw the map.
            lw $t1, doodle_origin

            sub $t0, $t0, $t1
            addi $t0, $t0, 1

            # If $t0 is positive, we have to redraw
            bgtz $t0, UPDATE_PLATFORMS

            # Bounce!
            # First, we need to erase our doodle.
            lw $t0, background
            addi $sp, $sp, -4
            sw $t0, ($sp)
            jal FUNCTION_DRAW_DOODLE

            # Check if the player wants to move the doodle
            jal FUNCTION_READ_KEYBOARD_INPUT
            add $a0, $zero, $v0
            add $t1, $zero, $v1
            addi $sp, $sp, -4
            sw $t1, 0($sp)                  # store $v1 on the stack (we only update if $a0 == 1)
            jal FUNCTION_UPDATE_DOODLE      # the doodle will update if there's an update to perform

            # We need to send our friend the doodle up 1 row.
            la $t2, doodle_origin
            lw $t1, 0($t2)
            lw $t0, ROW_BELOW
            sub $t1, $t1, $t0       # doodle position + 1 row

            sw $t1, 0($t2)          # update doodle_origin

            # Next, we need to look into updating the candidate_platform variable.
            lw $t0, candidate_platform
            # If we're 1 row above row_arr[candidate_platform + 1], we need to update candidate_platform
            li $t2, 4
            mult $t0, $t2
            mflo $t0
            addi $t0, $t0, 4
            add $t0, $t0, $t8
            lw $t3, 0($t0)          # $t3 = row_arr[candidate_platform + 1]

            addi $t3, $t3, -4       # end of row directly above the platform above our current candidate_platform

            sub $t0, $t3, $t1
            addi $t0, $t0, 1

            # place the doodle colour on the stack before calling FUNCTION_DRAW_DOODLE
            lw $t1, doodle_colour
            addi $sp, $sp, -4
            sw $t1, ($sp)

            # If $t0 is positive, then the doodle is 1 row above the top platform, so we need to update the candidate_platform variable.
            bgtz, $t0, INCREMENT_CANDIDATE_PLATFORM

            jal FUNCTION_DRAW_DOODLE
            j BOUNCE_LOOP

            INCREMENT_CANDIDATE_PLATFORM:
                la $t0, candidate_platform
                lw $t1, 0($t0)
                addi $t1, $t1, 1
                sw $t1, 0($t0)
                jal FUNCTION_DRAW_DOODLE

                # Since we may have passed through the platform, redraw the platforms.
                lw $t1, platform_colour
                addi $sp, $sp, -4
                sw $t1, ($sp)

                jal FUNCTION_DRAW_PLATFORM_LOOP
                j BOUNCE_LOOP

GAME_END:
    # Show the doodle at the bottom of the display.
    li $v0, 32
    lw $a0, jump_sleep_time
    syscall
    # Erase the doodle cuz it fell off the map
    lw $t0, background
    addi $sp, $sp, -4
    sw $t0, ($sp)
    jal FUNCTION_DRAW_DOODLE

    li $a0, 0x000000            # make the screen black
    jal FUNCTION_DRAW_BACKGROUND

    # Print the score
    li $v0 1
    lw $a0, score
    syscall

    li $v0, 10 		# terminate the program gracefully
    syscall

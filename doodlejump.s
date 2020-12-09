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
#   - Milestone 5
#
# Which approved additional features have been implemented?
#   Milestone 4 Features
#       1. Display score during game and at game over.
#       2. Game over, restart screen.
#   Milestone 5 Features
#       1. Better physics (added gravity)
#       2. More platforms (added 3 types)
#           a. Blue platforms that move left and right
#           b. White platforms that disappear (aka 'break').
#           c. Orange platforms that shift when landed on. (additional)
#       3. Doodle shoots
# Any additional information that the TA needs to know:
#   - (write here, if any)
#
#####################################################################
.data
    # ---Timers---
    jump_sleep_time:    .word 40               # ms to sleep between drawing
    platform_sleep:     .word 20

    # ---Colours---
    background:                     .word 0xDAEAFC      # Background colour of the display
    doodle_colour:                  .word 0xF9C09F

    # array of platform colours
    # first (green) normal
    # second (white-ish) disappearing
    # third (blue-ish) moving
    # fourth (yellow-ish) shifting
    platform_colour:    .word 0x00ff00, 0xF2F2F2, 0x80BFFF, 0xFFD966

    # For disappearing platforms, we require 5 steps to disappear.
    # The first element is the background colour, the last is closest to the
    # ordinary disappearing platform colour.
    gradient:           .word 0xDAEAFC, 0xE0ECFA, 0xE6EEF7, 0xECF0F4, 0xF0F1F3

    # normal_platform_colour:         .word 0x00ff00      # green
    # disappearing_platform_colour:   .word 0xF2F2F2      # white-ish
    # moving_platform_colour:         .word 0x80BFFF      # blue-ish
    # shifting_platform_colour:       .word 0xFFD966      # yellow-ish
    score_colour:                   .word 0x000000

    # ---IO Addresses---
    displayAddress:     .word 0x10008000
    keyPress:           .word 0xffff0000
    keyValue:           .word 0xffff0004

    # ---Program constants---
    block_size:         .word 8
    display_width:      .word 512

    platform_width:     .word 12
    num_platforms:      .word 4
    platform_distance:  .word 18                # vertical distance between platforms

    ROW_WIDTH:          .word 252               # This is for a 512 x 512 display.
    ROW_BELOW:          .word 256               # same column, one row below

    # ---Array of 4 platforms---
    #   - The following arrays store the bottom platform in the first index
    #   - *platform_arr* stores the leftmost column index (col * 4, col in [0, (display_width/block_size -1)-platform_width])
    #   - *row_arr* stores the row index (row*ROW_BELOW, row in [0, (display_width/block_size -1)])
    #   - *platform_type* stores pointers to structs of the following type:
    #
    #   struct platform {
    #       int type;       //  0 = normal, 1 = disappearing, 2 = moving, 3 = shifting
    #       int contact;    //  0 = no contact made, 1 = contact made. Used by type 1 and 3 platforms.
    #       int direction;  // -1 = left, 1 = right. Used by type 2 platforms.
    #   }
    #  These structs are stored on the heap and occupy 3 words, i.e 12 bytes.

    platform_arr:       .word 0:4
    row_arr:            .word 16128, 11520, 6912, 2304    # Store the row_indexes of each platform. Add these to displayAddress.
    platform_type:      .word 0:4

    # ---Doodle Character---
    #   - We will only store the bottom left of the doodle, the rest can easily be calculated on the fly.
    #   - We will store it's offset as a value in [0, 4092], so we have to add it to the base of the display
    #     when drawing.
    doodle_origin:      .word 0                 # Storing [0, 4092] makes bounds/collision detection easier.
    bounce_height:      .word 24                # Doodle can jump up 14 rows.
    candidate_platform: .word 0                 # Index [0 (bottom), 1, 2(top)] of the closest platform that we can fall on to. If -1, game is over (fell under map)

    # ---Score Keeping and State---
    #
    # score_digits is an array of pointers to:
    #   struct digit {
    #       int *address;   // pointer to some address on the display. Represents top left corner of a 7-seg display type shape.
    #       int value;      // an integer from 0 to 9.
    #   }
    # structs, which are allocated on the heap.
    # We could store (digit.value) as a byte (probably?, since 2^8 == 256) but we only allocate 5 of these so it's not worth
    # the mental gymnastics of having a 5 byte struct.
    score:              .word 0                 # Game score.
    max_score_length:   .word 5                 # the number of digits in the score
    score_digits:       .word 0:5               # array containing pointers to structs on the heap that represent our score.
                                                #   The digits are in reverse order. Assuming max score of 9999
    score_length:       .word 1                 # The number of digits in the score.

    allocations:        .word 0                 # We set this to 1 once we've allocated the blocks the first time.

.text
    MAIN:
        # setup
        lw $s0, displayAddress 	# $s0 stores the base address for display, we never change it.

        # flags that indicate whether we've finished setting up or not.
        li $s5, 0   # 0 => have yet to draw platforms, 1 => starting platforms have been drawn.
        li $s7, 0   # 0 => have yet to draw doodle,    1 => starting doodle has been drawn.

        jal FUNCTION_ALLOCATE_SCORE_ARRAY
        jal FUNCTION_ALLOCATE_PLATFORM_TYPES

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

    # No one is ever going to play this game to a score of 10,000+ so I'm not gonna bother
    # dynamically allocating/deallocating an array of pointers to structs on the heap.
    # Lets just allocate 5 pointers to structs on the heap here and be done with it.
    FUNCTION_ALLOCATE_SCORE_ARRAY:
        lw $t0, max_score_length
        li $t1, 0               # counter
        la $t5, score_digits

        # I want to use $s1 to increment the base address for each digit
        # so we have to store it on the stack.
        addi $sp, $sp, -4
        sw $s1, 0($sp)
        # $s1 = base address of this 7-seg display digit.
        li $s1, 1512            # HARDCODED VALUE! 5th row, 58th col. 1512 = 58*4 + 5 * 256
        add $s1, $s1, $s0       # $s0 is the base display

        DIGIT_ALLOCATION_LOOP:
            beq $t0, $t1, FINISH_DIGIT_ALLOCATION

            # Just a quick note: we allocate 8 bytes because our "struct"
            # is 2 words, the first is an address, the second is an integer.
            li $a0, 8           # num bytes to allocate
            li $v0, 9           # call sbrk() syscall
            syscall

            move $t2, $v0       # Save the address in $t2

            li $t3, 4
            mult $t1, $t3
            mflo $t3

            add $t3, $t3, $t5   # offset into array
            sw $t2, 0($t3)      # store the memory address in the array
            sw $s1, 0($t2)      # store the base address for the digit in the struct.

            # Increment the counter
            addi $t1, $t1, 1

            # Decrement the base address 4 columns
            addi $s1, $s1, -16

            j DIGIT_ALLOCATION_LOOP

        FINISH_DIGIT_ALLOCATION:
            # restore $s1
            lw $s1, 0($sp)
            addi $sp, $sp, 4
            jr $ra

    # We want to allocate num_platforms structs as defined in the .data section.
    # Note that if we're playing for the nth time, we're not doing any allocations,
    # we just reuse the blocks made when the program started.
    FUNCTION_ALLOCATE_PLATFORM_TYPES:
        lw $t0, num_platforms
        li $t1, 0               # counter
        la $t5, platform_type

        PLATFORM_ALLOCATION_LOOP:
            beq $t0, $t1, FINISH_PLATFORM_ALLOCATION

            # access the index in platform_type
            li $t3, 4
            mult $t1, $t3
            mflo $t3

            add $t3, $t3, $t5   # offset into array

            # We only allocate if this is our first time playing.
            lw $t2, allocations
            beq $t2, 1, SKIP_ALLOCATION
            # Just a quick note: we allocate 12 bytes because our "struct"
            # is 3 words:
            #   int type
            #   int contact
            #   int direction
            li $a0, 12          # num bytes to allocate
            li $v0, 9           # call sbrk() syscall
            syscall

            move $t2, $v0       # Save the address in $t2
            sw $t2, 0($t3)      # store the memory address in the array
            j SET_DEFAULT_PLATFORM

            SKIP_ALLOCATION:
                lw $t2, 0($t3)      # read the memory address from the array

            SET_DEFAULT_PLATFORM:
                # int type = 0
                li $t4, 0
                sw $t4, 0($t2)

                # int contact = 0
                sw $t4, 4($t2)

                # int direction = 1
                li $t4, 1
                sw $t4, 8($t2)

                # Increment the counter
                addi $t1, $t1, 1

                j PLATFORM_ALLOCATION_LOOP

        FINISH_PLATFORM_ALLOCATION:
            # Now that the allocations have been made, we will no longer perform them until the next time the program is reloaded
            la $t2, allocations
            li $t4, 1
            sw $t4, 0($t2)

            jr $ra

    # We want to de-allocate num_platforms structs as defined in the .data section.
    FUNCTION_DEALLOCATE_PLATFORM_TYPES:
        li $t0, -1
        lw $t1, num_platforms   # counter
        addi $t1, $t1, -1
        la $t5, platform_type

        # We deallocate in reverse
        PLATFORM_DEALLOCATION_LOOP:
            beq $t0, $t1, FINISH_PLATFORM_DEALLOCATION

            # Just a quick note: we deallocate 12 bytes because our "struct"
            # is 3 words:
            #   int type
            #   int contact
            #   int direction

            # access the index in platform_type
            li $t3, 4
            mult $t1, $t3
            mflo $t3

            add $t3, $t3, $t5   # offset into array
            lw $t2, 0($t3)      # store the memory address in the array

            # 0 everything out
            # int type = 0
            li $t4, 0
            sw $t4, 0($t2)

            # int contact = 0
            sw $t4, 4($t2)

            # int direction = 0
            sw $t4, 8($t2)

            # decrement the counter
            addi $t1, $t1, -1

            # NOTE: Typically, we would deallocate the space, however it seems like there isn't
            #       any way to do this in MARS, so I'm just leaving this as a comment.
            # Instead of reallocating space each time we play again, we'll just reuse
            # the same memory.
            # li $a0, -12         # num bytes to allocate
            # li $v0, 9           # call sbrk() syscall
            # syscall

            j PLATFORM_DEALLOCATION_LOOP

        FINISH_PLATFORM_DEALLOCATION:
            jr $ra


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
            li $t2, 1
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

    # TODO: Rather than passing the colour to draw, lets pass
    #           -1 = erase
    #            1 = draw
    #       This way we can draw different colours to represent different platform
    #       types. Also, recognize that we only want to figure out how to draw the
    #       platforms here. We aren't doing any updates, just drawing based on the
    #       current game state.

    # In FUNCTION_DRAW_PLATFORM_LOOP, we get each platform
    # from platform_arr and draw it using the colour on the stack.
    FUNCTION_DRAW_PLATFORM_LOOP:
        lw $t7, 0($sp)              # get the colour off the stack
        addi $sp, $sp, 4            # reset the stack pointer

        # Throughout FUNCTION_DRAW_PLATFORM_LOOP, $s2 will be the offset for the arrays.
        addi $sp, $sp, -4
        sw $s2, 0($sp)

        li $s2, 0
        la $t8, row_arr             # our array of row indexes
        la $t9, platform_arr        # our array of platform origins

        GET_PLATFORM:
            lw $t1, num_platforms   # loop condition
            beq $s2, $t1, COMPLETE_PLATFORM

            li $t2, 4
            mult $t2, $s2
            mflo $t2                # offset into our arrays

            # 1. get the row_index from row_arr[i]
            add $t4, $t8, $t2       # addr(row_arr[i])
            lw $t5, 0($t4)

            # 2. add the row index to the base of the display, positions us in the display.
            add $t5, $t5, $s0       # $t5 holds row_arr[i]'s actual position in the display

            # 3. get the column index from platform_arr[i]
            add $t4, $t9, $t2       # addr(platform_arr[i])
            lw $t6, 0($t4)          # $t6 = platform_arr[i]

            # 4. add the column index to the position in the display to get to the current block
            add $t6, $t6, $t5       # $t6 = platform_arr[i] + row in display, i.e the leftmost block of this platform. This is the curent block.

            # If we're erasing, set the colour to the background
            beq $t7, -1 ERASE_PLATFORM

            # TODO: IF WE HAVE A DISAPPEARING PLATFROM AND THE .CONTACT VALUE IS NOT 0 THEN DO NOT DRAW IT!
            # We're not erasing so we should get the default
            # colour of this type of platform
            la $t5, platform_type
            add $t1, $t2, $t5       # offset in platform_type
            lw $t1, 0($t1)          # address of struct on heap
            lw $t4, 0($t1)          # type of platform

            # if $t1 == 1 (disappearing), check the .contact value
            beq $t4, 1, CHECK_DISAPPEARING_CONTACT
            j ACCESS_PLATFORM_COLOURS

            CHECK_DISAPPEARING_CONTACT:
                lw $t2, 4($t1)      # $t4 == .contact
                # if non-zero, subtract by 1 and set colour = gradient[.contact - 1]
                beq $t2, 0, ACCESS_PLATFORM_COLOURS
                addi $t2, $t2, -1   # index, we read gradient array in reverse

                li $t1, 4
                mult $t2, $t1
                mflo $t2

                la $t1, gradient    # gradient array
                add $t2, $t1, $t2   # offset in gradient array

                lw $t1, 0($t2)      # colour to paint this block
                li $t2, 0           # loop coutner for DRAW_CURRENT_PLATFORM
                j DRAW_CURRENT_PLATFORM

            ACCESS_PLATFORM_COLOURS:
                li $t1, 4
                mult $t1, $t4
                mflo $t1                # offset in platform_colour array
                la $t4, platform_colour
                add $t4, $t4, $t1
                lw $t1, 0($t4)          # colour to paint this block

                li $t2, 0               # loop counter for DRAW_CURRENT_PLATFORM
                j DRAW_CURRENT_PLATFORM

            ERASE_PLATFORM:
                lw $t1, background
                li $t2, 0               # loop counter for DRAW_CURRENT_PLATFORM
                j DRAW_CURRENT_PLATFORM

            DRAW_CURRENT_PLATFORM:
                lw $t3, platform_width
                # while i < platform_width, draw this platform
                beq $t2, $t3, NEXT_PLATFORM
                sw $t1, 0($t6)      # draw the block the chosen colour

                # increment the block and go to the loop condition
                addi $t2, $t2, 1
                addi $t6, $t6, 4    # Draw this block next.
                j DRAW_CURRENT_PLATFORM

            NEXT_PLATFORM:
                # increment our
                addi $s2, $s2, 1
                j GET_PLATFORM

            COMPLETE_PLATFORM:
                lw $s2, 0($sp)
                addi $sp, $sp, 4
                jr $ra


    # NOTE: we call this function after FUNCTION_GENERATE_RANDOM_PLATFORM
    #       Update the last element in the platform_type array.
    FUNCTION_GENERATE_PLATFORM_TYPE:
        # set 'type' (1st property) to random number then shrink it down to [0, 3]
        #   - we use simple weighted probability to control the likelihood of getting certain platforms.
        #           50% chance of getting a normal platform         ( green )
        #           15% chance of getting a disappearing platform   ( white )
        #           15% chance of getting a moving platform         (  blue )
        #           20% chance of getting a shifting platform       ( yellow)
        # by default we make contact = 0, direction = 1

        lw $t0, num_platforms
        addi $t0, $t0, -1
        li $t1, 4
        mult $t0, $t1
        mflo $t0            # offset in platform_type array

        la $t2, platform_type
        add $t2, $t2, $t0   # address of last element in the array

        lw $t2, 0($t2)      # address of the struct

        # contact = 0
        li $t1, 0
        sw $t1, 4($t2)

        # direction = 1
        li $t1, 1
        sw $t1, 8($t2)

        # Now to determine the type of platform
        # random(0, 100)
        li $t1, 100
        li $a0, 0
        move $a1, $t1
        li $v0, 42
        syscall

        move $t1, $a0       # x = random_range(0, 100)
        li $t0, 80

        # At this point, if $t1 - 80 is greater than 0 it's a type 3
        sub $t0, $t1, $t0
        bltz, $t0, CHECK_TYPE_2

        # type = 3
        li $t1, 3
        sw $t1, 0($t2)
        j FINISH_GENERATING_PLATFORM_TYPE

        CHECK_TYPE_2:
            li $t0, 65

            # At this point, if $t1 - 65 is greater than 0 it's a type 2
            sub $t0, $t1, $t0
            bltz, $t0, CHECK_TYPE_1
            # type = 2
            li $t1, 2
            sw $t1, 0($t2)
            j FINISH_GENERATING_PLATFORM_TYPE

        CHECK_TYPE_1:
            li $t0, 50

            # At this point, if $t1 - 50 is greater than 0 it's a type 1
            sub $t0, $t1, $t0
            bltz, $t0, CHECK_TYPE_0
            # type = 1
            li $t1, 1
            sw $t1, 0($t2)
            j FINISH_GENERATING_PLATFORM_TYPE

        CHECK_TYPE_0:
            # At this point, 0 <= x <= 70, so it's a type 0
            # type = 0
            li $t1, 0
            sw $t1, 0($t2)
            j FINISH_GENERATING_PLATFORM_TYPE

        FINISH_GENERATING_PLATFORM_TYPE:
            jr $ra

    # Generate a random platform.
    # Arg: $a0 = width of this platform
    FUNCTION_GENERATE_RANDOM_PLATFORM:
        add $t0, $zero, $a0     # $t0 = width of this platform.
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

    #   Our main tool for drawing on the screen
    #   Arguments:
    #       - $a0 = colour
    #       - $a1 = starting address
    #       - $a2 = direction
    #             0: right
    #             1: up
    #             2: left
    #             3: down
    #       - $a3 = number of blocks to draw (including base)
    #
    FUNCTION_DRAW_TOOL:
        move $t0, $a0   # colour
        move $t1, $a1   # Base address
        move $t2, $a2   # direction
        move $t3, $a3   # number of blocks to draw
        li $t5, 0       # loop counter

        # We will be using $s1 to store the delta value as we draw.
        # Save it on the stack first.
        addi $sp, $sp, -4
        sw $s1, 0($sp)
        # First, if we got 0 or 2, go to draw horizontal.
        # We check this first because the incrementor for
        # L/R is identical up to the sign, and the same goes
        # for moving U/D
        li $t4, 2
        div $t2, $t4
        mfhi $t4

        beq $t4, $zero, DRAW_HORIZONTAL

        # Otherwise we're drawing vertically.
        j DRAW_VERTICAL

        DRAW_HORIZONTAL:
            # Set our incrementor/decrementor
            # Since we want to shift by columns, our delta is 4*i, where i is the index.
            li $s1, 4

            # If we're drawing left, flip the sign.
            li $t4, 2
            beq $t2, $t4, DRAW_LEFT

            j DRAW_TOOL_LOOP

            DRAW_LEFT:
                # offset value decreases as we go left, make the delta negative
                li $t4, -1
                mult $s1, $t4
                mflo $s1
                j DRAW_TOOL_LOOP

        DRAW_VERTICAL:
            # Set our incrementor/decrementor
            # Since we want to shift by rows, our delta is ROW_BELOW*i, where i is the index.
            lw $s1, ROW_BELOW

            # If we're drawing up, flip the sign.
            li $t4, 1
            beq $t2, $t4, DRAW_UP

            j DRAW_TOOL_LOOP

            DRAW_UP:
                # offset value decreases as we go up, make the delta negative
                li $t4, -1
                mult $s1, $t4
                mflo $s1
                j DRAW_TOOL_LOOP

        # Now that our delta is set up, we want to draw the requested line.
        DRAW_TOOL_LOOP:
            # If we've drawn the requested number of blocks, finish up.
            beq $t5, $t3, FINISH_DRAWING

            # We want to draw the block.
            mult $t5, $s1       # $t5 is the counter, $s1 is the delta
            mflo $t6
            add $t6, $t6, $t1   # $t6 = offset in the display

            sw $t0, 0($t6)      # draw the block the requested colour

            # Increment the counter
            addi $t5, $t5, 1

            j DRAW_TOOL_LOOP

        FINISH_DRAWING:
            # Restore $s1
            lw $s1, 0($sp)
            addi $sp, $sp, 4

            jr $ra

    # Draw "Retry s" on the screen.
    FUNCTION_DRAW_RETRY:

        # We'll be nesting funcs, so store $ra
        addi $sp, $sp, -4
        sw $ra, 0($sp)

        # $s2 = colour
        # $s3 = add to base addr
        # $s4 = base addr
        addi $sp, $sp, -4
        sw $s2, 0($sp)

        addi $sp, $sp, -4
        sw $s3, 0($sp)

        addi $sp, $sp, -4
        sw $s4, 0($sp)

        li $s2, 0xffffff    # colour white
        li $s4, 8272        # top left of R (20th col, 32nd row)
        add $s4, $s4, $s0
        li $s3, 20

        # Draw R
        # Left side
        move $a0, $s2
        move $a1, $s4
        li $a2, 3       # go down
        li $a3, 5       # draw 3 squares
        jal FUNCTION_DRAW_TOOL

        # top bar
        move $a0, $s2
        move $a1, $s4
        li $a2, 0       # go right
        li $a3, 2       # draw 3 squares
        jal FUNCTION_DRAW_TOOL

        # middle bar
        move $a0, $s2
        move $a1, $s4

        lw $t2, ROW_BELOW
        li $t3, 2
        mult $t2, $t3
        mflo $t2
        add $a1, $a1, $t2   # base

        li $a2, 0       # go right
        li $a3, 3       # draw 3 squares
        jal FUNCTION_DRAW_TOOL

        # inner right
        move $a0, $s2
        move $a1, $s4

        addi $a1, $a1, 8  # base

        li $a2, 3       # go down
        li $a3, 4       # draw 3 squares
        jal FUNCTION_DRAW_TOOL

        # outer right
        move $a0, $s2
        move $a1, $s4

        lw $t2, ROW_BELOW
        li $t3, 3
        mult $t2, $t3
        mflo $t2
        add $a1, $a1, $t2   # base
        addi $a1, $a1, 12  # base

        li $a2, 3       # go down
        li $a3, 2       # draw 3 squares
        jal FUNCTION_DRAW_TOOL

        # Draw E
        add $s4, $s4, $s3

        # Left col
        move $a0, $s2
        move $a1, $s4
        li $a2, 3       # go down
        li $a3, 5       # draw 3 squares
        jal FUNCTION_DRAW_TOOL

        # Top bar
        move $a0, $s2
        move $a1, $s4

        li $a2, 0       # go down
        li $a3, 3       # draw 3 squares
        jal FUNCTION_DRAW_TOOL

        # middle bar
        move $a0, $s2
        move $a1, $s4

        lw $t2, ROW_BELOW
        li $t3, 2
        mult $t2, $t3
        mflo $t2
        add $a1, $a1, $t2   # base

        li $a2, 0       # go right
        li $a3, 2       # draw 3 squares
        jal FUNCTION_DRAW_TOOL

        # bottom bar
        move $a0, $s2
        move $a1, $s4

        lw $t2, ROW_BELOW
        li $t3, 4
        mult $t2, $t3
        mflo $t2
        add $a1, $a1, $t2   # base

        li $a2, 0       # go right
        li $a3, 3       # draw 3 squares
        jal FUNCTION_DRAW_TOOL

        # Draw T
        add $s4, $s4, $s3
        addi $s4, $s4, -4

        # Top bar
        move $a0, $s2
        move $a1, $s4
        li $a2, 0       # go right
        li $a3, 5       # draw 3 squares
        jal FUNCTION_DRAW_TOOL

        # middle Column
        move $a0, $s2
        move $a1, $s4

        lw $t2, ROW_BELOW
        add $a1, $a1, $t2   # base
        addi $a1, $a1, 8

        li $a2, 3       # go down
        li $a3, 4       # draw 3 squares
        jal FUNCTION_DRAW_TOOL

        # Draw second R
        add $s4, $s4, $s3
        addi $s4, $s4, 4

        # Left side
        move $a0, $s2
        move $a1, $s4
        li $a2, 3       # go down
        li $a3, 5       # draw 3 squares
        jal FUNCTION_DRAW_TOOL

        # top bar
        move $a0, $s2
        move $a1, $s4
        li $a2, 0       # go right
        li $a3, 2       # draw 3 squares
        jal FUNCTION_DRAW_TOOL

        # middle bar
        move $a0, $s2
        move $a1, $s4

        lw $t2, ROW_BELOW
        li $t3, 2
        mult $t2, $t3
        mflo $t2
        add $a1, $a1, $t2   # base

        li $a2, 0       # go right
        li $a3, 3       # draw 3 squares
        jal FUNCTION_DRAW_TOOL

        # inner right
        move $a0, $s2
        move $a1, $s4

        addi $a1, $a1, 8  # base

        li $a2, 3       # go down
        li $a3, 4       # draw 3 squares
        jal FUNCTION_DRAW_TOOL

        # outer right
        move $a0, $s2
        move $a1, $s4

        lw $t2, ROW_BELOW
        li $t3, 3
        mult $t2, $t3
        mflo $t2
        add $a1, $a1, $t2   # base
        addi $a1, $a1, 12  # base

        li $a2, 3       # go down
        li $a3, 2       # draw 3 squares
        jal FUNCTION_DRAW_TOOL

        # Draw Y
        add $s4, $s4, $s3

        # left col
        move $a0, $s2
        move $a1, $s4
        li $a2, 3       # go down
        li $a3, 2       # draw 3 squares
        jal FUNCTION_DRAW_TOOL

        # right col
        move $a0, $s2
        move $a1, $s4
        addi $a1, $a1, 8    # base
        li $a2, 3       # go down
        li $a3, 2       # draw 3 squares
        jal FUNCTION_DRAW_TOOL

        # centre column
        move $a0, $s2
        move $a1, $s4
        lw $t2, ROW_BELOW
        add $a1, $a1, $t2   # base
        addi $a1, $a1, 4    # base
        li $a2, 3       # go down
        li $a3, 4       # draw 3 squares
        jal FUNCTION_DRAW_TOOL


        # Draw "s"
        # Centre of screen
        li $s4, 10360       # 10360 = col 30, row 40
        add $s4, $s4, $s0   # base of display

        # Draw the top bar
        move $a0, $s2
        move $a1, $s4
        li $a2, 0           # go right
        li $a3, 3           # draw 3 squares
        jal FUNCTION_DRAW_TOOL

        # Draw the middle bar
        move $a0, $s2
        move $a1, $s4
        lw $t2, ROW_BELOW
        li $t1, 2
        mult $t1, $t2
        mflo $t1
        add $a1, $a1, $t1   # middle row
        li $a2, 0           # go right
        li $a3, 3           # draw 3 squares
        jal FUNCTION_DRAW_TOOL

        # Draw the bottom bar
        move $a0, $s2
        move $a1, $s4
        lw $t2, ROW_BELOW
        li $t1, 4
        mult $t1, $t2
        mflo $t1
        add $a1, $a1, $t1   # middle row
        li $a2, 0           # go right
        li $a3, 3           # draw 3 squares
        jal FUNCTION_DRAW_TOOL

        # Draw right square
        move $a0, $s2
        move $a1, $s4
        lw $t2, ROW_BELOW
        li $t1, 3
        mult $t1, $t2
        mflo $t1
        add $a1, $a1, $t1   # middle row
        addi $a1, $a1, 8
        li $a2, 0           # go right
        li $a3, 1           # draw 1 square
        jal FUNCTION_DRAW_TOOL

        # Draw left square
        move $a0, $s2
        move $a1, $s4
        lw $t2, ROW_BELOW
        add $a1, $a1, $t2   # middle row
        li $a2, 0           # go right
        li $a3, 1           # draw 1 square
        jal FUNCTION_DRAW_TOOL

        # Restore callee saved reg's
        lw $s4, 0($sp)
        addi $sp, $sp, 4

        lw $s3, 0($sp)
        addi $sp, $sp, 4

        lw $s2, 0($sp)
        addi $sp, $sp, 4

        # Get our $ra back
        lw $ra, 0($sp)
        addi $sp, $sp, 4
        jr $ra

    # Draws the score on the display.
    # Args: $a0 = colour to draw.
    FUNCTION_DRAW_SCORE:
        # Because we have to call the draw tool function, we will lose our $ra
        # Therefore, we need to store it on the stack.
        addi $sp, $sp, -4
        sw $ra, 0($sp)

        # Going to use $s1 for the colour
        # We will use the following callee saved registers:
        #   $s1 = colour
        #   $s2 = score_digits array
        #   $s3 = loop counter
        #   $s4 = top left corner of digit's 7 seg display
        # Store these registers on the stack for preservation.
        addi $sp $sp, -4
        sw $s1, 0($sp)

        addi $sp $sp, -4
        sw $s2, 0($sp)

        addi $sp $sp, -4
        sw $s3, 0($sp)

        addi $sp $sp, -4
        sw $s4, 0($sp)

        move $s1, $a0
        la $s2, score_digits
        li $s3, 0               # loop counter

        DRAW_SCORE_LOOP:
            lw $t1, score_length
            beq $s3, $t1, FINISH_DRAWING_SCORE
            li $t3, 4
            mult $s3, $t3
            mflo $t3

            add $t3, $t3, $s2   # Offset in the score_digits array
            lw $t3, 0($t3)      # $t3 = address of struct

            # Get the value of the digit
            lw $t4, 4($t3)

            beq $t4, 0, DRAW_ZERO
            beq $t4, 1, DRAW_ONE
            beq $t4, 2, DRAW_TWO
            beq $t4, 3, DRAW_THREE
            beq $t4, 4, DRAW_FOUR
            beq $t4, 5, DRAW_FIVE
            beq $t4, 6, DRAW_SIX
            beq $t4, 7, DRAW_SEVEN
            beq $t4, 8, DRAW_EIGHT
            beq $t4, 9, DRAW_NINE

            DRAW_ZERO:
                lw $s4, 0($t3)  # base address of the 7-seg display
                # Draw the top bar
                move $a0, $s1     # colour
                move $a1, $s4     # base
                li $a2, 0       # go right
                li $a3, 3       # draw 3 squares

                jal FUNCTION_DRAW_TOOL

                # Draw the left side

                move $a0, $s1
                move $a1, $s4
                lw $t5, ROW_BELOW
                add $a1, $a1, $t5   # base
                li $a2, 3           # go down
                li $a3, 4           # 4 blocks

                jal FUNCTION_DRAW_TOOL

                # Draw the bottom bar
                move $a0, $s1
                move $a1, $s4
                lw $t5, ROW_BELOW
                li $t6, 4
                mult $t5, $t6
                mflo $t5
                addi $t5, $t5, 4
                add $a1, $a1, $t5

                li $a2, 0       # go right
                li $a3, 2       # draw 2 squares

                jal FUNCTION_DRAW_TOOL

                # Draw the right bar
                move $a0, $s1
                move $a1, $s4
                lw $t5, ROW_BELOW
                li $t6, 8
                add $t5, $t5, $t6
                add $a1, $a1, $t5

                li $a2, 3       # go down
                li $a3, 3       # draw 3 squares

                jal FUNCTION_DRAW_TOOL

                j FINISH_DRAWING_DIGIT

            DRAW_ONE:
                lw $s4, 0($t3)  # base address of the 7-seg display
                # Draw the right side
                move $a0, $s1       # colour
                move $a1, $s4       # base
                addi $a1, $a1, 8    # top right side
                li $a2, 3           # go down
                li $a3, 5           # draw 5 squares

                jal FUNCTION_DRAW_TOOL

                j FINISH_DRAWING_DIGIT

            DRAW_TWO:
                lw $s4, 0($t3)  # base address of the 7-seg display
                # Draw the top bar
                move $a0, $s1
                move $a1, $s4
                li $a2, 0           # go right
                li $a3, 3           # draw 3 squares

                jal FUNCTION_DRAW_TOOL

                # Draw the middle bar
                move $a0, $s1
                move $a1, $s4
                lw $t2, ROW_BELOW
                li $t1, 2
                mult $t1, $t2
                mflo $t1
                add $a1, $a1, $t1   # middle row
                li $a2, 0           # go right
                li $a3, 3           # draw 3 squares

                jal FUNCTION_DRAW_TOOL

                # Draw the bottom bar
                move $a0, $s1
                move $a1, $s4
                lw $t2, ROW_BELOW
                li $t1, 4
                mult $t1, $t2
                mflo $t1
                add $a1, $a1, $t1   # middle row
                li $a2, 0           # go right
                li $a3, 3           # draw 3 squares

                jal FUNCTION_DRAW_TOOL

                # Draw right square
                move $a0, $s1
                move $a1, $s4
                lw $t2, ROW_BELOW
                add $a1, $a1, $t2   # middle row
                addi $a1, $a1, 8
                li $a2, 0           # go right
                li $a3, 1           # draw 1 square

                jal FUNCTION_DRAW_TOOL

                # Draw left square
                move $a0, $s1
                move $a1, $s4
                lw $t2, ROW_BELOW
                li $t1, 3
                mult $t1, $t2
                mflo $t1
                add $a1, $a1, $t1   # middle row
                li $a2, 0           # go right
                li $a3, 1           # draw 1 square

                jal FUNCTION_DRAW_TOOL

                j FINISH_DRAWING_DIGIT

            DRAW_THREE:
                lw $s4, 0($t3)  # base address of the 7-seg display
                # Draw the right side
                move $a0, $s1       # colour
                move $a1, $s4       # base
                addi $a1, $a1, 8    # top right side
                li $a2, 3           # go down
                li $a3, 5           # draw 5 squares

                jal FUNCTION_DRAW_TOOL

                # Draw the top bar
                move $a0, $s1
                move $a1, $s4
                li $a2, 0           # go right
                li $a3, 2           # draw 2 squares

                jal FUNCTION_DRAW_TOOL

                # Draw the middle bar
                move $a0, $s1
                move $a1, $s4
                lw $t2, ROW_BELOW
                li $t1, 2
                mult $t1, $t2
                mflo $t1
                add $a1, $a1, $t1   # middle row
                li $a2, 0           # go right
                li $a3, 2           # draw 2 squares

                jal FUNCTION_DRAW_TOOL

                # Draw the bottom bar
                move $a0, $s1
                move $a1, $s4
                lw $t2, ROW_BELOW
                li $t1, 4
                mult $t1, $t2
                mflo $t1
                add $a1, $a1, $t1   # middle row
                li $a2, 0           # go right
                li $a3, 2           # draw 2 squares

                jal FUNCTION_DRAW_TOOL

                j FINISH_DRAWING_DIGIT

            DRAW_FOUR:
                lw $s4, 0($t3)  # base address of the 7-seg display
                # Draw the right side
                move $a0, $s1       # colour
                move $a1, $s4       # base
                addi $a1, $a1, 8    # top right side
                li $a2, 3           # go down
                li $a3, 5           # draw 5 squares

                jal FUNCTION_DRAW_TOOL

                # Draw the middle bar
                move $a0, $s1
                move $a1, $s4
                lw $t2, ROW_BELOW
                li $t1, 2
                mult $t1, $t2
                mflo $t1
                add $a1, $a1, $t1   # middle row
                li $a2, 0           # go right
                li $a3, 2           # draw 2 squares
                jal FUNCTION_DRAW_TOOL

                # Draw the left side
                move $a0, $s1       # colour
                move $a1, $s4       # base
                li $a2, 3           # go down
                li $a3, 2           # draw 2 squares
                jal FUNCTION_DRAW_TOOL

                j FINISH_DRAWING_DIGIT

            DRAW_FIVE:
                lw $s4, 0($t3)  # base address of the 7-seg display
                # Draw the top bar
                move $a0, $s1
                move $a1, $s4
                li $a2, 0           # go right
                li $a3, 3           # draw 3 squares

                jal FUNCTION_DRAW_TOOL

                # Draw the middle bar
                move $a0, $s1
                move $a1, $s4
                lw $t2, ROW_BELOW
                li $t1, 2
                mult $t1, $t2
                mflo $t1
                add $a1, $a1, $t1   # middle row
                li $a2, 0           # go right
                li $a3, 3           # draw 3 squares

                jal FUNCTION_DRAW_TOOL

                # Draw the bottom bar
                move $a0, $s1
                move $a1, $s4
                lw $t2, ROW_BELOW
                li $t1, 4
                mult $t1, $t2
                mflo $t1
                add $a1, $a1, $t1   # middle row
                li $a2, 0           # go right
                li $a3, 3           # draw 3 squares

                jal FUNCTION_DRAW_TOOL

                # Draw right square
                move $a0, $s1
                move $a1, $s4
                lw $t2, ROW_BELOW
                li $t1, 3
                mult $t1, $t2
                mflo $t1
                add $a1, $a1, $t1   # middle row
                addi $a1, $a1, 8
                li $a2, 0           # go right
                li $a3, 1           # draw 1 square

                jal FUNCTION_DRAW_TOOL

                # Draw left square
                move $a0, $s1
                move $a1, $s4
                lw $t2, ROW_BELOW
                add $a1, $a1, $t2   # middle row
                li $a2, 0           # go right
                li $a3, 1           # draw 1 square

                jal FUNCTION_DRAW_TOOL
                j FINISH_DRAWING_DIGIT

            DRAW_SIX:
                lw $s4, 0($t3)  # base address of the 7-seg display
                # Draw the left side
                move $a0, $s1       # colour
                move $a1, $s4       # base
                li $a2, 3           # go down
                li $a3, 5           # draw 5 squares
                jal FUNCTION_DRAW_TOOL

                # Draw the top bar
                move $a0, $s1
                move $a1, $s4
                li $a2, 0           # go right
                li $a3, 3           # draw 3 squares

                jal FUNCTION_DRAW_TOOL

                # Draw the middle bar
                move $a0, $s1
                move $a1, $s4
                lw $t2, ROW_BELOW
                li $t1, 2
                mult $t1, $t2
                mflo $t1
                add $a1, $a1, $t1   # middle row
                li $a2, 0           # go right
                li $a3, 3           # draw 3 squares

                jal FUNCTION_DRAW_TOOL

                # Draw the bottom bar
                move $a0, $s1
                move $a1, $s4
                lw $t2, ROW_BELOW
                li $t1, 4
                mult $t1, $t2
                mflo $t1
                add $a1, $a1, $t1   # middle row
                li $a2, 0           # go right
                li $a3, 3           # draw 3 squares

                jal FUNCTION_DRAW_TOOL

                # Draw the right side
                move $a0, $s1       # colour
                move $a1, $s4       # base
                lw $t2, ROW_BELOW
                li $t1, 2
                mult $t1, $t2
                mflo $t2
                addi $t2, $t2, 8
                add $a1, $a1, $t2
                li $a2, 3           # go down
                li $a3, 2           # draw 2 squares
                jal FUNCTION_DRAW_TOOL

                j FINISH_DRAWING_DIGIT

            DRAW_SEVEN:
                lw $s4, 0($t3)  # base address of the 7-seg display
                # Draw the right side
                move $a0, $s1       # colour
                move $a1, $s4       # base
                addi $a1, $a1, 8    # top right side
                li $a2, 3           # go down
                li $a3, 5           # draw 5 squares

                jal FUNCTION_DRAW_TOOL

                # Draw the top bar
                move $a0, $s1
                move $a1, $s4
                li $a2, 0           # go right
                li $a3, 3           # draw 3 squares

                jal FUNCTION_DRAW_TOOL

                j FINISH_DRAWING_DIGIT

            DRAW_EIGHT:
                lw $s4, 0($t3)  # base address of the 7-seg display
                # Draw the left side
                move $a0, $s1       # colour
                move $a1, $s4       # base
                li $a2, 3           # go down
                li $a3, 5           # draw 5 squares

                jal FUNCTION_DRAW_TOOL

                # Draw the right side
                move $a0, $s1       # colour
                move $a1, $s4       # base
                addi $a1, $a1, 8    # top right side
                li $a2, 3           # go down
                li $a3, 5           # draw 5 squares

                jal FUNCTION_DRAW_TOOL

                # Draw the top bar
                move $a0, $s1
                move $a1, $s4
                addi $a1, $a1, 4    # base is middle
                li $a2, 0           # go right
                li $a3, 1           # draw 1 square

                jal FUNCTION_DRAW_TOOL

                # Draw the middle bar
                move $a0, $s1
                move $a1, $s4
                lw $t2, ROW_BELOW
                li $t1, 2
                mult $t1, $t2
                mflo $t1
                add $a1, $a1, $t1   # middle row
                addi $a1, $a1, 4
                li $a2, 0           # go right
                li $a3, 1           # draw 1 square

                jal FUNCTION_DRAW_TOOL

                # Draw the bottom bar
                move $a0, $s1
                move $a1, $s4
                lw $t2, ROW_BELOW
                li $t1, 4
                mult $t1, $t2
                mflo $t1
                add $a1, $a1, $t1   # middle row
                addi $a1, $a1, 4
                li $a2, 0           # go right
                li $a3, 1           # draw 1 square

                jal FUNCTION_DRAW_TOOL

                j FINISH_DRAWING_DIGIT

            DRAW_NINE:
                lw $s4, 0($t3)  # base address of the 7-seg display
                # Draw the right side
                move $a0, $s1       # colour
                move $a1, $s4       # base
                addi $a1, $a1, 8    # top right side
                li $a2, 3           # go down
                li $a3, 5           # draw 5 squares

                jal FUNCTION_DRAW_TOOL

                # Draw the top bar
                move $a0, $s1
                move $a1, $s4
                li $a2, 0           # go right
                li $a3, 2           # draw 2 squares

                jal FUNCTION_DRAW_TOOL

                # Draw the middle bar
                move $a0, $s1
                move $a1, $s4
                lw $t2, ROW_BELOW
                li $t1, 2
                mult $t1, $t2
                mflo $t1
                add $a1, $a1, $t1   # middle row
                li $a2, 0           # go right
                li $a3, 3           # draw 3 squares

                jal FUNCTION_DRAW_TOOL

                # Draw the left side
                move $a0, $s1
                move $a1, $s4
                li $a2, 3           # go down
                li $a3, 2           # draw 2 squares

                jal FUNCTION_DRAW_TOOL

                j FINISH_DRAWING_DIGIT

            FINISH_DRAWING_DIGIT:
                # Increment loop counter.
                addi $s3, $s3, 1
                j DRAW_SCORE_LOOP

        FINISH_DRAWING_SCORE:

            # Restore $s registers.
            lw $s4, 0($sp)
            addi $sp $sp, 4
            lw $s3, 0($sp)
            addi $sp $sp, 4
            lw $s2, 0($sp)
            addi $sp $sp, 4
            lw $s1, 0($sp)
            addi $sp $sp, 4

            # Restore $ra
            lw $ra, 0($sp)
            addi $sp, $sp, 4

            jr $ra


    # Update the players score, as well as the score_digits array and more.
    FUNCTION_UPDATE_SCORE:
        # First, we increment the score by 1.
        la $t0, score

        lw $t1, 0($t0)
        addi $t1, $t1, 1
        sw $t1, 0($t0)

        # Next, we want to update the values in our digits array
        li $t0, 0           # current index in array and the counter
        lw $t2, score
        li $t3, 10          # divisor to get last digit of score

        # we're going to store the value of $s2 on the stack because I want to store the address
        # of the score_digits array there.
        addi $sp, $sp, -4
        sw $s2, 0($sp)

        la $s2, score_digits

        # We want to access each digit of the score.
        # While the result of division by 10 is non-zero,
        # divide by 10 and check the remainder.
        #
        # We read digits back to front, so score_digits is reversed
        SPLIT_SCORE_LOOP:
            div $t2, $t3
            mflo $t2            # quotient
            mfhi $t4            # remainder (last digit)

            li $t5, 4
            mult $t0, $t5
            mflo $t5

            add $t5, $t5, $s2   # offset in array
            lw $t6, 0($t5)      # $t6 = pointer to heap allocated struct base address

            addi $t6, $t6, 4    # address of second property of this struct
            sw $t4, 0($t6)      # update the value at this struct

            # If we've read the last digit, we're done.
            beq $t2, $zero, END_SCORE_UPDATE

            # Otherwise, we have more digits to count.
            addi $t0, $t0, 1
            j SPLIT_SCORE_LOOP

        END_SCORE_UPDATE:
            # reset the value of $s2
            lw $s2, 0($sp)
            addi $sp, $sp, 4

            la $t1, score_length
            addi $t0, $t0, 1
            sw $t0, 0($t1)      # update the number of digits in the score.
            jr $ra

    # the doodle has hit max height and so we have to move the platforms down.
    UPDATE_PLATFORMS:
        # Erase the current score
        lw $a0, background
        jal FUNCTION_DRAW_SCORE
        # Update the game score.
        jal FUNCTION_UPDATE_SCORE

        lw $a0, score_colour
        jal FUNCTION_DRAW_SCORE

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
            li $t0, -1
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

                # In this loop, we perform row_arr[i] = row_arr[i + 1]
                # for every platform excluding the last.
                # This is how we shift the middle to the bottom, the top to the middle, etc.
                SWAP_PLATFORMS_LOOP:
                    lw $t2, num_platforms
                    addi $t2, $t2, -1       # We will modify all but the final platform

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

                    # -REMARK-
                    # We can't just swap pointers in platform_type, we have shift the values of the structs
                    la $t4, platform_type
                    add $t3, $t3, $t4   # offset into platform_type
                    addi $t5, $t3, 4    # offset + 4 is the next platform

                    lw $t0, 0($t5)      # $t0 = platform_type[i + 1]
                    lw $t2, 0($t3)      # $t2 = platform_type[i]

                    # Next, access each property of the struct $t0 and store it in the corresponding
                    # property of struct $t2
                    # swap platform type
                    lw $t4, 0($t0)
                    sw $t4, 0($t2)

                    # swap contact value
                    lw $t4, 4($t0)
                    sw $t4, 4($t2)

                    # swap direction value
                    lw $t4, 8($t0)
                    sw $t4, 8($t2)

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

                    # generate the platforms location
                    jal FUNCTION_GENERATE_RANDOM_PLATFORM
                    add $t0, $zero, $v0

                    # store $t0
                    addi $sp, $sp, -4
                    sw $t0, 0($sp)

                    # generate the type of platform
                    jal FUNCTION_GENERATE_PLATFORM_TYPE

                    # Pop the old $t0 value off the stack
                    lw $t0, 0($sp)
                    addi $sp, $sp, 4

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
                li $t0, 1
                addi $sp, $sp, -4
                sw $t0, 0($sp)
                jal FUNCTION_DRAW_PLATFORM_LOOP

                # A platform may have come down through the score so we have to redraw it.
                lw $a0, score_colour
                jal FUNCTION_DRAW_SCORE

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
    #    2 if collision detected on special platform
    #   -1 if we fell past the candidate platform
    # Mutates:
    #   if there's a collision and the candidate platform is a special platform
    #       - i.e platform types 1 (disappearing) and 3 (shifting)
    #   then we set platform_arr[candidate_platform]->contact = 1
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
            # Check if this is a type 1 or 3 platform
            la $t1, platform_type
            li $t2, 4
            lw $t0, candidate_platform
            mult $t0, $t2
            mflo $t2            # offset

            add $t1, $t1, $t2   # address of candidate_platform in platform_type array
            lw $t2, 0($t1)      # address of the struct belonging to this candidate_platform

            lw $t1, 0($t2)      # platform_type[candidate_platform]->type
            beq $t1, 1, DISAPPEARING_PLATFORM
            beq $t1, 3, SPECIAL_COLLISION

            # normal collision
            li $v0, 1
            jr $ra

            DISAPPEARING_PLATFORM:
                # Check if contact == 1, if so then fall past the platform
                lw $t1, 4($t2)
                beq $t1, 1, FELL_PAST_PLATFORM
                # otherwise contact == 0 so we have a special collision

            SPECIAL_COLLISION:
                # We want to set platform_type[candidate_platform]->contact = 1
                li $t1, 1
                sw $t1, 4($t2)
                li $v0, 2
                jr $ra

        NO_COLLISION:
            li $v0, 0
            jr $ra

        FELL_PAST_PLATFORM:
            li $v0, -1
            jr $ra

    # Create a random shift for the shift platform that we just collided with.
    # Args: $a0 = leftmost block offset for the platform.
    # Returns
    #   $v0: direction to move in (+/- 1)
    #   $v1: columns to move [2, display_width/block_size - platform_width]
    FUNCTION_RANDOM_SHIFT:
        # first, we have to check if we're close to the boundary.
        move $t0, $a0
        li $t1, 8
        div $t0, $t1
        mflo $t1

        # If $t1 is within 8 blocks of column 0 we're on the left side so we have to go right.
        addi $t2, $t1, -8
        blez $t1, SHIFT_LEFT_BOUNDARY

        # If $t0 = (display_width/block_size) - platform_width we're on the right side.
        lw $t2, display_width
        lw $t3, block_size
        div $t2, $t3
        mflo $t2
        lw $t3, platform_width

        sub $t2, $t2, $t3
        addi $t2, $t2, -8       # $t2 = display_width/block_size - 8 - platform_width

        # If x < $t2, then we're within the valid arena, so we can move 8 blocks in any direction
        sub $t3, $t1, $t2
        bgez $t3, SHIFT_RIGHT_BOUNDARY

        # If we're here, we will move a random amount from 0 to 8
        j SHIFT_RANDOM_DIRECTION

        # Will force shift right
        SHIFT_LEFT_BOUNDARY:
            li $t3, 1
            j AVOID_WALL

        # Will force shift left
        SHIFT_RIGHT_BOUNDARY:
            li $t3, -1
            j AVOID_WALL

        SHIFT_RANDOM_DIRECTION:
            li $a0, 0
            li $v0, 41
            syscall
            move $t3, $a0

            # if our number is divisible by 2 then we'll go right
            li $t2, 2
            div $t3, $t2
            mfhi $t3
            beq $t3, 0, SHIFT_RIGHT

            # otherwise go left
            j SHIFT_LEFT

            SHIFT_RIGHT:
                li $t3, 1
                j VALID_ZONE_SHIFT

            SHIFT_LEFT:
                li $t3, -1
                j VALID_ZONE_SHIFT

            VALID_ZONE_SHIFT:
                # we want to shift by random_range(0, 6), + 2 so [2, 8] columns.
                li $a0, 0
                li $a1, 6
                li $v0, 42
                syscall

                # return
                # First, recall that $t3 = direction
                move $v0, $t3
                move $v1, $a0
                addi $v1, $v1, 2    # moves us from [0, 6] -> [2, 8]

                jr $ra

        # pick any random distance within a range of [2, 12] cols of the platform.
        AVOID_WALL:
            # t3 stores our direction
            li $a0, 0
            li $a1, 10
            li $v0, 42
            syscall

            # return
            move $v0, $t3
            move $v1, $a0
            addi $v1, $v1, 2    # moves us from [0, 10] -> [2, 12]

            jr $ra

    FALL:
        li $s6, 0       # number of rows we've fallen so far
        FALL_LOOP:
            jal FUNCTION_COLLISION_DETECTION
            # 2 if special collision occured
            # 1 if collision occured
            # 0 if no platform nearby
            # -1 if fell past platform.
            add $s4, $zero, $v0

            li $t1, 2
            beq $s4, $t1, LANDED_ON_SPECIAL

            li $t1, 1
            beq $s4, $t1, JUMP

            # We're falling at this point, deal with it.
            # First, lets check if we fell past the platform, since it could mean game over.
            li $t1, -1
            beq $s4, $t1, DECREMENT_CANDIDATE_PLATFORM
            j HANDLE_FALL

            # TODO
            # We landed on a type 1 or type 3 platform.
            LANDED_ON_SPECIAL:
                li $t0, 4
                lw $t1, candidate_platform
                mult $t0, $t1
                mflo $t1

                la $t0, platform_type
                add $t1, $t1, $t0       # offset in array.

                lw $t2, 0($t1)          # address of the struct
                lw $t2, 0($t2)          # type of platform

                beq $t2, 1, LANDED_ON_TYPE1
                beq $t2, 3, LANDED_ON_TYPE3

                # If we've landed on a type 1 (disappearing) platform
                # We're going to hijack the .contact property and turn it into a countdown.
                # This will be used by the platform drawing code as a loop counter.
                # .contact's final value will be 1.
                LANDED_ON_TYPE1:
                    lw $t2, 0($t1)      # address of struct
                    li $t0, 4
                    sw $t0, 4($t2)      # .contact = 4
                    j JUMP

                # If we landed on a type 3 (shifting) platform
                # We're going to hijack the .contact property and turn it into a countdown.
                # This will be used by the platform drawing code as a loop counter.
                # Next, we will change the .direction property depending on what direction is safe.
                # .contact's final value will be 0.
                LANDED_ON_TYPE3:
                    # TODO: THIS REQUIRES TESTING
                    la $t2, platform_type
                    sub $t3, $t1, $t2
                    la $t2, platform_arr
                    add $t3, $t2, $t3   # offset in platfrom_arr

                    # We need to hold on to $t1 because it's useful
                    addi $sp, $sp, -4
                    sw $t1, 0($sp)

                    lw $a0, 0($t3)      # send the current column to the arg
                    jal FUNCTION_RANDOM_SHIFT

                    lw $t1, 0($sp)
                    addi $sp, $sp, 4

                    move $t0, $v0       # direction

                    lw $t2, 0($t1)      # address of struct
                    sw $t0, 8($t2)      # .direction = direction (+/-1)

                    move $t0, $v1       # columns to move
                    sw $t0, 4($t2)      # .contact = iterator now
                    j JUMP

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
                # Get the velocity according to doodle physics
                move $a0, $s6
                li $a1, -1

                jal FUNCTION_PHYSICS
                move $a0, $v0

                li $v0, 32
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

                # TODO: we may need to save some registers
                jal FUNCTION_MOVE_MOVING_PLATFORMS

                # Redraw platform
                # TODO: When we move the map (doodle hit max height), the doodle may be "inside"
                #       the top platform. Therefore, when it falls, as we erase it, we erase
                #       the platform as well, so we're taking this into account by redrawing it here.
                # There has to be a more efficient way to do this, I don't want to draw in a bunch of edge
                # cases, it's adding complexity.
                li $t0, 1
                addi $sp, $sp, -4
                sw $t0, ($sp)
                jal FUNCTION_DRAW_PLATFORM_LOOP

                # Redraw the score because the platform may have overwritten it.
                lw $a0, score_colour
                jal FUNCTION_DRAW_SCORE

                addi $s6, $s6, 1
                j FALL_LOOP

    # Args: $a0 = index of jump
    #       $a1 = direction
    FUNCTION_PHYSICS:
        # Save registers $s1, $s2, $s3
        addi $sp, $sp, -4
        sw $s1, 0($sp)

        addi $sp, $sp, -4
        sw $s2, 0($sp)

        addi $sp, $sp, -4
        sw $s3, 0($sp)

        move $s1, $a0
        move $s2, $a1

        beq $s2, 1, JUMP_PHYSICS

        # If we've fallen more than 24 rows, our speed will no longer change
        li $s3, 24
        sub $s3, $s1, $s3

        bgtz $s3, TERMINAL_VELOCITY
        j FALL_PHYSICS

        JUMP_PHYSICS:
            # If 0<= x <= 20 go to PARABOLIC_ASCENT
            li $s3, 20
            sub $s3, $s3, $s1
            bgtz, $s3, PARABOLIC_ASCENT
            j LINEAR_ASCENT

            # If 0 <= x <= 20
            # f(x) = 40 + (x^2)/20
            PARABOLIC_ASCENT:
                mult $s1, $s1
                mflo $s1

                li $s3, 20
                div $s1, $s3
                mflo $s1

                addi $s1, $s1, 40

                move $v0, $s1
                j FINALIZE_PHYSICS

            # If 20 < x <= 24
            # f(x) = 30(x - 20) + 60
            LINEAR_ASCENT:
                addi $s1, $s1, -20

                li $s3, 30
                mult $s1, $s3
                mflo $s1

                addi $s1, $s1, 60

                move $v0, $s1
                j FINALIZE_PHYSICS

        FALL_PHYSICS:
            # If 0 <= x <= 4 go to LINEAR_DESCENT
            li $s3, 4
            sub $s3, $s3, $s1
            bgtz, $s3, LINEAR_DESCENT
            j PARABOLIC_DESCENT

            # 4 < x <= 24
            # f(x) = 40 + ((x-24)^2)/20
            PARABOLIC_DESCENT:
                addi $s1, $s1, -24
                mult $s1, $s1
                mflo $s1
                li $s3, 20
                div $s1, $s3
                mflo $s1

                addi $s1, $s1, 40
                move $v0, $s1
                j FINALIZE_PHYSICS

            # 0 <=x <= 4
            # f(x) = -30(x) + 180
            LINEAR_DESCENT:
                li $s3, -30
                mult $s1, $s3
                mflo $s1
                addi $s1,$s1, 180
                move $v0, $s1
                j FINALIZE_PHYSICS

        # Can't go any faster
        TERMINAL_VELOCITY:
            lw $v0, jump_sleep_time
            j FINALIZE_PHYSICS

        FINALIZE_PHYSICS:
            # Restore our registers
            lw $s3, 0($sp)
            addi $sp, $sp, 4
            lw $s2, 0($sp)
            addi $sp, $sp, 4
            lw $s1, 0($sp)
            addi $sp, $sp, 4

            jr $ra

    # Erase the platforms, update the moving platform positions, and redraw them
    FUNCTION_MOVE_MOVING_PLATFORMS:
        # Save ra
        addi $sp, $sp, -4
        sw $ra, 0($sp)

        # use s1, s2, s3
        addi $sp, $sp, -4
        sw $s1, 0($sp)

        addi $sp, $sp, -4
        sw $s2, 0($sp)

        addi $sp, $sp, -4
        sw $s3, 0($sp)

        addi $sp, $sp, -4
        sw $s4, 0($sp)

        # 0 until we encounter and update a moving platform
        li $s4, 0

        # Loop counter
        li $s1, 0
        # loop each platform
        LOOP_UPDATE_MOVING_PLATFORMS:
            lw $t1, num_platforms
            beq $s1, $t1, REDRAW_MOVED_PLATFORMS

            # otherwise, get the offset
            li $t1, 4
            mult $t1, $s1
            mflo $t1                # offset
            # Next, check if we're at an edge
            la $t9, platform_arr
            add $s2, $t1, $t9       # address containing column offset
            lw $s2, 0($s2)          # $s2 = column offset

            li $s3, 4
            div $s2, $s3
            mflo $s2                # $s2 in [0, display_width/block_size - 1]

            # Now we have to check if we're on the left or right side
            beq $s2, 0, SEND_RIGHT

            lw $s3, display_width

            # TODO: Save $t3 before we call FUNCTION_MOVE_MOVING_PLATFORM
            lw $t3, block_size
            div $s3, $t3
            mflo $t3
            lw $s3, platform_width
            sub $t3, $t3, $s3
            addi $t3, $t3, -1

            beq $s2, $t3, SEND_LEFT
            # Otherwise, get the direction we currently store
            la $t3, platform_type
            add $t3, $t3, $t1       # offset in platform_type
            lw $t3, 0($t3)          # address of struct

            lw $s2, 0($t3)          # check type first
            bne $s2, 2, FETCH_NEXT_PLATFORM

            lw $s2, 8($t3)          # direction
            j MOVE_PLATFORM

            SEND_RIGHT:
                la $t3, platform_type
                add $t3, $t3, $t1   # offset in platform_type
                lw $t3, 0($t3)      # address of struct


                lw $s2, 0($t3)      # check type first
                bne $s2, 2, FETCH_NEXT_PLATFORM

                li $s2, 1
                sw $s2, 8($t3)      # update the direction
                j MOVE_PLATFORM

            SEND_LEFT:
                la $t3, platform_type
                add $t3, $t3, $t1   # offset in platform_type
                lw $t3, 0($t3)      # address of struct

                lw $s2, 0($t3)          # check type first
                bne $s2, 2, FETCH_NEXT_PLATFORM

                li $s2, -1
                sw $s2, 8($t3)      # update the direction
                j MOVE_PLATFORM

            # We only get here if we have a type 2 platform
            MOVE_PLATFORM:
                # First, we only want to erase once.
                beq $s4, 0, ERASE_FOR_UPDATE
                j MODIFY_POSITION

                ERASE_FOR_UPDATE:
                    addi $sp, $sp, -4
                    sw $t1, 0($sp)

                    li $s4, -1
                    addi $sp, $sp, -4
                    sw $s4, 0($sp)

                    jal FUNCTION_DRAW_PLATFORM_LOOP

                    lw $t1, 0($sp)
                    addi $sp, $sp, 4

                    li $s4, 1           # update flag so that we redraw the platforms.

                MODIFY_POSITION:
                    li $s3, 4
                    mult $s3, $s2
                    mflo $s2            # add this to our current column
                    add $s3, $t9, $t1   # offset of the platform in platform_arr
                    lw $t1, 0($s3)
                    add $t1, $t1, $s2   # new value
                    sw $t1, 0($s3)      # platform_arr[index] (+/-)= 4

            FETCH_NEXT_PLATFORM:
                addi $s1, $s1, 1
                j LOOP_UPDATE_MOVING_PLATFORMS

        REDRAW_MOVED_PLATFORMS:
            # We've updated any present moving platforms.
            # However, we only want to draw if we made updates.
            beq $s4, 1, PERFORM_REDRAW
            j RESTORE_AND_EXIT

            PERFORM_REDRAW:
                li $s1, 1
                addi $sp, $sp, -4
                sw $s1, 0($sp)

                jal FUNCTION_DRAW_PLATFORM_LOOP
                j RESTORE_AND_EXIT

            RESTORE_AND_EXIT:
                # restore $sx
                lw $s4, 0($sp)
                addi $sp, $sp, 4

                lw $s3, 0($sp)
                addi $sp, $sp, 4

                lw $s2, 0($sp)
                addi $sp, $sp, 4

                lw $s1, 0($sp)
                addi $sp, $sp, 4

                lw $ra, 0($sp)
                addi $sp, $sp, 4

                jr $ra


    # Check and resolve any pending updates of special platforms.
    FUNCTION_RESOLVE_SPECIAL_UPDATES:
        # using $s1 for the loop counter
        addi $sp, $sp, -4
        sw $s1, 0($sp)

        li $s1, 0

        # Can use t2, t3
        RESOLVE_LOOP:
            la $t7, platform_type
            lw $t1, num_platforms
            beq $s1, $t1, COMPLETE_SPECIAL_UPDATE

            li $t2, 4
            mult $s1, $t2
            mflo $t2

            add $t3, $t2, $t7       # offset in platform_type
            lw $t3, 0($t3)          # address of struct

 #           lw $t4, 0($t3)          # platform type, we only care if type 2
#            beq $t4, 2, MOVE_MOVING_PLATFORM

            lw $t4, 4($t3)          # .contact value, repurposed as a counter if contact was made with type 1 or 3

            # Check if the counter is 0, if so go to the next platform.
            beq $t4, 0, PARSE_NEXT_PLATFORM

            lw $t4, 0($t3)          # platform type
            beq $t4, 1, CHECK_DISAPPEARING_PLATFORM
            beq $t4, 3, CHECK_SHIFTER_PLATFORM
            j PARSE_NEXT_PLATFORM

            CHECK_DISAPPEARING_PLATFORM:
                # Draw the platform the colour associated with the .contact value,
                # and then decrement the counter stored in .contact
                # If the counter (.contact) = 1, the platform should be the background colour.

                # Save $ra before we call func
                addi $sp, $sp, -4
                sw $ra, ($sp)

                # using $s3
                addi $sp, $sp, -4
                sw $s3, 0($sp)

                addi $sp, $sp, -4
                sw $t3, ($sp)

                # Access this decremented contact gradient value.
                # We have to do this in draw_platfrom_loop.
                # I think we may need to add an arguement...
                li $s3, 1       # draw, don't erase
                addi $sp, $sp, -4
                sw $s3, 0($sp)

                jal FUNCTION_DRAW_PLATFORM_LOOP

                # restore $t3
                lw $t3, 0($sp)
                addi $sp, $sp, 4

                # Now that we've drawn it, decrement the counter.
                lw $s3, 4($t3)      # columns remaining to move
                addi $s3, $s3, -1   # decrement it
                sw $s3, 4($t3)      # .contact -= .contact

                # If we've decremented to 0, it's time for this platform to disappear.
                beq $s3, 0, REMOVE_PLATFORM
                j CONTACT_NOT_FINALIZED

                REMOVE_PLATFORM:
                    li $s3, 1
                    sw $s3, 4($t3)      # .contact = 1 (final value)

                CONTACT_NOT_FINALIZED:
                    # restore $s3
                    lw $s3, 0($sp)
                    addi $sp, $sp, 4

                    # restore $ra
                    lw $ra, 0($sp)
                    addi $sp, $sp, 4

                    j PARSE_NEXT_PLATFORM

            CHECK_SHIFTER_PLATFORM:
                # Store $t2, $t3, $t4, $ra on the stack
                addi $sp, $sp, -4
                sw $ra, ($sp)

                addi $sp, $sp, -4
                sw $t2, ($sp)

                addi $sp, $sp, -4
                sw $t3, ($sp)

                addi $sp, $sp, -4
                sw $t4, ($sp)

                # First we erase them
                li $t1, -1
                addi $sp, $sp, -4
                sw $t1, ($sp)

                jal FUNCTION_DRAW_PLATFORM_LOOP

                # restore $t2, $t4, $ra from the stack
                lw $t4, ($sp)
                addi $sp, $sp, 4

                lw $t3, ($sp)
                addi $sp, $sp, 4

                lw $t2, ($sp)
                addi $sp, $sp, 4

                lw $ra, ($sp)
                addi $sp, $sp, 4

                # Shift it in the chosen direction and then decrement the counter stored in .contact
                la $t9, platform_arr
                add $t4, $t2, $t9   # Offset in platform_arr array

                lw $t2, 0($t4)      # current column * 4

                # using $s2
                addi $sp, $sp, -4
                sw $s2, 0($sp)
                # using $s3
                addi $sp, $sp, -4
                sw $s3, 0($sp)


                lw $s3, 4($t3)      # columns remaining to move
                addi $s3, $s3, -1   # decrement it
                sw $s3, 4($t3)      # .contact -= .contact

                lw $s2, 8($t3)      # direction of travel
                li $s3, 4
                mult $s2, $s3       # +/- 4, aka right/left 1 block
                mflo $s3

                add $t2, $t2, $s3   # new column position
                sw $t2, 0($t4)

                # restore $s3
                addi $sp, $sp, -4
                sw $s3, 0($sp)

                # restore $s2
                addi $sp, $sp, -4
                sw $s2, 0($sp)

                # Store $t2, $t4, $ra on the stack
                addi $sp, $sp, -4
                sw $ra, ($sp)

                addi $sp, $sp, -4
                sw $t2, ($sp)

                addi $sp, $sp, -4
                sw $t3, ($sp)

                addi $sp, $sp, -4
                sw $t4, ($sp)

                # Now we redraw
                li $t1, 1
                addi $sp, $sp, -4
                sw $t1, ($sp)

                jal FUNCTION_DRAW_PLATFORM_LOOP

                # restore $t2, $t4, $ra from the stack
                lw $t4, ($sp)
                addi $sp, $sp, 4

                lw $t3, ($sp)
                addi $sp, $sp, 4

                lw $t2, ($sp)
                addi $sp, $sp, 4

                lw $ra, ($sp)
                addi $sp, $sp, 4

                j PARSE_NEXT_PLATFORM

        PARSE_NEXT_PLATFORM:
            addi $s1, $s1, 1
            j RESOLVE_LOOP

        COMPLETE_SPECIAL_UPDATE:
            lw $s1, 0($sp)
            addi $sp, $sp, 4

            jr $ra


    # TODO: each time we go up a row we're going to modify our special platforms if they have pending modifications.
    #       For example: We just bounced off a shift platform, so each time we move up a row we shift that platform.
    JUMP:
        li $s1, 0                   # $s1 will be our counter that lets us know how many more times we have to move the doodle up
        la $t8, row_arr

        BOUNCE_LOOP:
            # Get the velocity according to doodle physics
            move $a0, $s1
            li $a1, 1
            jal FUNCTION_PHYSICS

            move $a0, $v0
            li $v0, 32
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

            # TODO: we may need to save some registers
            jal FUNCTION_MOVE_MOVING_PLATFORMS
            # Perform the updates to our special platforms
            jal FUNCTION_RESOLVE_SPECIAL_UPDATES

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
                li $t1, 1
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

    # Move the score position to the centre of the screen
    la $t0, score_digits
    lw $t1, score_length
    li $t2, 0

    REPOSITION_SCORE:
        beq $t2, $t1, DISPLAY_END_SCREEN
        li $t3, 4
        mult $t2, $t3
        mflo $t3

        add $t3, $t3, $t0
        lw $t4, 0($t3)
        lw $t5, 0($t4)
        addi $t5, $t5, -112
        sw $t5, 0($t4)

        addi $t2, $t2, 1
        j REPOSITION_SCORE

    DISPLAY_END_SCREEN:
        # Display the final score
        li $a0, 0xffffff
        jal FUNCTION_DRAW_SCORE
        jal FUNCTION_DRAW_RETRY

        # deallocate the heap
        jal FUNCTION_DEALLOCATE_PLATFORM_TYPES
    RETRY:
        # Wait for the signal "s" to restart the game.
        jal FUNCTION_READ_KEYBOARD_INPUT
        add $t0, $zero, $v0
        li $t1, 2
        beq $t0, $t1, RESET_GAME
        j RETRY

    RESET_GAME:
        # Clear the score.
        la $t0, score
        la $t1, score_length

        li $t2, 0
        sw $t2, 0($t0)

        addi $t2, $t2, 1
        sw $t2, 0($t1)
        j MAIN

    li $v0, 10 		# terminate the program gracefully
    syscall

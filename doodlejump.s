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
#   - Display width in pixels: 256
#   - Display height in pixels: 256
#   - Base Address for Display: 0x10008000 ($gp)
#
# Which milestone is reached in this submission?
#   - Milestone 1/2/3/4/5 (choose the one the applies)
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
    background:         .word 0xffffff          # Background colour of the display
    doodle_colour:      .word 0x000fff
    platform_colour:    .word 0x00ff00

    displayAddress:     .word 0x10008000

    platform_width:     .word 8                 # platform width
    num_platforms:      .word 3

    # Array of 3 platforms.
    #   - in both platform_arr and row_arr, the first entry is the bottom platform.
    #   - platform_arr stores the leftmost column index (col * 4, col in [0, 31-platform_width])
    #   - row_arr stores the row index (row*128, row in [0, 31])
    #       - we pick 128 because that's the index of the first block after the 1st row
    platform_arr:       .word 0:3
    row_arr:            .word 3968,2688,1408    # Store the row_indexes of each platform. Add these to displayAddress.

    # Doodle Character
    #   - We will only store the bottom left of the doodle, the rest can easily be calculated on the fly.
    #   - We will store it's offset as a value in [0, 4092], so we have to add it to the base of the display
    #     when drawing.
    doodle_origin:      .word 0                 # Storing [0, 4092] makes bounds/collision detection easier.

.text
    MAIN:
        # setup
        lw $s0, displayAddress 	# $s0 stores the base address for display
        add $s1, $zero, $s0     # $s1 stores the location of the current block

        # ~~platforms~~
        add $s5, $zero, $zero   # 0 => have yet to draw platforms, 1 => starting platforms have been drawn.
        add $s7, $0, $0         # 0 => have yet to draw doodle,    1 => starting doodle has been drawn.
        j DRAW_BACKGROUND

    # this section of code is where we are idle.
    GAME_LOOP:
        # 1. Check for keyboard input
        #   a. Update the location of the doodle
        #   b. Check for collision events.
        # 2. If doodle is at max height, update platforms
        #   a. We're going to have to check if the keys are pressed while the platforms are updated.
        # 3. Redraw screen
        # 4. Sleep
        # 5. Go back to step #1

        li $v0 32
        addi $a0, $zero, 500
        syscall

        j UPDATE_PLATFORMS

    DRAW_BACKGROUND:
        # first, we want to make sure we're not at the last block
        addi $t2, $s0, 4096 # based address + 4096
        # if we've drawn the background, start other assets.
        beq $s1, $t2, SETUP_GAME

        # otherwise, make the block white and increment!
        lw $t0, background
        sw $t0, 0($s1)
        addi $s1, $s1, 4

        # go to the top of the loop.
        j DRAW_BACKGROUND

    SETUP_GAME:
        add $s1, $zero, $s0 # current block
        # We always have 3 platforms visible.
        add $t2 $zero, $zero

        # TODO: Set up and draw the character.
        # if $s5 is 0, draw the platforms, otherwise skip
        beq $s5, $t2, SET_PLATFORMS
        # if $s7 is 0, draw the doodle, otherwise skip
        beq $s7, $t2, SET_DOODLE
        j GAME_LOOP

    # In SET_PLATFORMS we determine the horizontal position of each platform.
    SET_PLATFORMS:
        # 1. set the left bound of each platform
        #       TODO: will need bounds checking later.
        # platform width = 8 blocks
        # left most is column 12 (default for testing)

        # want column index 12*4 = 48, rows 31, 21, and 11
        la $t9, platform_arr    # our array of platform origins

        # bottom platform
        add $t0, $zero, $zero   # current index i in platform_arr
        add $t1, $t9, $t0       # $t1 = platform_arr[i]
        addi $t2, $zero, 48     # column_index = column * 4
        sw $t2, 0($t1)          # platform_arr[i] = column_index
        addi $t0, $t0, 4        # increment our index to the next word

        # middle platform
        add $t1, $t9, $t0       # $t1 = platform_arr[i]
        sw $t2, 0($t1)          # platform_arr[i] = column_index
        addi $t0, $t0, 4        # increment our index to the next word

        # top platform
        add $t1, $t9, $t0       # $t1 = platform_arr[i]
        sw $t2, 0($t1)          # platform_arr[i] = column_index

        # put the platform colour on the stack before drawing.
        lw $t8, platform_colour
        addi $sp, $sp, -4
        sw $t8, 0($sp)

        jal FUNCTION_DRAW_PLATFORM_LOOP

        # set $s5 to 1 to indicate we have drawn the starting platforms.
        addi $s5, $zero, 1
        j SETUP_GAME

    # In SET_DOODLE, we want to initiate the doodle above the (centre?)
    # of the bottom platform.
    # Since the platforms have been validated, we don't need to check any errors.
    SET_DOODLE:
        lw $t0, platform_arr
        lw $t1, row_arr
        lw $t2, doodle_colour
        la $t3, doodle_origin

        add $t0, $t0, $t1       # $t0 = offset of the 1st block of the bottom platform
        addi $t0, $t0, -120     # -120 = -128 + 8 = 1 row above, 3 blocks to the right
        sw $t0, 0($t3)          # doodle_origin = 3rd block of bottom platform

        # move the doodle's colour onto the stack
        addi $sp, $sp, -4
        sw $t2, 0($sp)
        jal FUNCTION_DRAW_DOODLE
        addi $s7, $zero, 1      # $s7 = 1, so we have finished drawing the initial doodle.
        j SETUP_GAME

    # Draw the doodle given the bottom left block
    # If we enter this function, we assume that the bounds checks etc have all been done.
    FUNCTION_DRAW_DOODLE:
        # $t0 = colour of the doodle.
        lw $t0, 0($sp)
        addi $sp, $sp, 4

        lw $t1, doodle_origin
        # Draw as follows:
        #	 1. Origin
        #	 2. Origin + 8
        #	 3. Origin - 128
        #	 4. Origin - 124
        #	 5. Origin - 120
        #	 6. Origin - 252

        add $t1, $t1, $s0   # recall $s0 = displayAddress
        addi $t2, $t1, 8
        addi $t3, $t1, -128
        addi $t4, $t1, -124
        addi $t5, $t1, -120
        addi $t6, $t1, -252

        # draw each location
        sw $t0, 0($t1)
        sw $t0, 0($t2)
        sw $t0, 0($t3)
        sw $t0, 0($t4)
        sw $t0, 0($t5)
        sw $t0, 0($t6)

        jr $ra

    FUNCTION_DRAW_PLATFORM_LOOP:
        # In FUNCTION_DRAW_PLATFORM_LOOP, we get each platform
        # from platform_arr and draw it using the colour on the stack.

        lw $t7, 0($sp)      # get the colour off the stack
        addi $sp, $sp, 4    # reset the stack pointer

        # Throughout FUNCTION_DRAW_PLATFORM_LOOP, $s2 will be the offset for the arrays.
        add $s2, $zero, $zero
        la $t8, row_arr         # our array of row indexes
        la $t9, platform_arr    # our array of platform origins

        GET_PLATFORM:
            lw $t1, num_platforms   # loop condition
            addi $t2, $zero, 4
            mult $t1, $t2
            mflo $t1                # $t1 = num_platforms * 4

            # While i < num_platforms * 4, required because the next element is at arr[i + 4]
            beq $s2, $t1, COMPLETE_PLATFORM

            # Draw the current platform from our array.
            add $t2, $zero, $zero   # current block being drawn.
            lw $t3, platform_width
            addi $t4, $zero, 4
            mult $t3, $t4
            mflo $t3                # required for loop condition, 4*platform width

            # 1. get the row_index from row_arr[i]
            add $t4, $t8, $s2   # addr(row_arr[i])
            lw $t5, 0($t4)

            # 2. add the row index to the base of the display, positions us in the display.
            add $t5, $t5, $s0   # $t5 holds row_arr[i]'s actual position in the display

            # 3. get the column index from platform_arr[i]
            add $t4, $t9, $s2   # addr(platform_arr[i])
            lw $s6, 0($t4)      # $s6 = platform_arr[i]

            # 4. add the column index to the position in the display to get to the current block
            add $s6, $s6, $t5   # $s6 = platform_arr[i] + row in display, i.e the leftmost block of this platform. This is the curent block.

            DRAW_CURRENT_PLATFORM:
                # while i < platform_width, draw this platform
                beq $t2, $t3, NEXT_PLATFORM
                addi $s6, $s6, 4    # current block to colour
                sw $t7, 0($s6)      # draw the block the chosen colour

                # increment the block and go to the loop condition
                addi $t2, $t2, 4
                j DRAW_CURRENT_PLATFORM

            NEXT_PLATFORM:
                # increment our index by 4
                addi $s2, $s2, 4
                j GET_PLATFORM

            COMPLETE_PLATFORM:
                jr $ra

    # the character has hit max height and so we have to move the platforms down.
    UPDATE_PLATFORMS:
        add $s3, $zero, $zero   # $s3 will be our loop counter, we loop 10x

        MOVE_PLATFORMS:
            li $v0 32           # sleep for 100 ms
            addi $a0, $zero, 150
            syscall
            addi $t0, $zero, 10
            beq $s3, $t0, COMPLETE_PLATFORM_UPDATE

            addi $s3, $s3, 1    # increment $s3 here since we're already passed the branch operation

            # 1. Erase the current platforms.
            # put the platform colour on the stack before drawing.
            lw $t0, background
            addi $sp, $sp, -4
            sw $t0, 0($sp)

            jal FUNCTION_DRAW_PLATFORM_LOOP

            # 2. Calculate the new positions
            add $t0, $zero, $zero
            la $t8, row_arr
            la $t9, platform_arr
            # The algorithm works as follows.
            # First, we increase each platform's row by 1.
            # for i in range(len(arr)):
            #   arr[i] = arr[i] + 1
            # if arr[0] == 32:      # if our bottom row is off the screen
            #   arr[0] = arr[1]
            #   arr[1] = arr[2]
            #   arr[2] = 2          # i.e the top platform goes to the 3rd row from the top.
            CALCULATE_NEW_PLATFORM_ROWS:
                lw $t1, num_platforms
                # while i < # platforms
                beq $t0, $t1, CHECK_PLATFORM_OVERFLOW

                add $t2, $zero, 4
                mult $t0, $t2
                mflo $t2            # current offset

                add $t3, $t8, $t2   # $t4 = addr(row_arr[i])

                lw $t4, 0($t3)      # $t5 = row_arr[i]
                addi $t4, $t4, 128  # $t5 += 1 row
                sw $t4, 0($t3)      # row_arr[i] += 1 row

                # increment and jump to loop condition
                addi $t0, $t0, 1
                j CALCULATE_NEW_PLATFORM_ROWS

            # We want to see if the bottom platform has fallen off the map
            CHECK_PLATFORM_OVERFLOW:
                # Check if row_arr[0] == 4096 == 32 (row) * 128
                lw $t0, 0($t8)          # 0($t8) = row_arr[0]
                addi $t2, $zero, 4096
                # if row_arr[0] != 4096, draw the new platforms
                bne $t0, $t2, DRAW_NEW_PLATFORMS

                # row_arr[0] == 4096 so we have to move our values around
                lw $t0, 4($t8)      # $t0 = row_arr[1]
                lw $t1, 8($t8)      # $t1 = row_arr[2]
                sw $t0, 0($t8)      # row_arr[0] = row_arr[1]
                sw $t1, 4($t8)      # row_arr[1] = row_arr[2]

                # Note this next instruction.
                # When the new platform comes in from the top, it will go to the 3rd row
                # to maintain a distance of 10 rows from the middle platform.
                addi $t0, $zero, 256
                sw $t0, 8($t8)      # row_arr[2] = 256, aka the 3rd row (256 = 2 * 128).

                # Now we need to move the values in the platform array.
                lw $t0, 4($t9)      # $t0 = platform_arr[1]
                lw $t1, 8($t9)      # $t1 = platform_arr[2]
                sw $t0, 0($t9)      # platform_arr[0] = platform_arr[1]
                sw $t1, 4($t9)      # platform_arr[1] = platform_arr[2]

                # TODO: MILESTONE 2 we need to generate a random column position here.
                # For now, just set it to the middle.
                addi $t0, $zero, 48 # 48 = 12*4 = 12th column.
                sw $t0, 8($t9)      # platform_arr[2] = 48
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

Exit:
    li $v0, 10 		# terminate the program gracefully
    syscall

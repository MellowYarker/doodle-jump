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
    displayAddress:     .word 0x10008000
    background:         .word 0xffffff      # Background colour of the display
    platform_colour:    .word 0x00ff00
    platform_width:     .word 8             # platform width
    num_platforms:      .word 3
    # Array of 3 platforms.
    #   - in both platform_arr and row_arr, the first entry is the bottom platform.
    # Note that we will have to add the "column index", i.e x*4 to whatever the row is
    # so it will be trivial to get it on the display. Just set the row to the 0th col of some
    # row in the display.
    platform_arr:   .word 0:3               # We store the leftmost block's "column" x where x in [0, 31 - platform_width].
    row_arr:      .word 3968,2688,1408    # Store the row_indexes of each platform. Add these to displayAddress.

.text
    MAIN:
        # setup
        lw $s0, displayAddress 	# $s0 stores the base address for display
        add $s1, $zero, $s0     # $s1 stores the location of the current block

        # ~~platforms~~
        add $s5, $zero, $zero   # 0 => draw platforms, 1 => do not draw platforms
        j DRAW_BACKGROUND

    DRAW_BACKGROUND:
        # first, we want to make sure we're not at the last block
        addi $t2, $s0, 4096 # based address + 4096
        # If testing, uncomment this to avoid painting the white screen.
        # add $s1, $zero, $t2
        # if we've drawn the background, start drawing the map
        beq $s1, $t2, DRAW_MAP

        # otherwise, make the block white and increment!
        lw $t0, background  # Store the background colour in $t0
        sw $t0, 0($s1)      # $s1 points to a location in memory, we are accessing the memory
        addi $s1, $s1, 4    # here, we are modifying the value of the address stored at $s1

        # go to the top of the loop.
        j DRAW_BACKGROUND

    DRAW_MAP:
        lw $s0, displayAddress
        add $s1, $zero, $s0 # current block
        # We always have 3 platforms visible.
        add $t2 $zero, $zero

        # if $s5 is 0, draw the platforms, otherwise skip
        beq $s5, $t2, SET_PLATFORMS
        # do stuff like draw the character.

        # after everything has finished
        add $s5, $zero, $zero     # set $s5 to 0, so the next time we enter DRAW_MAP we will draw the platforms
        j DRAW_MAP

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

        # 2. actually draw each platform
        # Throughout DRAW_PLATFORM_LOOP, $s2 will be the offset for the arrays.
        add $s2, $zero, $zero
        j DRAW_PLATFORM_LOOP

    DRAW_PLATFORM_LOOP:
        # In DRAW_PLATFORM_LOOP, we get each platform from platform_arr and draw it.

        la $t8, row_arr         # our array of row indexes
        la $t9, platform_arr    # our array of platform origins
        lw $t1, num_platforms   # loop condition
        addi $t2, $zero, 4
        mult $t1, $t2
        mflo $t1                # $t1 = num_platforms * 4

        # While i < num_platforms * 4, required because the next element is at arr[i + 4]
        beq $s2, $t1, COMPLETE_PLATFORM

        # Draw the current platform from our array.
        add $t2, $zero, $zero   # current block being drawn.
        lw $s0, displayAddress  # base address
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

        # 5. colour the block
        lw $t7, platform_colour

        DRAW_CURRENT_PLATFORM:
            # while i < platform_width, draw this platform
            beq $t2, $t3, NEXT_PLATFORM
            addi $s6, $s6, 4   # current block to colour
            sw $t7, 0($s6)      # make current block green

            # increment the block and go to the loop condition
            addi $t2, $t2, 4
            j DRAW_CURRENT_PLATFORM

        NEXT_PLATFORM:
            # increment our index by 4
            addi $s2, $s2, 4
            j DRAW_PLATFORM_LOOP


    COMPLETE_PLATFORM:
        # set $s5 to 1 to indicate we should not draw the platforms until later.
        addi $s5, $zero, 1
        
        # go back to DRAW_MAP, since we have finished drawing the platforms.
        j DRAW_MAP

Exit:
    li $v0, 10 		# terminate the program gracefully
    syscall

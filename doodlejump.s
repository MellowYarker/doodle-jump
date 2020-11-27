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
    displayAddress:	.word 0x10008000
.text
    # setup
    lw $s0, displayAddress 	# $s0 stores the base address for display
    add $s1, $zero, $s0     # $s1 stores the location of the current block
    li $t0, 0xffffff        # $t0 stores the white colour code, this is the background colour
    li $t1, 0x00ff00        # $t1 stores the green colour code, this is the platform colour
    addi $s7, $zero, 8      # $s7 stores the default size (number of blocks) of the platforms.

    # ~~platforms~~
    # $s2 stores the leftmost block index of the lowest platform
    # $s3 stores the leftmost block index of the centre platform
    # $s4 stores the leftmost block index of the top    platform
    
    add $s2, $zero, $s0     # set it to be the base address for now
    add $s3, $zero, $s0     # set it to be the base address for now
    add $s4, $zero, $s0     # set it to be the base address for now
    add $s5, $zero, $zero   # 0 => draw platforms, 1 => do not draw platforms

    START:
        # first, we want to make sure we're not at the last block
        addi $t2, $s0, 4096 # based address + 4096
        # If testing, uncomment this to avoid painting the white screen.
        # add $s1, $zero, $t2
        # if we've drawn the background, start drawing the map
        beq $s1, $t2, DRAW_MAP

        # otherwise, make the block white and increment!
        sw $t0, 0($s1)      # $s1 points to a location in memory, we are accessing the memory
        addi $s1, $s1, 4    # here, we are modifying the value of the address stored at $s1

        # go to the top of the loop.
        j START

    DRAW_MAP:
        # We always have 3 platforms visible.
        add $t2 $zero, $zero

        # if $s5 is 0, draw the platforms, otherwise skip
        beq $s5, $t2, SET_PLATFORMS
        # do stuff like draw the character.


        # after everything has finished
        add $s5, $zero, $zero     # set $s5 to 0, so the next time we enter DRAW_MAP we will draw the platforms
        j Exit

    SET_PLATFORMS:
        # add $t2, $zero, $zero # seems unnecessary
        # 1. set the left bound of each platform
        #       TODO: will need bounds checking later.
        # platform width = 8 blocks
        # left most is column 12 (default for testing)

        # want column index 12*4 = 48, rows 18, 12, and 6
        #   $s2 => (48 + 128*18), 128*18 = 18th row
        addi $t2, $zero, 48
        addi $t4, $zero, 128
        addi $t3, $zero, 18
        mult $t3, $t4       # 128 * 18
        mflo $t3            # store mult in $t3
        add $t2, $t2, $t3   # 48 + 128*18
        add $s2, $s2, $t2
        add $t2, $zero, $zero

        #   $s3 => (48+ 128*12), 128*12 = 12th row
        addi $t2, $zero, 48
        addi $t3, $zero, 12
        mult $t3, $t4       # 128 * 12
        mflo $t3            # store mult in $t3
        add $t2, $t2, $t3   # 48 + 128*12
        add $s3, $s3, $t2
        add $t2, $zero, $zero

        #   $s4 => (48 + 128*6), 128 * 6 = 6th row
        addi $t2, $zero, 48
        addi $t3, $zero, 6
        mult $t3, $t4       # 128*6
        mflo $t3            # store mult in $t3
        add $t2, $t2, $t3   # 48 + 128*6
        add $s4, $s4, $t2
        add $t2, $zero, $zero

        # 2. actually draw each platform
        j DRAW_PLATFORM_LOOP

    DRAW_PLATFORM_LOOP:
        # in this loop, we will draw the platforms and then finish up.
        # each left most index is assumed to be correct at this point, we simply need to draw them now
        beq $t2, $s7, COMPLETE_PLATFORM
        # colour each current platform block
        sw $t1, 0($s2)
        sw $t1, 0($s3)
        sw $t1, 0($s4)

        # increment each current platform block
        addi $s2, $s2, 4
        addi $s3, $s3, 4
        addi $s4, $s4, 4

        # increment $t2
        addi $t2, $t2, 1

        # jump to the top of the loop
        j DRAW_PLATFORM_LOOP

    COMPLETE_PLATFORM:
        # First, reset $s2, #s3, and $s4 to their leftmost block positions
        # Recall that $s7 is the DEFAULT PLATFORM SIZE
        # TODO: if we have variable sized platforms, should probably handle that here.
        sub $s2, $s2, $s7
        sub $s3, $s3, $s7
        sub $s4, $s4, $s7
        # set $s5 to 1, i.e do not draw platforms when we enter DRAW_MAP, as we have already done it.
        addi $s5, $zero, 1
        
        # go back to DRAW_MAP, since we have finished drawing the platforms.
        j DRAW_MAP

Exit:
    li $v0, 10 		# terminate the program gracefully
    syscall

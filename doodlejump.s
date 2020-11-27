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

    # ~~platforms~~
    # $s2 stores the leftmost block index of the lowest platform
    # $s3 stores the leftmost block index of the centre platform
    # $s4 stores the leftmost block index of the top    platform
    
    add $s2, $zero, $s0     # set it to be the base address for now
    add $s3, $zero, $s0     # set it to be the base address for now
    add $s4, $zero, $s0     # set it to be the base address for now
    add $s4, $zero, $zero   # 0 => draw platforms, 1 => do not draw platforms

    START:
        # first, we want to make sure we're not at the last block
        addi $t1, $s0, 4096 # based address + 4096

        # if we've drawn the background, start drawing the map
        beq $s1, $t1, DRAW_MAP

        # otherwise, make the block white and increment!
        sw $t0, 0($s1)      # $s1 points to a location in memory, we are accessing the memory
        addi $s1, $s1, 4    # here, we are modifying the value of the address stored at $s1

        # go to the top of the loop.
        j START

    DRAW_MAP:
        # We always have 3 platforms visible.
        add $t2, $zero, $zero

        # if $s5 is 0, draw the platforms, otherwise skip
        beq $s5, $t2, DRAW_PLATFORMS
        # do stuff like draw the character.


        # after everything has finished
        # after everything has finished
        addi $s5, $zero, -1     # set $s5 to 0, so the next time we enter DRAW_MAP we will draw the platforms
        j Exit

    DRAW_PLATFORMS:
        # do stuff
        # platform width = 8 blocks
        # left most is column 13 (default for testing)
        addi $s2, $s2, 13
        # set $s5 to 1, i.e do not draw platforms, as we have already done it.
        addi $s5, $zero, 1

        
Exit:
    li $v0, 10 		# terminate the program gracefully
    syscall

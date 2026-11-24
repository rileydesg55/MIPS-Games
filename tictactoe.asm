# BITMAP SETUP (do this before running):
#   Tools > Bitmap Display, then set
#     Unit Width = 8, Unit Height = 8
#     Display Width = 256, Display Height = 256
#     Base address = 0x10008000 ($gp)
#   Click "Connect to MARS", then assemble and run.
# The display is a 32x32 grid of units. The board uses 26x26 of them:
# three 8x8 cells with 1-unit grid lines between them.
 
.eqv DISPLAY_BASE 0x10008000
 
.data
board:      .byte 0,0,0,0,0,0,0,0,0
# the 8 winning lines (3 cell indexes each)
lines:      .byte 0,1,2, 3,4,5, 6,7,8, 0,3,6, 1,4,7, 2,5,8, 0,4,8, 2,4,6
inputBuf:   .space 32
 
# 8x8 sprites: one byte per row, bit 7 = leftmost pixel, 1 = lit
spriteX:    .byte 0xC3,0x66,0x3C,0x18,0x18,0x3C,0x66,0xC3
spriteO:    .byte 0x3C,0x7E,0xC3,0xC3,0xC3,0xC3,0x7E,0x3C
 
welcome:    .asciiz "Tic-Tac-Toe\nYou are X, computer is O. You go first.\nOpen Tools > Bitmap Display (unit 8x8, display 256x256, base 0x10008000) and click Connect.\n"
movePrompt: .asciiz "\nYour move (1-9): "
badMsg:     .asciiz "Please enter a number from 1 to 9.\n"
takenMsg:   .asciiz "That square is taken.\n"
compMsg:    .asciiz "\nComputer plays "
winMsg:     .asciiz "\nYou win!\n"
loseMsg:    .asciiz "\nComputer wins!\n"
drawMsg:    .asciiz "\nIt's a draw.\n"
againMsg:   .asciiz "\nPlay again? 1 = yes, 2 = no: "
wLabel:     .asciiz "\nWins: "
lLabel:     .asciiz "  Losses: "
dLabel:     .asciiz "  Draws: "
divider:    .asciiz "---+---+---\n"
newline:    .asciiz "\n"
 
.text
.globl main
 
# $s0 = wins, $s1 = losses, $s2 = draws (all helper functions that use
# $s registers save and restore them, so these survive)
main:
    # seed the RNG with the system time
    li  $v0, 30
    syscall
    move $a1, $a0
    li  $a0, 0
    li  $v0, 40
    syscall
 
    li  $s0, 0
    li  $s1, 0
    li  $s2, 0
 
    li  $v0, 4
    la  $a0, welcome
    syscall
 
newGame:
    # clear the board
    la  $t0, board
    li  $t1, 0
clearLoop:
    beq $t1, 9, clearDone
    sb  $zero, 0($t0)
    addi $t0, $t0, 1
    addi $t1, $t1, 1
    j   clearLoop
clearDone:
    jal initDisplay
    jal printBoard
    jal drawBoard
 
gameLoop:
    jal playerMove
    jal printBoard
    jal drawBoard
    li  $a0, 1
    jal checkWin
    bnez $v0, playerWon
    jal boardFull
    bnez $v0, gameDraw
 
    jal computerMove
    jal printBoard
    jal drawBoard
    li  $a0, 2
    jal checkWin
    bnez $v0, computerWon
    # X moves on turns 1,3,5,7,9 so the board can only fill after X's move
    j   gameLoop
 
playerWon:
    li  $v0, 4
    la  $a0, winMsg
    syscall
    addi $s0, $s0, 1
    j   roundOver
 
computerWon:
    li  $v0, 4
    la  $a0, loseMsg
    syscall
    addi $s1, $s1, 1
    j   roundOver
 
gameDraw:
    li  $v0, 4
    la  $a0, drawMsg
    syscall
    addi $s2, $s2, 1
 
roundOver:
    jal printScore
askAgain:
    li  $v0, 4
    la  $a0, againMsg
    syscall
    jal readInt
    beqz $v1, askAgain
    beq $v0, 1, newGame
    beq $v0, 2, quit
    j   askAgain
 
quit:
    li  $v0, 10
    syscall
 
# ------------------------------------------------------------
# printBoard: draws the board; empty squares show their number
# ------------------------------------------------------------
printBoard:
    li  $v0, 4
    la  $a0, newline
    syscall
    li  $t0, 0                  # cell index
pb_loop:
    beq $t0, 9, pb_end
    li  $v0, 11                 # leading space
    li  $a0, 32
    syscall
 
    la  $t1, board
    add $t1, $t1, $t0
    lb  $t2, 0($t1)
    beq $t2, 1, pb_x
    beq $t2, 2, pb_o
    addi $a0, $t0, 49           # '1' + index
    j   pb_print
pb_x:
    li  $a0, 88                 # 'X'
    j   pb_print
pb_o:
    li  $a0, 79                 # 'O'
pb_print:
    li  $v0, 11
    syscall
 
    rem $t3, $t0, 3
    beq $t3, 2, pb_endRow
    li  $v0, 11                 # column separator " |"
    li  $a0, 32
    syscall
    li  $a0, 124
    syscall
    j   pb_next
pb_endRow:
    li  $v0, 4
    la  $a0, newline
    syscall
    beq $t0, 8, pb_next         # no divider after the last row
    la  $a0, divider
    syscall
pb_next:
    addi $t0, $t0, 1
    j   pb_loop
pb_end:
    jr  $ra
 
# ------------------------------------------------------------
# checkWin: $a0 = player (1 or 2). Returns $v0 = 1 if they have 3 in a row
# ------------------------------------------------------------
checkWin:
    la  $t0, lines
    la  $t5, board
    li  $t1, 0
cw_loop:
    beq $t1, 8, cw_no
    lb  $t2, 0($t0)
    add $t3, $t5, $t2
    lb  $t3, 0($t3)
    bne $t3, $a0, cw_next
    lb  $t2, 1($t0)
    add $t3, $t5, $t2
    lb  $t3, 0($t3)
    bne $t3, $a0, cw_next
    lb  $t2, 2($t0)
    add $t3, $t5, $t2
    lb  $t3, 0($t3)
    bne $t3, $a0, cw_next
    li  $v0, 1
    jr  $ra
cw_next:
    addi $t0, $t0, 3
    addi $t1, $t1, 1
    j   cw_loop
cw_no:
    li  $v0, 0
    jr  $ra
 
# ------------------------------------------------------------
# boardFull: returns $v0 = 1 if no empty squares remain
# ------------------------------------------------------------
boardFull:
    la  $t0, board
    li  $t1, 0
bf_loop:
    beq $t1, 9, bf_yes
    lb  $t2, 0($t0)
    beqz $t2, bf_no
    addi $t0, $t0, 1
    addi $t1, $t1, 1
    j   bf_loop
bf_yes:
    li  $v0, 1
    jr  $ra
bf_no:
    li  $v0, 0
    jr  $ra
 
# ------------------------------------------------------------
# findWin: $a0 = player. Returns $v0 = index of a square that would
# give that player three in a row, or -1 if none.
# ------------------------------------------------------------
findWin:
    addi $sp, $sp, -16
    sw  $ra, 0($sp)
    sw  $s0, 4($sp)
    sw  $s1, 8($sp)
    sw  $s2, 12($sp)
 
    move $s0, $a0               # player
    li  $s1, 0                  # index
fw_loop:
    beq $s1, 9, fw_none
    la  $t0, board
    add $s2, $t0, $s1           # address of cell
    lb  $t1, 0($s2)
    bnez $t1, fw_next           # occupied
    sb  $s0, 0($s2)             # try it
    move $a0, $s0
    jal checkWin
    sb  $zero, 0($s2)           # undo
    bnez $v0, fw_found
fw_next:
    addi $s1, $s1, 1
    j   fw_loop
fw_found:
    move $v0, $s1
    j   fw_ret
fw_none:
    li  $v0, -1
fw_ret:
    lw  $ra, 0($sp)
    lw  $s0, 4($sp)
    lw  $s1, 8($sp)
    lw  $s2, 12($sp)
    addi $sp, $sp, 16
    jr  $ra
 
# ------------------------------------------------------------
# playerMove: asks until the player picks a valid empty square
# ------------------------------------------------------------
playerMove:
    addi $sp, $sp, -4
    sw  $ra, 0($sp)
pm_ask:
    li  $v0, 4
    la  $a0, movePrompt
    syscall
    jal readInt
    beqz $v1, pm_bad
    blt $v0, 1, pm_bad
    bgt $v0, 9, pm_bad
    addi $t0, $v0, -1
    la  $t1, board
    add $t1, $t1, $t0
    lb  $t2, 0($t1)
    bnez $t2, pm_taken
    li  $t3, 1
    sb  $t3, 0($t1)
    lw  $ra, 0($sp)
    addi $sp, $sp, 4
    jr  $ra
pm_bad:
    li  $v0, 4
    la  $a0, badMsg
    syscall
    j   pm_ask
pm_taken:
    li  $v0, 4
    la  $a0, takenMsg
    syscall
    j   pm_ask
 
# ------------------------------------------------------------
# computerMove: picks a random empty square
# ------------------------------------------------------------
computerMove:
    addi $sp, $sp, -4
    sw  $ra, 0($sp)
 
cm_random:
    li  $v0, 42
    li  $a0, 0
    li  $a1, 9
    syscall                     # random 0-8 in $a0
    move $v0, $a0
    la  $t0, board
    add $t1, $t0, $v0
    lb  $t2, 0($t1)
    bnez $t2, cm_random         # occupied, try again
 
cm_place:
    la  $t0, board
    add $t0, $t0, $v0
    li  $t1, 2
    sb  $t1, 0($t0)
    addi $t5, $v0, 1            # 1-based position for display
 
    li  $v0, 4
    la  $a0, compMsg
    syscall
    li  $v0, 1
    move $a0, $t5
    syscall
    li  $v0, 4
    la  $a0, newline
    syscall
 
    lw  $ra, 0($sp)
    addi $sp, $sp, 4
    jr  $ra
 
# ------------------------------------------------------------
# printScore
# ------------------------------------------------------------
printScore:
    li  $v0, 4
    la  $a0, wLabel
    syscall
    li  $v0, 1
    move $a0, $s0
    syscall
    li  $v0, 4
    la  $a0, lLabel
    syscall
    li  $v0, 1
    move $a0, $s1
    syscall
    li  $v0, 4
    la  $a0, dLabel
    syscall
    li  $v0, 1
    move $a0, $s2
    syscall
    li  $v0, 4
    la  $a0, newline
    syscall
    jr  $ra
 
# ------------------------------------------------------------
# readInt: reads a line, validates it. Returns $v0 = value,
# $v1 = 1 if valid, 0 if not. Never crashes on letters.
# ------------------------------------------------------------
readInt:
    li  $v0, 8
    la  $a0, inputBuf
    li  $a1, 10                 # max 9 digits, avoids overflow
    syscall
 
    la  $t0, inputBuf
    li  $t1, 0                  # value
    li  $t2, 0                  # digit count
ri_loop:
    lb  $t3, 0($t0)
    beq $t3, 10, ri_end
    beqz $t3, ri_end
    blt $t3, 48, ri_bad
    bgt $t3, 57, ri_bad
    addi $t3, $t3, -48
    mul $t1, $t1, 10
    add $t1, $t1, $t3
    addi $t2, $t2, 1
    addi $t0, $t0, 1
    j   ri_loop
ri_end:
    beqz $t2, ri_bad
    move $v0, $t1
    li  $v1, 1
    jr  $ra
ri_bad:
    li  $v0, 0
    li  $v1, 0
    jr  $ra
 
# ============================================================
# BITMAP DISPLAY ROUTINES
# Pixel address = DISPLAY_BASE + (y * 32 + x) * 4   (32 units per row)
# ============================================================
 
# ------------------------------------------------------------
# initDisplay: clears the screen to black and draws the grid lines
# ------------------------------------------------------------
initDisplay:
    li  $t0, DISPLAY_BASE
    li  $t1, 0
id_clear:
    beq $t1, 1024, id_grid      # 32 * 32 units
    sw  $zero, 0($t0)
    addi $t0, $t0, 4
    addi $t1, $t1, 1
    j   id_clear
 
id_grid:
    li  $t4, DISPLAY_BASE
    li  $t9, 0x00FFFFFF         # white grid lines
    li  $t0, 0                  # i = 0..25
id_loop:
    beq $t0, 26, id_done
    sll $t1, $t0, 5             # i * 32
 
    addi $t2, $t1, 8            # vertical line x = 8, y = i
    sll $t2, $t2, 2
    add $t2, $t2, $t4
    sw  $t9, 0($t2)
 
    addi $t2, $t1, 17           # vertical line x = 17, y = i
    sll $t2, $t2, 2
    add $t2, $t2, $t4
    sw  $t9, 0($t2)
 
    addi $t2, $t0, 256          # horizontal line y = 8 (8*32), x = i
    sll $t2, $t2, 2
    add $t2, $t2, $t4
    sw  $t9, 0($t2)
 
    addi $t2, $t0, 544          # horizontal line y = 17 (17*32), x = i
    sll $t2, $t2, 2
    add $t2, $t2, $t4
    sw  $t9, 0($t2)
 
    addi $t0, $t0, 1
    j   id_loop
id_done:
    jr  $ra
 
# ------------------------------------------------------------
# drawSprite: draws an 8x8 sprite (reusable in any game)
#   $a0 = x, $a1 = y (in display units), $a2 = sprite address,
#   $a3 = color (0x00RRGGBB). Unlit pixels are drawn black.
# ------------------------------------------------------------
drawSprite:
    li  $t0, 0                  # row
ds_row:
    beq $t0, 8, ds_done
    add $t1, $a2, $t0
    lbu $t2, 0($t1)             # this row's 8 bits
    add $t3, $a1, $t0           # y + row
    sll $t3, $t3, 5             # * 32
    add $t3, $t3, $a0           # + x
    sll $t3, $t3, 2             # * 4 bytes
    li  $t4, DISPLAY_BASE
    add $t3, $t3, $t4           # address of leftmost pixel in this row
    li  $t5, 0                  # column
ds_col:
    beq $t5, 8, ds_next
    li  $t6, 7
    sub $t6, $t6, $t5           # shift = 7 - column
    srlv $t7, $t2, $t6
    andi $t7, $t7, 1
    beqz $t7, ds_off
    sw  $a3, 0($t3)
    j   ds_adv
ds_off:
    sw  $zero, 0($t3)
ds_adv:
    addi $t3, $t3, 4
    addi $t5, $t5, 1
    j   ds_col
ds_next:
    addi $t0, $t0, 1
    j   ds_row
ds_done:
    jr  $ra
 
# ------------------------------------------------------------
# drawCell: $a0 = cell index 0-8, $a1 = player (1 = X, 2 = O)
# Cell (row, col) has its top-left corner at x = col*9, y = row*9
# ------------------------------------------------------------
drawCell:
    addi $sp, $sp, -4
    sw  $ra, 0($sp)
 
    li  $t0, 3
    div $a0, $t0
    mflo $t1                    # row
    mfhi $t2                    # col
    mul $t3, $t2, 9             # x
    mul $t4, $t1, 9             # y
    move $t5, $a1
    move $a0, $t3
    move $a1, $t4
    beq $t5, 1, dc_x
    la  $a2, spriteO
    li  $a3, 0x004080FF         # blue O
    j   dc_draw
dc_x:
    la  $a2, spriteX
    li  $a3, 0x00FF4040         # red X
dc_draw:
    jal drawSprite
 
    lw  $ra, 0($sp)
    addi $sp, $sp, 4
    jr  $ra
 
# ------------------------------------------------------------
# drawBoard: draws an X or O sprite for every occupied cell
# ------------------------------------------------------------
drawBoard:
    addi $sp, $sp, -12
    sw  $ra, 0($sp)
    sw  $s0, 4($sp)
    sw  $s1, 8($sp)
 
    li  $s0, 0
db_loop:
    beq $s0, 9, db_done
    la  $t0, board
    add $t0, $t0, $s0
    lb  $s1, 0($t0)
    beqz $s1, db_next
    move $a0, $s0
    move $a1, $s1
    jal drawCell
db_next:
    addi $s0, $s0, 1
    j   db_loop
db_done:
    lw  $ra, 0($sp)
    lw  $s0, 4($sp)
    lw  $s1, 8($sp)
    addi $sp, $sp, 12
    jr  $ra
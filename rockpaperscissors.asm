# Rock Paper Scissors with Bitmap Display
#
# BITMAP SETUP (Tools > Bitmap Display):
#   Unit Width = 8, Unit Height = 8
#   Display Width = 256, Display Height = 256
#   Base address = 0x10008000 ($gp)
#   Click "Connect to MARS" before running.
#
# Left sprite = your choice, right sprite = enemy's choice.
# Background: green = win, red = loss, yellow = tie.
 
.eqv DISPLAY_BASE 0x10008000
 
.data
	initialPrompt: .asciiz "Rock -> Paper -> Scissors ->\nPick One: 1 rock, 2 paper, 3 scissors )\n"
	rock: .asciiz "rock"
	paper: .asciiz "paper"
	scissors: .asciiz "scissors"
	cpuPick: .asciiz "Enemy picks: "
	newLine: .asciiz "\n"
	tieMess: .asciiz "You tied, try again\n"
	loseMess: .asciiz "You lost, try again\n"
	winMess: .asciiz "You win! Play again\n"
	recordW: .asciiz "\nWin: "
	recordL: .asciiz " Loss: "
 
	# 8x8 sprites, one byte per row, bit 7 = leftmost pixel, 1 = lit.
	# Stored back to back so sprite address = sprites + (choice - 1) * 8
	sprites:
	.byte 0x3C,0x7E,0xFF,0xFB,0xFF,0xDF,0x7E,0x3C   # rock
	.byte 0xFE,0x82,0xBA,0x82,0xBA,0x82,0xBA,0xFE   # paper
	.byte 0x81,0x42,0x24,0x18,0x24,0x66,0x99,0x66   # scissors
.text
 
main:
 
# seed the RNG with the system time
li $v0, 30
syscall
move $a1, $a0
li $a0, 0
li $v0, 40
syscall
 
#win record
li $s3, 0
#loss record
li $s4, 0
 
startGame:
li $v0, 4
la $a0, initialPrompt
syscall
# user hand
li $s0, 0
#computer hand
li $s1, 0
 
#get user's choice
li $v0, 5
syscall
move $s0, $v0
 
# reject anything that isn't 1-3 (otherwise it would be treated as rock)
blt $s0, 1, startGame
bgt $s0, 3, startGame
 
#get cpu choice
li $v0, 42
li $a0, 0
li $a1, 3
syscall
move $s1, $a0
addi $s1, $s1, 1
 
li $v0, 4
la $a0, cpuPick
syscall
jal printChoice
 
# li $v0, 1
# move $a0, $s0
# syscall
 
determineWinner:
 
beq $s0, 1, checkRock
beq $s0, 2, checkPaper
beq $s0, 3, checkScissors
 
checkRock:
beq $s1, 1, tie
beq $s1, 2, lose
beq $s1, 3, win
 
checkPaper:
beq $s1, 1, win
beq $s1, 2, tie
beq $s1, 3, lose
 
checkScissors:
beq $s1, 1, lose
beq $s1, 2, win
beq $s1, 3, tie
 
tie:
li $a0, 0x00F0D020        # yellow
jal drawScene
li $v0, 4
la $a0, tieMess
syscall
jal printRecord
j startGame
 
lose:
addi $s4, $s4, 1
li $a0, 0x00D03030        # red
jal drawScene
li $v0, 4
la $a0, loseMess
syscall
jal printRecord
j startGame
 
win:
addi $s3, $s3, 1
li $a0, 0x0000B050        # green
jal drawScene
li $v0, 4
la $a0, winMess
syscall
jal printRecord
j startGame
 
 
printChoice:
beq $s1, 1, printRock
beq $s1, 2, printPaper
beq $s1, 3, printScissors
printRock:
li $v0, 4
la $a0, rock
syscall
la $a0, newLine
syscall
jr $ra
printPaper:
li $v0, 4
la $a0, paper
syscall
la $a0, newLine
syscall
jr $ra
printScissors:
li $v0, 4
la $a0, scissors
syscall
la $a0, newLine
syscall
jr $ra
 
printRecord:
li $v0, 4
la $a0, recordW
syscall
li $v0, 1
move $a0, $s3
syscall
li $v0, 4
la $a0, recordL
syscall
li $v0, 1
move $a0, $s4
syscall
li $v0, 4
la $a0, newLine
syscall
jr $ra
 
# ============================================================
# BITMAP DISPLAY ROUTINES
# Pixel address = DISPLAY_BASE + (y * 32 + x) * 4   (32 units per row)
# ============================================================
 
# ------------------------------------------------------------
# drawScene: $a0 = background color.
# Fills the screen, then draws your sprite (left, from $s0)
# and the enemy's sprite (right, from $s1) in black.
# ------------------------------------------------------------
drawScene:
addi $sp, $sp, -4
sw $ra, 0($sp)
 
jal fillScreen               # $a0 still holds the color
 
# your choice: left side
li $a0, 4
li $a1, 12
addi $t0, $s0, -1
sll $t0, $t0, 3              # (choice - 1) * 8
la $a2, sprites
add $a2, $a2, $t0
li $a3, 0x00000000
jal drawSprite
 
# enemy choice: right side
li $a0, 20
li $a1, 12
addi $t0, $s1, -1
sll $t0, $t0, 3
la $a2, sprites
add $a2, $a2, $t0
li $a3, 0x00000000
jal drawSprite
 
lw $ra, 0($sp)
addi $sp, $sp, 4
jr $ra
 
# ------------------------------------------------------------
# fillScreen: $a0 = color. Paints all 32 x 32 units.
# ------------------------------------------------------------
fillScreen:
li $t0, DISPLAY_BASE
li $t1, 0
fs_loop:
beq $t1, 1024, fs_done
sw $a0, 0($t0)
addi $t0, $t0, 4
addi $t1, $t1, 1
j fs_loop
fs_done:
jr $ra
 
# ------------------------------------------------------------
# drawSprite: draws an 8x8 sprite (only lit pixels, so the
# background shows through the rest).
#   $a0 = x, $a1 = y (display units), $a2 = sprite address,
#   $a3 = color
# ------------------------------------------------------------
drawSprite:
li $t0, 0                    # row
ds_row:
beq $t0, 8, ds_done
add $t1, $a2, $t0
lbu $t2, 0($t1)              # this row's 8 bits
add $t3, $a1, $t0            # y + row
sll $t3, $t3, 5              # * 32
add $t3, $t3, $a0            # + x
sll $t3, $t3, 2              # * 4 bytes
li $t4, DISPLAY_BASE
add $t3, $t3, $t4            # address of leftmost pixel in this row
li $t5, 0                    # column
ds_col:
beq $t5, 8, ds_next
li $t6, 7
sub $t6, $t6, $t5            # shift = 7 - column
srlv $t7, $t2, $t6
andi $t7, $t7, 1
beqz $t7, ds_skip
sw $a3, 0($t3)
ds_skip:
addi $t3, $t3, 4
addi $t5, $t5, 1
j ds_col
ds_next:
addi $t0, $t0, 1
j ds_row
ds_done:
jr $ra
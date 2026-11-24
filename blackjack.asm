# Blackjack with Bitmap Display
#
# BITMAP SETUP (Tools > Bitmap Display):
#   Unit Width = 8, Unit Height = 8
#   Display Width = 256, Display Height = 256
#   Base address = 0x10008000 ($gp)
#   Click "Connect to MARS" before running.
#
# After each hand the screen shows WIN, LOSE or PUSH (black text on white).
# $t8 holds the result: 0 = push, 1 = win, 2 = lose.
 
.eqv DISPLAY_BASE 0x10008000
 
.data
	initialPrompt:   .asciiz "Blackjack\nDealer stands on soft 17\n"
	numInputInstruct:.asciiz "\nHow much do you want to wager?\n"
	bank:            .asciiz "\nBank: "
	youDrew:         .asciiz "You drew a "
	dealerShows:     .asciiz "Dealer shows a "
	yourTotal:       .asciiz "Your total: "
	dealerTotal:     .asciiz "Dealer total: "
	hitPrompt:       .asciiz "1 = hit, 2 = stand\n"
	userBust:        .asciiz "Bust! Dealer wins\n"
	dealerBustMsg:   .asciiz "Dealer busts! You win\n"
	winMsg:          .asciiz "You win!\n"
	loseMsg:         .asciiz "Dealer wins\n"
	pushMsg:         .asciiz "Push\n"
	gameOverMsg:     .asciiz "\nOut of money. Game over.\n"
	newline:         .asciiz "\n"
 
	# Word images: 5 rows each, one byte per pixel (1 = black), row by row.
	# Widths: WIN = 14, LOSE = 15, PUSH = 15
	winImg:
	.byte 1,0,0,0,1,0,1,1,1,0,1,0,0,1
	.byte 1,0,0,0,1,0,0,1,0,0,1,1,0,1
	.byte 1,0,1,0,1,0,0,1,0,0,1,0,1,1
	.byte 1,0,1,0,1,0,0,1,0,0,1,0,0,1
	.byte 0,1,0,1,0,0,1,1,1,0,1,0,0,1
 
	loseImg:
	.byte 1,0,0,0,1,1,1,0,1,1,1,0,1,1,1
	.byte 1,0,0,0,1,0,1,0,1,0,0,0,1,0,0
	.byte 1,0,0,0,1,0,1,0,1,1,1,0,1,1,1
	.byte 1,0,0,0,1,0,1,0,0,0,1,0,1,0,0
	.byte 1,1,1,0,1,1,1,0,1,1,1,0,1,1,1
 
	pushImg:
	.byte 1,1,1,0,1,0,1,0,1,1,1,0,1,0,1
	.byte 1,0,1,0,1,0,1,0,1,0,0,0,1,0,1
	.byte 1,1,1,0,1,0,1,0,1,1,1,0,1,1,1
	.byte 1,0,0,0,1,0,1,0,0,0,1,0,1,0,1
	.byte 1,0,0,0,1,1,1,0,1,1,1,0,1,0,1
 
.text
.globl main
main:
    # seed RNG with system time
    li $v0, 30
    syscall
    move $a1, $a0
    li $a0, 0
    li $v0, 40
    syscall
 
    li $s3, 300              # bank
 
    li $v0, 4
    la $a0, initialPrompt
    syscall
 
start:
    li $s0, 0                # reset player total / aces / cards
    li $s1, 0
    li $s2, 0
    li $s4, 0                # reset dealer total / aces / cards
    li $s5, 0
    li $s6, 0
 
    #win val (0 push, 1 win, 2 lose)
    li $t8, 0
 
    blez $s3, gameOver
 
    li $v0, 4
    la $a0, bank
    syscall
    li $v0, 1
    move $a0, $s3
    syscall
    li $v0, 4
    la $a0, newline
    syscall
 
getInput:
    li $v0, 4
    la $a0, numInputInstruct
    syscall
    li $v0, 5
    syscall
    move $s7, $v0            # wager lives in $s7
    blt $s7, 1, getInput
    bgt $s7, $s3, getInput
    sub $s3, $s3, $s7
 
    jal playerDeal
    jal dealerDeal
    la  $a0, dealerShows     # show dealer's first card only
    move $a1, $t3
    jal printNum
    jal playerDeal
    jal dealerDeal           # hole card, not shown
 
playerTurn:
    la  $a0, yourTotal
    move $a1, $s0
    jal printNum
    li $v0, 4
    la $a0, hitPrompt
    syscall
    li $v0, 5
    syscall
    beq $v0, 2, dealerTurn
    bne $v0, 1, playerTurn
 
    jal playerDeal
    bgt $s0, 21, playerBust
    j playerTurn
 
playerBust:
    la  $a0, yourTotal
    move $a1, $s0
    jal printNum
    li $v0, 4
    la $a0, userBust
    syscall
    li $t8, 2
    jal update
    j start
 
dealerTurn:
    bge $s4, 17, dealerDone  # stands on all 17+, including soft 17
    jal dealerDeal
    j dealerTurn
 
dealerDone:
    la  $a0, dealerTotal
    move $a1, $s4
    jal printNum
 
    bgt $s4, 21, dealerBust
    bgt $s0, $s4, playerWins
    blt $s0, $s4, dealerWins
 
    add $s3, $s3, $s7        # push: wager returned
    li $v0, 4
    la $a0, pushMsg
    syscall
    li $t8, 0
    jal update
    j start
 
dealerBust:
    li $v0, 4
    la $a0, dealerBustMsg
    syscall
    li $t8, 1
    jal update
    j payWin
 
playerWins:
    li $v0, 4
    la $a0, winMsg
    syscall
    li $t8, 1
    jal update
payWin:
    sll $t0, $s7, 1          # wager * 2
    add $s3, $s3, $t0
    j start
 
dealerWins:
    li $v0, 4
    la $a0, loseMsg
    syscall
    li $t8, 2
    jal update
    j start
 
gameOver:
    li $v0, 4
    la $a0, gameOverMsg
    syscall
    li $v0, 10
    syscall
 
# ---------- returns card value (1-11) in $v0 ----------
drawCard:
    li $v0, 42
    li $a0, 0
    li $a1, 13
    syscall
    addi $v0, $a0, 1
    li $t0, 1
    beq $v0, $t0, isAce
    ble $v0, 10, drawRet
    li $v0, 10
    j drawRet
isAce:
    li $v0, 11
drawRet:
    jr $ra
 
playerDeal:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)
 
    jal  drawCard
    move $t3, $v0
    add  $s0, $s0, $t3
    addi $s2, $s2, 1
    li   $t0, 11
    bne  $t3, $t0, p_check
    addi $s1, $s1, 1
p_check:
    ble  $s0, 21, p_done
    beqz $s1, p_done
    addi $s0, $s0, -10
    addi $s1, $s1, -1
p_done:
    la   $a0, youDrew
    move $a1, $t3
    jal  printNum
 
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra
 
dealerDeal:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)
 
    jal  drawCard
    move $t3, $v0
    add  $s4, $s4, $t3
    addi $s6, $s6, 1
    li   $t0, 11
    bne  $t3, $t0, d_check
    addi $s5, $s5, 1
d_check:
    ble  $s4, 21, d_done
    beqz $s5, d_done
    addi $s4, $s4, -10
    addi $s5, $s5, -1
d_done:
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra
 
# prints string in $a0, then number in $a1, then newline
printNum:
    move $t4, $a1
    li $v0, 4
    syscall
    li $v0, 1
    move $a0, $t4
    syscall
    li $v0, 4
    la $a0, newline
    syscall
    jr $ra
 
# ============================================================
# BITMAP DISPLAY ROUTINES
# Pixel address = DISPLAY_BASE + (y * 32 + x) * 4   (32 units per row)
# ============================================================
 
# ------------------------------------------------------------
# update: shows WIN / LOSE / PUSH based on $t8 (1 = win, 2 = lose,
# anything else = push). White background, word centered, black text.
# ------------------------------------------------------------
update:
    addi $sp, $sp, -4
    sw   $ra, 0($sp)
 
    li   $a0, 0x00FFFFFF
    jal  fillScreen
 
    beq  $t8, 1, useWin
    beq  $t8, 2, useLose
    la   $a2, pushImg
    li   $a3, 15                 # width of PUSH
    j    placeWord
useWin:
    la   $a2, winImg
    li   $a3, 14                 # width of WIN
    j    placeWord
useLose:
    la   $a2, loseImg
    li   $a3, 15                 # width of LOSE
placeWord:
    li   $t0, 32
    sub  $t0, $t0, $a3
    srl  $a0, $t0, 1             # x = (32 - width) / 2
    li   $a1, 13                 # y = (32 - 5) / 2, rounded
    jal  drawWord
 
    lw   $ra, 0($sp)
    addi $sp, $sp, 4
    jr   $ra
 
# ------------------------------------------------------------
# fillScreen: $a0 = color. Paints all 32 x 32 units.
# ------------------------------------------------------------
fillScreen:
    li   $t0, DISPLAY_BASE
    li   $t1, 0
fs_loop:
    beq  $t1, 1024, fs_done
    sw   $a0, 0($t0)
    addi $t0, $t0, 4
    addi $t1, $t1, 1
    j    fs_loop
fs_done:
    jr   $ra
 
# ------------------------------------------------------------
# drawWord: draws a 5-row image of black pixels.
#   $a0 = x, $a1 = y (display units), $a2 = image address,
#   $a3 = image width. Reads width * 5 bytes in row order.
# ------------------------------------------------------------
drawWord:
    li   $t0, 0                  # row
dw_row:
    beq  $t0, 5, dw_done
    li   $t1, 0                  # column
dw_col:
    beq  $t1, $a3, dw_nextRow
    lbu  $t2, 0($a2)             # next pixel from the table
    addi $a2, $a2, 1
    beqz $t2, dw_skip
    add  $t3, $a1, $t0           # y + row
    sll  $t3, $t3, 5             # * 32
    add  $t4, $a0, $t1           # x + column
    add  $t3, $t3, $t4
    sll  $t3, $t3, 2             # * 4 bytes
    li   $t4, DISPLAY_BASE
    add  $t3, $t3, $t4
    sw   $zero, 0($t3)           # black pixel
dw_skip:
    addi $t1, $t1, 1
    j    dw_col
dw_nextRow:
    addi $t0, $t0, 1
    j    dw_row
dw_done:
    jr   $ra
 
; TITLE: Rush Hour Game - Complete Implementation
; AUTHOR: [Your Name]
; COURSE: Computer Organization & Assembly Language
; DATE: Fall 2025

INCLUDE Irvine32.inc

; Define Windows API Beep if not already defined by Irvine
Beep PROTO :DWORD, :DWORD

; ========================================================================
;                              CONSTANTS
; ========================================================================
BOARD_SIZE      = 20
BOARD_AREA      = BOARD_SIZE * BOARD_SIZE
MAX_PASSENGERS  = 5     ; Requirement: Max 5
MIN_PASSENGERS  = 3     ; Requirement: Min 3
MAX_BONUS_ITEMS = 3     ; Number of bonus items
NPC_COUNT       = 5     ; Reduced for stability
MAX_HIGHSCORES  = 10    ; Top 10 scores
SAVE_SIGNATURE  = 12345678h ; Magic Number for Save Validity

; Game Modes
MODE_CAREER     = 1
MODE_TIME       = 2
MODE_ENDLESS    = 3
CAREER_TARGET   = 200   ; Score needed to win Career mode

; Key Codes
KEY_UP          = 48h
KEY_DOWN        = 50h
KEY_LEFT        = 4Bh
KEY_RIGHT       = 4Dh
KEY_ESC         = 1Bh
KEY_SPACE       = 20h

; ========================================================================
;                              DATA SEGMENT
; ========================================================================
.data
; --- UI Strings ---
strTitle        BYTE "=== RUSH HOUR - ULTIMATE EDITION ===",0
strMenu1        BYTE "1. Start New Game",0
strMenu2        BYTE "2. Continue Game",0 
strMenu3        BYTE "3. Change Difficulty",0 ; NEW Option
strMenu4        BYTE "4. High Scores",0 
strMenu5        BYTE "5. Instructions",0 
strMenu6        BYTE "6. Exit",0         
strScore        BYTE "Score: ",0
strLevel        BYTE "   Level: ",0
strTime         BYTE "   Time: ",0 
strPausedMsg    BYTE "=== PAUSED ===",0  
strSavedMsg     BYTE "GAME SAVED!",0      
strNoSaveMsg    BYTE "Invalid or no save file found.",0
strClearPause   BYTE "              ",0  
strGameOver     BYTE "GAME OVER!",0
strWin          BYTE "Mission passed! You Won!",0 ; Updated Win Message
strFinal        BYTE "Final Score: ",0
strNewHigh      BYTE "NEW HIGH SCORE!",0
strEnterName    BYTE "Enter Name: ",0
strHeader       BYTE "   NAME                 SCORE",0
strSeparator    BYTE "------------------------------",0
strNoScores     BYTE "No high scores yet.",0
strPressKey     BYTE "Press any key to return...",0
strContinueMsg  BYTE "Press any key to continue...",0 ; New string for transition

; --- Instruction Strings ---
strInstrTitle   BYTE "=== HOW TO PLAY ===",0
strInstr1       BYTE "1. Use ARROW KEYS to move your Taxi (T).",0
strInstr2       BYTE "2. Pick up Passengers (P) by moving next to them.",0
strInstr3       BYTE "3. Drop them at the Destination (D) for points.",0
strInstr4       BYTE "4. Collect Bonus Items (B) for extra points.",0
strInstr5       BYTE "5. Avoid Walls (#) and Traffic (C).",0
strInstr6       BYTE "6. Press 'P' to Pause, 'S' to Save.",0
strInstr7       BYTE "7. Career Mode: Reach 200 Points to WIN!",0
strInstr8       BYTE "8. Time Mode: Score high in 60 seconds.",0
strInstr9       BYTE "9. Endless Mode: No time limit, just survive.",0
strInstr10      BYTE "10. Easy Difficulty: Slower Traffic (Beginner friendly).",0
strInstr11      BYTE "11. Medium Difficulty: Normal Traffic Speed.",0
strInstr12      BYTE "12. Hard Difficulty: Fast Traffic (For experts).",0

; --- Game Mode Strings ---
strModeTitle    BYTE "SELECT GAME MODE:",0
strMode1        BYTE "1. Career (Reach 200 Pts)",0
strMode2        BYTE "2. Time Trial (High Score in 60s)",0
strMode3        BYTE "3. Endless (No Time Limit)",0

; --- Difficulty Strings ---
strDiffTitle    BYTE "SELECT DIFFICULTY:",0
strDiff1        BYTE "1. Easy (Slower Traffic)",0
strDiff2        BYTE "2. Medium (Normal)",0
strDiff3        BYTE "3. Hard (Fast Traffic)",0

; --- Taxi Select Strings ---
strTaxiTitle    BYTE "SELECT TAXI COLOR:",0
strTaxi1        BYTE "1. Yellow Taxi (Fast, High Obs Penalty)",0
strTaxi2        BYTE "2. Red Taxi    (Slow, Low Obs Penalty)",0
strTaxi3        BYTE "3. Random",0

; --- File I/O Data ---
filename        BYTE "highscores.txt",0
saveFilename    BYTE "savegame.dat",0     
fileHandle      DWORD INVALID_HANDLE_VALUE
saveSignature   DWORD ?                   

; --- Game Variables ---
playerScore     DWORD 0
passengersDelivered DWORD 0 
level           DWORD 1
gameTime        DWORD 60    
lastTick        DWORD 0     
gameActive      DWORD 0
gamePaused      DWORD 0     
gameSpeed       DWORD 100
playerColor     DWORD 0F6h 
currentMode     DWORD 2     
gameWon         DWORD 0     

; --- Settings ---
difficultySetting DWORD 2   ; 1=Easy, 2=Med, 3=Hard
baseDifficultySpeed DWORD 100

; --- Taxi Statistics ---
taxiBaseSpeed   DWORD 100 
penaltyObstacle DWORD 2
penaltyCar      DWORD 3

; --- Board Data ---
board           BYTE BOARD_AREA DUP(0)  

; --- Player Data ---
playerX         DWORD 1
playerY         DWORD 1
hasPassenger    DWORD 0     
currentPlayerName BYTE 20 DUP(0)

; --- Passenger Arrays ---
passX           DWORD MAX_PASSENGERS DUP(0)
passY           DWORD MAX_PASSENGERS DUP(0)
destX           DWORD MAX_PASSENGERS DUP(0)
destY           DWORD MAX_PASSENGERS DUP(0)
passActive      DWORD MAX_PASSENGERS DUP(0) 

; --- Bonus Item Arrays ---
bonusX          DWORD MAX_BONUS_ITEMS DUP(0)
bonusY          DWORD MAX_BONUS_ITEMS DUP(0)
bonusActive     DWORD MAX_BONUS_ITEMS DUP(0) 

; --- NPC Arrays ---
npcX            DWORD NPC_COUNT DUP(0)
npcY            DWORD NPC_COUNT DUP(0)
npcDir          DWORD NPC_COUNT DUP(0) 
npcTimer        DWORD 0

; --- High Score Arrays ---
highscoreCount  DWORD 0
highscoreValues DWORD MAX_HIGHSCORES DUP(0)
highscoreNames  BYTE  MAX_HIGHSCORES * 20 DUP(0) 

; --- Buffer ---
buffer          BYTE 500 DUP(?) 

; ========================================================================
;                              CODE SEGMENT
; ========================================================================
.code

main PROC
    ; Set text color immediately
    mov eax, 15 + (0 * 16) 
    call SetTextColor
    call Clrscr
    
    call Randomize
    call LoadHighscores 
    
MainMenu:
    mov eax, 15
    call SetTextColor
    call Clrscr
    
    mov dh, 5
    mov dl, 30
    call Gotoxy
    mov edx, OFFSET strTitle
    call WriteString
    
    mov dh, 7
    mov dl, 32
    call Gotoxy
    mov edx, OFFSET strMenu1 ; Start
    call WriteString
    
    mov dh, 8
    mov dl, 32
    call Gotoxy
    mov edx, OFFSET strMenu2 ; Continue
    call WriteString
    
    mov dh, 9
    mov dl, 32
    call Gotoxy
    mov edx, OFFSET strMenu3 ; Difficulty
    call WriteString
    
    mov dh, 10
    mov dl, 32
    call Gotoxy
    mov edx, OFFSET strMenu4 ; High Scores
    call WriteString
    
    mov dh, 11
    mov dl, 32
    call Gotoxy
    mov edx, OFFSET strMenu5 ; Instructions
    call WriteString
    
    mov dh, 12
    mov dl, 32
    call Gotoxy
    mov edx, OFFSET strMenu6 ; Exit
    call WriteString
    
    call ReadChar
    cmp al, '1'
    je StartGame
    cmp al, '2'
    je ContinueGame
    cmp al, '3'
    je ChangeDifficulty
    cmp al, '4'
    je ViewScores
    cmp al, '5'
    je ViewInstructions
    cmp al, '6'
    je ExitGame
    jmp MainMenu

StartGame:
    call SelectGameMode  
    call SelectTaxiColor 
    call GetPlayerName   
    call SetupGame
    call GameLoop
    jmp MainMenu

ContinueGame:
    call LoadGameState
    cmp eax, 0 
    je MainMenu
    
    mov gameActive, 1
    mov gamePaused, 0
    call GetMseconds
    mov lastTick, eax 
    call GameLoop
    jmp MainMenu

ChangeDifficulty:
    call SelectDifficulty
    jmp MainMenu

ViewScores:
    call DisplayHighscores
    jmp MainMenu

ViewInstructions:
    call ShowInstructions
    jmp MainMenu

ExitGame:
    exit
main ENDP

; ------------------------------------------------------------------------
; SELECT DIFFICULTY
; ------------------------------------------------------------------------
SelectDifficulty PROC
    call Clrscr
    mov dh, 5
    mov dl, 30
    call Gotoxy
    mov edx, OFFSET strDiffTitle
    call WriteString
    
    mov dh, 7
    mov dl, 32
    call Gotoxy
    mov edx, OFFSET strDiff1
    call WriteString
    
    mov dh, 8
    mov dl, 32
    call Gotoxy
    mov edx, OFFSET strDiff2
    call WriteString
    
    mov dh, 9
    mov dl, 32
    call Gotoxy
    mov edx, OFFSET strDiff3
    call WriteString
    
    DiffInput:
    call ReadChar
    cmp al, '1'
    je SetEasy
    cmp al, '2'
    je SetMed
    cmp al, '3'
    je SetHard
    jmp DiffInput
    
    SetEasy:
    mov difficultySetting, 1
    mov baseDifficultySpeed, 120
    ret
    SetMed:
    mov difficultySetting, 2
    mov baseDifficultySpeed, 100
    ret
    SetHard:
    mov difficultySetting, 3
    mov baseDifficultySpeed, 80
    ret
SelectDifficulty ENDP

; ------------------------------------------------------------------------
; GAME STATE MANAGEMENT
; ------------------------------------------------------------------------
SaveGameState PROC
    mov edx, OFFSET saveFilename
    call CreateOutputFile
    cmp eax, INVALID_HANDLE_VALUE
    je SaveError
    
    mov fileHandle, eax
    
    ; Write Magic Number
    mov saveSignature, SAVE_SIGNATURE
    mov edx, OFFSET saveSignature
    mov ecx, 4
    call WriteToFile
    
    ; Save Core Variables
    mov edx, OFFSET playerScore
    mov ecx, 4
    call WriteToFile
    mov edx, OFFSET passengersDelivered
    mov ecx, 4
    call WriteToFile
    mov edx, OFFSET level
    mov ecx, 4
    call WriteToFile
    mov edx, OFFSET gameTime
    mov ecx, 4
    call WriteToFile
    mov edx, OFFSET gameSpeed
    mov ecx, 4
    call WriteToFile
    mov edx, OFFSET playerColor
    mov ecx, 4
    call WriteToFile
    mov edx, OFFSET currentMode
    mov ecx, 4
    call WriteToFile
    mov edx, OFFSET playerX
    mov ecx, 4
    call WriteToFile
    mov edx, OFFSET playerY
    mov ecx, 4
    call WriteToFile
    mov edx, OFFSET hasPassenger
    mov ecx, 4
    call WriteToFile
    
    ; Save Arrays
    mov edx, OFFSET currentPlayerName
    mov ecx, 20
    call WriteToFile
    mov edx, OFFSET passX
    mov ecx, SIZEOF passX
    call WriteToFile
    mov edx, OFFSET passY
    mov ecx, SIZEOF passY
    call WriteToFile
    mov edx, OFFSET destX
    mov ecx, SIZEOF destX
    call WriteToFile
    mov edx, OFFSET destY
    mov ecx, SIZEOF destY
    call WriteToFile
    mov edx, OFFSET passActive
    mov ecx, SIZEOF passActive
    call WriteToFile
    mov edx, OFFSET npcX
    mov ecx, SIZEOF npcX
    call WriteToFile
    mov edx, OFFSET npcY
    mov ecx, SIZEOF npcY
    call WriteToFile
    mov edx, OFFSET npcDir
    mov ecx, SIZEOF npcDir
    call WriteToFile
    mov edx, OFFSET bonusX
    mov ecx, SIZEOF bonusX
    call WriteToFile
    mov edx, OFFSET bonusY
    mov ecx, SIZEOF bonusY
    call WriteToFile
    mov edx, OFFSET bonusActive
    mov ecx, SIZEOF bonusActive
    call WriteToFile
    
    ; Save Board
    mov edx, OFFSET board
    mov ecx, BOARD_AREA
    call WriteToFile
    
    mov eax, fileHandle
    call CloseFile
    
    mov dh, 0
    mov dl, 60
    call Gotoxy
    mov edx, OFFSET strSavedMsg
    call WriteString
    mov eax, 1000
    call Delay
    
SaveError:
    ret
SaveGameState ENDP

LoadGameState PROC
    mov edx, OFFSET saveFilename
    call OpenInputFile
    cmp eax, INVALID_HANDLE_VALUE
    je LoadFail
    
    mov fileHandle, eax
    
    ; Validate Magic Number
    mov edx, OFFSET saveSignature
    mov ecx, 4
    call ReadFromFile
    mov eax, saveSignature
    cmp eax, SAVE_SIGNATURE
    jne BadSaveFile
    
    ; Read Core Variables
    mov edx, OFFSET playerScore
    mov ecx, 4
    call ReadFromFile
    mov edx, OFFSET passengersDelivered
    mov ecx, 4
    call ReadFromFile
    mov edx, OFFSET level
    mov ecx, 4
    call ReadFromFile
    mov edx, OFFSET gameTime
    mov ecx, 4
    call ReadFromFile
    mov edx, OFFSET gameSpeed
    mov ecx, 4
    call ReadFromFile
    mov edx, OFFSET playerColor
    mov ecx, 4
    call ReadFromFile
    mov edx, OFFSET currentMode
    mov ecx, 4
    call ReadFromFile
    mov edx, OFFSET playerX
    mov ecx, 4
    call ReadFromFile
    mov edx, OFFSET playerY
    mov ecx, 4
    call ReadFromFile
    mov edx, OFFSET hasPassenger
    mov ecx, 4
    call ReadFromFile
    
    ; Read Arrays
    mov edx, OFFSET currentPlayerName
    mov ecx, 20
    call ReadFromFile
    mov edx, OFFSET passX
    mov ecx, SIZEOF passX
    call ReadFromFile
    mov edx, OFFSET passY
    mov ecx, SIZEOF passY
    call ReadFromFile
    mov edx, OFFSET destX
    mov ecx, SIZEOF destX
    call ReadFromFile
    mov edx, OFFSET destY
    mov ecx, SIZEOF destY
    call ReadFromFile
    mov edx, OFFSET passActive
    mov ecx, SIZEOF passActive
    call ReadFromFile
    mov edx, OFFSET npcX
    mov ecx, SIZEOF npcX
    call ReadFromFile
    mov edx, OFFSET npcY
    mov ecx, SIZEOF npcY
    call ReadFromFile
    mov edx, OFFSET npcDir
    mov ecx, SIZEOF npcDir
    call ReadFromFile
    mov edx, OFFSET bonusX
    mov ecx, SIZEOF bonusX
    call ReadFromFile
    mov edx, OFFSET bonusY
    mov ecx, SIZEOF bonusY
    call ReadFromFile
    mov edx, OFFSET bonusActive
    mov ecx, SIZEOF bonusActive
    call ReadFromFile
    
    ; Read Board
    mov edx, OFFSET board
    mov ecx, BOARD_AREA
    call ReadFromFile
    
    mov eax, fileHandle
    call CloseFile
    mov eax, 1 ; Success
    ret

BadSaveFile:
    mov eax, fileHandle
    call CloseFile
LoadFail:
    call Clrscr
    mov dh, 10
    mov dl, 30
    call Gotoxy
    mov edx, OFFSET strNoSaveMsg
    call WriteString
    mov eax, 2000
    call Delay
    mov eax, 0 ; Fail
    ret
LoadGameState ENDP

; ------------------------------------------------------------------------
; SELECT GAME MODE
; ------------------------------------------------------------------------
SelectGameMode PROC
    call Clrscr
    mov dh, 5
    mov dl, 30
    call Gotoxy
    mov edx, OFFSET strModeTitle
    call WriteString
    
    mov dh, 7
    mov dl, 32
    call Gotoxy
    mov edx, OFFSET strMode1 ; Career
    call WriteString
    
    mov dh, 8
    mov dl, 32
    call Gotoxy
    mov edx, OFFSET strMode2 ; Time
    call WriteString
    
    mov dh, 9
    mov dl, 32
    call Gotoxy
    mov edx, OFFSET strMode3 ; Endless
    call WriteString
    
    ; FIX: Clear input buffer loop to avoid auto-selection
FlushInput:
    call ReadKey
    jnz FlushInput
    
ModeInput:
    call ReadChar
    cmp al, '1'
    je SetCareer
    cmp al, '2'
    je SetTime
    cmp al, '3'
    je SetEndless
    jmp ModeInput
    
SetCareer:
    mov currentMode, MODE_CAREER
    ret
SetTime:
    mov currentMode, MODE_TIME
    ret
SetEndless:
    mov currentMode, MODE_ENDLESS
    ret
SelectGameMode ENDP

; ------------------------------------------------------------------------
; SHOW INSTRUCTIONS
; ------------------------------------------------------------------------
ShowInstructions PROC
    call Clrscr
    mov dh, 3
    mov dl, 30
    call Gotoxy
    mov edx, OFFSET strInstrTitle
    call WriteString
    
    mov dh, 5
    mov dl, 15
    call Gotoxy
    mov edx, OFFSET strInstr1
    call WriteString
    
    mov dh, 6
    mov dl, 15
    call Gotoxy
    mov edx, OFFSET strInstr2
    call WriteString
    
    mov dh, 7
    mov dl, 15
    call Gotoxy
    mov edx, OFFSET strInstr3
    call WriteString
    
    mov dh, 8
    mov dl, 15
    call Gotoxy
    mov edx, OFFSET strInstr4
    call WriteString
    
    mov dh, 9
    mov dl, 15
    call Gotoxy
    mov edx, OFFSET strInstr5
    call WriteString
    
    mov dh, 10
    mov dl, 15
    call Gotoxy
    mov edx, OFFSET strInstr6
    call WriteString
    
    mov dh, 12
    mov dl, 15
    call Gotoxy
    mov edx, OFFSET strInstr7
    call WriteString
    
    mov dh, 13
    mov dl, 15
    call Gotoxy
    mov edx, OFFSET strInstr8
    call WriteString

    mov dh, 14
    mov dl, 15
    call Gotoxy
    mov edx, OFFSET strInstr9
    call WriteString

    mov dh, 15
    mov dl, 15
    call Gotoxy
    mov edx, OFFSET strInstr10
    call WriteString

    mov dh, 16
    mov dl, 15
    call Gotoxy
    mov edx, OFFSET strInstr11
    call WriteString

    mov dh, 17
    mov dl, 15
    call Gotoxy
    mov edx, OFFSET strInstr12
    call WriteString
    
    mov dh, 19
    mov dl, 25
    call Gotoxy
    mov edx, OFFSET strPressKey
    call WriteString
    call ReadChar
    ret
ShowInstructions ENDP

; ------------------------------------------------------------------------
; GET PLAYER NAME
; ------------------------------------------------------------------------
GetPlayerName PROC
    call Clrscr
    mov dh, 10
    mov dl, 30
    call Gotoxy
    mov edx, OFFSET strEnterName
    call WriteString
    
    mov edx, OFFSET currentPlayerName
    mov ecx, 19 
    call ReadString
    ret
GetPlayerName ENDP

; ------------------------------------------------------------------------
; SELECT TAXI COLOR
; ------------------------------------------------------------------------
SelectTaxiColor PROC
    call Clrscr
    mov dh, 5
    mov dl, 30
    call Gotoxy
    mov edx, OFFSET strTaxiTitle
    call WriteString
    
    mov dh, 7
    mov dl, 32
    call Gotoxy
    mov edx, OFFSET strTaxi1 
    call WriteString
    
    mov dh, 8
    mov dl, 32
    call Gotoxy
    mov edx, OFFSET strTaxi2 
    call WriteString
    
    mov dh, 9
    mov dl, 32
    call Gotoxy
    mov edx, OFFSET strTaxi3 
    call WriteString
    
    TaxiInput:
    call ReadChar
    cmp al, '1'
    je SetYellow
    cmp al, '2'
    je SetRed
    cmp al, '3'
    je SetRandom
    jmp TaxiInput
    
    SetYellow:
    mov playerColor, 0F6h 
    mov taxiBaseSpeed, 60 
    mov penaltyObstacle, 4
    mov penaltyCar, 2
    ret
    
    SetRed:
    mov playerColor, 0F4h 
    mov taxiBaseSpeed, 100 
    mov penaltyObstacle, 2
    mov penaltyCar, 3
    ret
    
    SetRandom:
    mov eax, 2
    call RandomRange
    cmp eax, 0
    je SetYellow
    jmp SetRed
SelectTaxiColor ENDP

; ------------------------------------------------------------------------
; SETUP GAME
; ------------------------------------------------------------------------
SetupGame PROC
    mov playerScore, 0
    mov passengersDelivered, 0 
    mov level, 1
    mov gameTime, 60 
    call GetMseconds 
    mov lastTick, eax
    
    ; Apply base speed modified by difficulty
    mov eax, taxiBaseSpeed 
    ; Simple difficulty modifier: Easy=+20, Med=0, Hard=-20
    cmp difficultySetting, 1
    je EasyMode
    cmp difficultySetting, 3
    je HardMode
    jmp StoreSpeed
EasyMode:
    add eax, 20
    jmp StoreSpeed
HardMode:
    sub eax, 20
StoreSpeed:
    mov gameSpeed, eax
    
    mov playerX, 1
    mov playerY, 1
    mov hasPassenger, 0
    mov gameActive, 1
    mov gamePaused, 0 
    mov gameWon, 0 
    
    ; Clear Board
    mov ecx, BOARD_AREA
    mov edi, OFFSET board
    mov al, 0
    rep stosb
    
    ; Generate Random Walls
    mov ecx, 60     
GenWalls:
    mov eax, BOARD_AREA
    call RandomRange
    mov edi, OFFSET board
    add edi, eax
    mov BYTE PTR [edi], 1   
    dec ecx
    jnz GenWalls
    
    ; Clear Start Area
    mov ecx, 3
    mov esi, 0
ClearRow:
    push ecx
    mov ecx, 3
    mov edi, 0
ClearCol:
    mov eax, esi
    mov ebx, BOARD_SIZE
    mul ebx
    add eax, edi
    mov ebx, OFFSET board
    mov BYTE PTR [ebx + eax], 0 
    inc edi
    dec ecx
    jnz ClearCol
    pop ecx
    inc esi
    dec ecx
    jnz ClearRow

    ; Clear Passenger Arrays
    mov ecx, MAX_PASSENGERS
    mov esi, 0
ClearPass:
    mov passActive[esi*4], 0 
    inc esi
    dec ecx
    jnz ClearPass

    call InitNPCs
    call InitBonusItems 
    call InitPassengers 
    call EnsureAllPaths
    
    ret
SetupGame ENDP

; ------------------------------------------------------------------------
; INIT BONUS ITEMS
; ------------------------------------------------------------------------
InitBonusItems PROC
    mov ecx, MAX_BONUS_ITEMS
    mov esi, 0
BonusLoop:
    mov bonusActive[esi*4], 0 
    push ecx
    push esi
    call SpawnOneBonus
    pop esi
    pop ecx
    inc esi
    dec ecx
    jnz BonusLoop
    ret
InitBonusItems ENDP

; ------------------------------------------------------------------------
; SPAWN ONE BONUS
; ------------------------------------------------------------------------
SpawnOneBonus PROC
FindBonusPos:
    mov eax, BOARD_AREA
    call RandomRange
    mov ebx, OFFSET board
    cmp BYTE PTR [ebx + eax], 0 
    jne FindBonusPos
    
    mov edx, 0
    mov ecx, BOARD_SIZE
    div ecx
    mov bonusY[esi*4], eax
    mov bonusX[esi*4], edx
    mov bonusActive[esi*4], 1
    ret
SpawnOneBonus ENDP

; ------------------------------------------------------------------------
; CHECK BONUS COLLECTION
; ------------------------------------------------------------------------
CheckBonusCollection PROC
    mov ecx, MAX_BONUS_ITEMS
    mov esi, 0
CheckLoop:
    cmp bonusActive[esi*4], 1
    jne NextBonus
    
    mov eax, playerX
    cmp eax, bonusX[esi*4]
    jne NextBonus
    mov eax, playerY
    cmp eax, bonusY[esi*4]
    jne NextBonus
    
    add playerScore, 10
    call Snd_GetPassenger 
    call SpawnOneBonus 
    
NextBonus:
    inc esi
    dec ecx
    jnz CheckLoop
    ret
CheckBonusCollection ENDP

; ------------------------------------------------------------------------
; INIT PASSENGERS
; ------------------------------------------------------------------------
InitPassengers PROC
    mov ecx, MIN_PASSENGERS
SpawnInitial:
    push ecx
    call SpawnOnePassenger
    pop ecx
    dec ecx
    jnz SpawnInitial
    ret
InitPassengers ENDP

; ------------------------------------------------------------------------
; REFILL PASSENGERS
; ------------------------------------------------------------------------
RefillPassengers PROC
    pushad
    mov ecx, MAX_PASSENGERS
    mov esi, 0
    mov ebx, 0 
CountLoop:
    cmp passActive[esi*4], 1 
    jne NextCount
    inc ebx
NextCount:
    inc esi
    dec ecx
    jnz CountLoop
    
    cmp ebx, MIN_PASSENGERS
    jge RefillDone
    call SpawnOnePassenger
    
RefillDone:
    popad
    ret
RefillPassengers ENDP

; ------------------------------------------------------------------------
; SPAWN ONE PASSENGER
; ------------------------------------------------------------------------
SpawnOnePassenger PROC
    pushad
    mov ecx, MAX_PASSENGERS
    mov esi, 0
FindSlot:
    cmp passActive[esi*4], 0
    je FoundSlot
    inc esi
    dec ecx
    jnz FindSlot
    jmp SpawnDone 
    
FoundSlot:
FindPickup:
    mov eax, BOARD_AREA
    call RandomRange
    mov ebx, OFFSET board
    cmp BYTE PTR [ebx + eax], 0 
    jne FindPickup
    
    mov edx, 0
    mov ecx, BOARD_SIZE
    div ecx
    mov passY[esi*4], eax
    mov passX[esi*4], edx
    
FindDest:
    mov eax, BOARD_AREA
    call RandomRange
    mov ebx, OFFSET board
    cmp BYTE PTR [ebx + eax], 0 
    jne FindDest
    
    mov edx, 0
    mov ecx, BOARD_SIZE
    div ecx
    mov destY[esi*4], eax
    mov destX[esi*4], edx
    
    mov passActive[esi*4], 1 
    
SpawnDone:
    popad
    ret
SpawnOnePassenger ENDP

; ------------------------------------------------------------------------
; ENSURE ALL PATHS
; ------------------------------------------------------------------------
EnsureAllPaths PROC
    pushad
    mov ecx, MAX_PASSENGERS
    mov esi, 0
PathLoop:
    cmp passActive[esi*4], 1
    jne NextPath
    
    mov eax, playerX
    mov ebx, playerY
    mov ecx, passX[esi*4]
    mov edx, passY[esi*4]
    call CarveRoute
    
    mov eax, passX[esi*4]
    mov ebx, passY[esi*4]
    mov ecx, destX[esi*4]
    mov edx, destY[esi*4]
    call CarveRoute
    
NextPath:
    inc esi
    dec ecx
    jnz PathLoop
    popad
    ret
EnsureAllPaths ENDP

; ------------------------------------------------------------------------
; CARVE ROUTE HELPER
; ------------------------------------------------------------------------
CarveRoute PROC
    pushad
DrillLoop:
    cmp eax, ecx
    je CheckY
    jl IncX
    dec eax 
    jmp DrillCell
IncX:
    inc eax 
    jmp DrillCell
CheckY:
    cmp ebx, edx
    je DrillDone 
    jl IncY
    dec ebx 
    jmp DrillCell
IncY:
    inc ebx 
DrillCell:
    push eax
    push ebx
    push edx
    push eax    
    mov eax, ebx 
    push ecx    
    mov ecx, BOARD_SIZE
    mul ecx     
    pop ecx     
    mov edx, eax 
    pop eax     
    add edx, eax 
    mov esi, OFFSET board
    mov BYTE PTR [esi + edx], 0 
    pop edx
    pop ebx
    pop eax
    jmp DrillLoop
DrillDone:
    popad
    ret
CarveRoute ENDP

; ------------------------------------------------------------------------
; INIT NPCs
; ------------------------------------------------------------------------
InitNPCs PROC
    mov ecx, NPC_COUNT
    mov esi, 0
InitLoop:
    mov eax, BOARD_SIZE
    call RandomRange
    mov npcX[esi*4], eax
    mov eax, BOARD_SIZE
    call RandomRange
    mov npcY[esi*4], eax
    mov eax, 4
    call RandomRange
    mov npcDir[esi*4], eax
    inc esi
    dec ecx
    jnz InitLoop
    ret
InitNPCs ENDP

; ------------------------------------------------------------------------
; GAME LOOP
; ------------------------------------------------------------------------
GameLoop PROC
    call Clrscr
LoopStart:
    cmp gameActive, 0
    je LoopEnd
    
    call ReadKey
    jz Update
    
    cmp al, 's'
    je SaveGameAction
    cmp al, 'S'
    je SaveGameAction
    cmp al, 'p'
    je TogglePause
    cmp al, 'P'
    je TogglePause
    
    ; FIX: Check ASCII code AL for ESC key
    cmp al, KEY_ESC
    je QuitToMenu
    
    cmp gamePaused, 1
    je Update
    
    cmp ah, KEY_UP
    je MoveUp
    cmp ah, KEY_DOWN
    je MoveDown
    cmp ah, KEY_LEFT
    je MoveLeft
    cmp ah, KEY_RIGHT
    je MoveRight
    cmp al, KEY_SPACE
    je HandleAction
    jmp Update

QuitToMenu:
    ret

SaveGameAction:
    call SaveGameState
    ret
TogglePause:
    xor gamePaused, 1
    jmp Update
MoveUp:
    mov eax, 0
    mov ebx, -1
    call TryMove
    jmp Update
MoveDown:
    mov eax, 0
    mov ebx, 1
    call TryMove
    jmp Update
MoveLeft:
    mov eax, -1
    mov ebx, 0
    call TryMove
    jmp Update
MoveRight:
    mov eax, 1
    mov ebx, 0
    call TryMove
    jmp Update
HandleAction:
    call PlayerAction
    jmp Update
Update:
    cmp gamePaused, 1
    je DrawOnly
    call UpdateTimer 
    call UpdateNPCs
    call CheckCollisions
    call CheckLevelUp 
    call RefillPassengers 
    
    ; --- NEW: Check Win Condition Every Frame ---
    cmp currentMode, MODE_CAREER
    jne DrawOnly
    cmp playerScore, CAREER_TARGET
    jb DrawOnly
    
    ; Career Won!
    mov gameActive, 0
    mov gameWon, 1
    jmp LoopEnd
    ; --------------------------------------------
    
DrawOnly:
    call DrawBoard
    mov eax, gameSpeed
    call Delay
    jmp LoopStart
LoopEnd:
    call ShowGameOver
    ret
GameLoop ENDP

; ------------------------------------------------------------------------
; UPDATE TIMER
; ------------------------------------------------------------------------
UpdateTimer PROC
    ; FIX: Disable timer in Career Mode too? Or just Endless?
    ; Requirement says Career Mode has a score target, usually implies time pressure or not.
    ; Let's assume Career mode DOES NOT time out (like Endless) but has a goal.
    ; Wait, most Career modes have time limits.
    ; The user prompt was: "when i play career mode timer is still shown and game ends when time runs out fix it"
    ; So I will disable Timer updates for Career Mode as well.
    
    cmp currentMode, MODE_ENDLESS
    je NoTimeUpdate
    cmp currentMode, MODE_CAREER ; FIX: Career Mode also no timer?
    je NoTimeUpdate
    
    call GetMseconds
    sub eax, lastTick
    cmp eax, 1000
    jb NoTimeUpdate
    dec gameTime
    add lastTick, 1000 
    cmp gameTime, 0
    jne NoTimeUpdate
    mov gameActive, 0 
NoTimeUpdate:
    ret
UpdateTimer ENDP

; ------------------------------------------------------------------------
; TRY MOVE PLAYER
; ------------------------------------------------------------------------
TryMove PROC
    add eax, playerX
    add ebx, playerY
    cmp eax, 0
    jl InvalidMove
    cmp eax, BOARD_SIZE
    jge InvalidMove
    cmp ebx, 0
    jl InvalidMove
    cmp ebx, BOARD_SIZE
    jge InvalidMove
    
    push ecx
    push esi
    mov ecx, MAX_PASSENGERS
    mov esi, 0
CheckPassColl:
    cmp passActive[esi*4], 1 
    jne NextPassColl
    cmp eax, passX[esi*4]
    jne NextPassColl
    cmp ebx, passY[esi*4]
    jne NextPassColl
    push eax
    mov eax, 5
    cmp playerScore, eax
    jb ResetScorePerson
    sub playerScore, eax
    jmp DoBeepPerson
ResetScorePerson:
    mov playerScore, 0
DoBeepPerson:
    call Snd_Accident 
    pop eax
    pop esi
    pop ecx
    ret 
NextPassColl:
    inc esi
    dec ecx
    jnz CheckPassColl
    pop esi
    pop ecx
    
    push eax    
    push ebx    
    push eax    
    mov eax, ebx 
    mov ecx, BOARD_SIZE
    mul ecx     
    mov ecx, eax
    pop eax     
    add eax, ecx 
    mov ecx, OFFSET board
    cmp BYTE PTR [ecx + eax], 1 
    pop ebx     
    pop eax     
    je HitBuilding
    
    mov playerX, eax
    mov playerY, ebx
    call CheckBonusCollection 
    ret
HitBuilding:
    mov ecx, penaltyObstacle
    cmp playerScore, ecx
    jb ResetScore
    sub playerScore, ecx
    jmp DoBeep
ResetScore:
    mov playerScore, 0
DoBeep:
    call Snd_Accident 
    ret
InvalidMove:
    ret
TryMove ENDP

; ------------------------------------------------------------------------
; PLAYER ACTION
; ------------------------------------------------------------------------
PlayerAction PROC
    cmp hasPassenger, 1
    je TryDrop
    mov ecx, MAX_PASSENGERS
    mov esi, 0
PickupLoop:
    cmp passActive[esi*4], 1
    jne NextPickup
    push eax
    push ebx
    push edx
    mov ebx, 0
    mov eax, playerX
    sub eax, passX[esi*4]
    cdq
    xor eax, edx
    sub eax, edx
    add ebx, eax
    mov eax, playerY
    sub eax, passY[esi*4]
    cdq
    xor eax, edx
    sub eax, edx
    add ebx, eax
    mov eax, ebx 
    pop edx
    pop ebx
    cmp eax, 1
    pop eax 
    jne NextPickup
    mov passActive[esi*4], 2 
    mov hasPassenger, 1
    call Snd_GetPassenger 
    ret 
NextPickup:
    inc esi
    dec ecx
    jnz PickupLoop
    ret
TryDrop:
    mov ecx, MAX_PASSENGERS
    mov esi, 0
DropLoop:
    cmp passActive[esi*4], 2
    jne NextDrop
    mov eax, playerX
    cmp eax, destX[esi*4]
    jne NextDrop
    mov eax, playerY
    cmp eax, destY[esi*4]
    jne NextDrop
    mov passActive[esi*4], 0 
    mov hasPassenger, 0
    add playerScore, 10
    
    ; FIX: Don't add bonus time in Career Mode (since timer is disabled)
    cmp currentMode, MODE_TIME
    jne CheckCareerWin
    add gameTime, 5
    
CheckCareerWin:
    inc passengersDelivered 
    call Snd_JobComplete 
    
    ; REMOVED WIN CHECK FROM HERE - Handled in Update Loop now
    
    ret
NextDrop:
    inc esi
    dec ecx
    jnz DropLoop
ActionDone:
    ret
PlayerAction ENDP

; ------------------------------------------------------------------------
; CHECK LEVEL UP
; ------------------------------------------------------------------------
CheckLevelUp PROC
    mov edx, 0
    mov eax, passengersDelivered
    mov ecx, 2
    div ecx         
    inc eax         
    cmp eax, 10
    jle LevelOK
    mov eax, 10
LevelOK:
    mov level, eax
    mov ebx, eax    
    imul ebx, 5     
    mov eax, taxiBaseSpeed 
    sub eax, ebx    
    cmp eax, 20
    jg SetSpeed
    mov eax, 20     
SetSpeed:
    mov gameSpeed, eax
    ret
CheckLevelUp ENDP

; ------------------------------------------------------------------------
; UPDATE NPCs
; ------------------------------------------------------------------------
UpdateNPCs PROC
    inc npcTimer
    cmp npcTimer, 3
    jl SkipNPCMove
    mov npcTimer, 0
    mov ecx, NPC_COUNT
    mov esi, 0
NPCMoveLoop:
    mov eax, npcX[esi*4]
    mov ebx, npcY[esi*4]
    cmp npcDir[esi*4], 0
    je N_Up
    cmp npcDir[esi*4], 1
    je N_Down
    cmp npcDir[esi*4], 2
    je N_Left
    jmp N_Right
N_Up:    dec ebx
         jmp CheckNPCBounds
N_Down:  inc ebx
         jmp CheckNPCBounds
N_Left:  dec eax
         jmp CheckNPCBounds
N_Right: inc eax
         jmp CheckNPCBounds
CheckNPCBounds:
    cmp eax, 0
    jl N_Bounce
    cmp eax, BOARD_SIZE
    jge N_Bounce
    cmp ebx, 0
    jl N_Bounce
    cmp ebx, BOARD_SIZE
    jge N_Bounce
    push eax    
    push ebx    
    push edx    
    push eax    
    mov eax, ebx 
    mov ebx, BOARD_SIZE
    mul ebx     
    pop ebx     
    add eax, ebx 
    mov ebx, OFFSET board
    mov dl, BYTE PTR [ebx + eax]
    cmp dl, 1   
    pop edx     
    pop ebx     
    pop eax     
    je N_Bounce 
    mov npcX[esi*4], eax
    mov npcY[esi*4], ebx
    jmp NextNPC
N_Bounce:
    push eax
    mov eax, 4
    call RandomRange
    mov npcDir[esi*4], eax
    pop eax
NextNPC:
    inc esi
    dec ecx
    cmp ecx, 0
    je EndUpdateLoop ; FIX: Local jump (short)
    jmp NPCMoveLoop  ; FIX: Long jump (safe)
EndUpdateLoop:
    
    ; Increment global NPC timer
    ; (No longer used here but logic structure preserved)
    
SkipNPCMove:
    ret
UpdateNPCs ENDP

; ------------------------------------------------------------------------
; CHECK COLLISIONS
; ------------------------------------------------------------------------
CheckCollisions PROC
    mov ecx, NPC_COUNT
    mov esi, 0
CheckColLoop:
    mov eax, playerX
    cmp eax, npcX[esi*4]
    jne NextCol
    mov eax, playerY
    cmp eax, npcY[esi*4]
    jne NextCol
    call Snd_Accident 
    mov eax, penaltyCar
    cmp playerScore, eax
    jb ResetScoreCar
    sub playerScore, eax
    jmp ResetPos
ResetScoreCar:
    mov playerScore, 0
ResetPos:
    mov playerX, 1
    mov playerY, 1
    ret 
NextCol:
    inc esi
    dec ecx
    jnz CheckColLoop
    ret
CheckCollisions ENDP

; ------------------------------------------------------------------------
; DRAW BOARD (FIXED LOOPS)
; ------------------------------------------------------------------------
DrawBoard PROC
    mov dh, 0
    mov dl, 0
    call Gotoxy
    mov eax, 15     
    call SetTextColor
    mov edx, OFFSET strScore
    call WriteString
    mov eax, playerScore
    call WriteDec
    mov edx, OFFSET strLevel
    call WriteString
    mov eax, level
    call WriteDec
    
    ; FIX: Hide Timer in Career Mode too
    cmp currentMode, MODE_ENDLESS
    je DrawTimeDone
    cmp currentMode, MODE_CAREER ; Added check
    je DrawTimeDone
    
    mov edx, OFFSET strTime
    call WriteString
    mov eax, gameTime
    call WriteDec
    mov al, ' ' 
    call WriteChar
DrawTimeDone:
    cmp gamePaused, 1
    jne ClearPause
    mov edx, OFFSET strPausedMsg
    call WriteString
    jmp DrawGrid
ClearPause:
    mov edx, OFFSET strClearPause
    call WriteString
DrawGrid:
    call Crlf
    mov ebx, 0      
RowLoop:
    mov ecx, 0      
ColLoop:
    cmp ecx, playerX
    jne CheckNPC
    cmp ebx, playerY
    jne CheckNPC
    mov eax, playerColor 
    call SetTextColor
    mov al, 'T'
    call WriteChar
    jmp NextCell
CheckNPC:
    push ecx        
    push ebx        
    mov edi, NPC_COUNT
    mov esi, 0
NPCLoop:
    cmp ecx, npcX[esi*4]
    jne NPCContinue
    cmp ebx, npcY[esi*4]
    jne NPCContinue
    pop ebx         
    pop ecx         
    mov eax, 0F1h   
    call SetTextColor
    mov al, 'C'
    call WriteChar
    jmp NextCell    
NPCContinue:
    inc esi
    dec edi
    cmp edi, 0
    je EndNPCLoop_Jmp
    jmp NPCLoop
EndNPCLoop_Jmp:
    jmp EndNPCLoop
EndNPCLoop:
    pop ebx         
    pop ecx         
CheckPassengers:
    push ecx
    push ebx
    mov edi, MAX_PASSENGERS
    mov esi, 0
PassLoop:
    cmp passActive[esi*4], 1 
    jne TryDrawDest
    cmp ecx, passX[esi*4]
    jne TryDrawDest
    cmp ebx, passY[esi*4]
    jne TryDrawDest
    pop ebx
    pop ecx
    mov eax, 0FAh
    call SetTextColor
    mov al, 'P'
    call WriteChar
    jmp NextCell
TryDrawDest:
    cmp passActive[esi*4], 2 
    jne NextPass
    cmp ecx, destX[esi*4]
    jne NextPass
    cmp ebx, destY[esi*4]
    jne NextPass
    pop ebx
    pop ecx
    mov eax, 0A0h ; Green BG / Black FG for Destination Highlight
    call SetTextColor
    mov al, 'D'
    call WriteChar
    jmp NextCell
NextPass:
    inc esi
    dec edi
    cmp edi, 0
    je EndPassLoop_Jmp
    jmp PassLoop
EndPassLoop_Jmp:
    jmp EndPassLoop
EndPassLoop:
    pop ebx
    pop ecx
CheckBonus:
    push ecx
    push ebx
    mov edi, MAX_BONUS_ITEMS
    mov esi, 0
BonusLoop:
    cmp bonusActive[esi*4], 1
    jne NextBonus
    cmp ecx, bonusX[esi*4]
    jne NextBonus
    cmp ebx, bonusY[esi*4]
    jne NextBonus
    pop ebx
    pop ecx
    mov eax, 0FDh 
    call SetTextColor
    mov al, 'B'
    call WriteChar
    jmp NextCell
NextBonus:
    inc esi
    dec edi
    cmp edi, 0
    je EndBonusLoop_Jmp
    jmp BonusLoop
EndBonusLoop_Jmp:
    jmp EndBonusLoop
EndBonusLoop:
    pop ebx
    pop ecx
CheckWall:
    push ecx
    push ebx
    mov eax, ebx
    push ecx        
    mov ecx, BOARD_SIZE
    mul ecx
    pop ecx         
    add eax, ecx
    mov esi, OFFSET board
    cmp BYTE PTR [esi + eax], 1
    pop ebx
    pop ecx
    jne DrawEmpty
    mov eax, 0 
    call SetTextColor
    mov al, ' '     
    call WriteChar
    jmp NextCell
DrawEmpty:
    mov eax, 0F0h   
    call SetTextColor
    mov al, ' '
    call WriteChar
NextCell:
    inc ecx
    cmp ecx, BOARD_SIZE
    jge EndColLoop_Jmp 
    jmp ColLoop
EndColLoop_Jmp:
    jmp EndColLoop
EndColLoop:
    mov eax, 15
    call SetTextColor
    call Crlf       
    inc ebx
    cmp ebx, BOARD_SIZE
    jge EndRowLoop_Jmp 
    jmp RowLoop
EndRowLoop_Jmp:
    jmp EndRowLoop
EndRowLoop:
    mov eax, 15
    call SetTextColor
    ret
DrawBoard ENDP

; =============================================================
;                AUDIO SUBSYSTEM
; =============================================================

Snd_GetPassenger PROC
    push 150    
    push 1100   
    call Beep
    ret
Snd_GetPassenger ENDP

Snd_JobComplete PROC
    push 100
    push 1200
    call Beep
    push 150
    push 2000   
    call Beep
    ret
Snd_JobComplete ENDP

Snd_Accident PROC
    push 400    
    push 180    
    call Beep
    ret
Snd_Accident ENDP

; ------------------------------------------------------------------------
; HIGH SCORE SYSTEM
; ------------------------------------------------------------------------
LoadHighscores PROC
    mov edx, OFFSET filename
    call OpenInputFile
    cmp eax, INVALID_HANDLE_VALUE
    je FileError
    mov fileHandle, eax
    mov edx, OFFSET highscoreCount
    mov ecx, 4
    call ReadFromFile
    mov eax, highscoreCount
    cmp eax, MAX_HIGHSCORES
    ja ResetBadFile    
    cmp eax, 0
    je CloseAndRet     
    mov edx, OFFSET highscoreValues
    mov ecx, SIZEOF highscoreValues
    call ReadFromFile
    mov edx, OFFSET highscoreNames
    mov ecx, SIZEOF highscoreNames
    call ReadFromFile
    jmp CloseAndRet
ResetBadFile:
    mov highscoreCount, 0 
CloseAndRet:
    mov eax, fileHandle
    call CloseFile
    ret
FileError:
    mov highscoreCount, 0 
    ret
LoadHighscores ENDP

SaveHighscores PROC
    mov edx, OFFSET filename
    call CreateOutputFile
    cmp eax, INVALID_HANDLE_VALUE 
    je SaveError
    mov fileHandle, eax
    mov edx, OFFSET highscoreCount
    mov ecx, 4
    call WriteToFile
    mov edx, OFFSET highscoreValues
    mov ecx, SIZEOF highscoreValues
    call WriteToFile
    mov edx, OFFSET highscoreNames
    mov ecx, SIZEOF highscoreNames
    call WriteToFile
    mov eax, fileHandle
    call CloseFile
SaveError:
    ret
SaveHighscores ENDP

CheckHighscore PROC
    mov eax, playerScore
    cmp eax, 0
    je NoHighscore 
    mov ecx, highscoreCount
    cmp ecx, MAX_HIGHSCORES
    jl IsHighscore 
    mov esi, MAX_HIGHSCORES
    dec esi
    cmp eax, highscoreValues[esi*4]
    jbe NoHighscore
IsHighscore:
    call Clrscr
    mov dh, 10
    mov dl, 30
    call Gotoxy
    mov edx, OFFSET strNewHigh
    call WriteString
    call Crlf
    call WaitMsg 
    mov eax, playerScore
    mov ecx, 0 
FindInsert:
    cmp ecx, highscoreCount
    jge InsertNow
    cmp ecx, MAX_HIGHSCORES
    jge InsertNow
    cmp eax, highscoreValues[ecx*4]
    jg InsertNow
    inc ecx
    jmp FindInsert
InsertNow:
    mov esi, MAX_HIGHSCORES
    dec esi 
ShiftLoop:
    cmp esi, ecx
    jle DoInsert
    mov eax, highscoreValues[esi*4 - 4] 
    mov highscoreValues[esi*4], eax
    push ecx
    push esi    
    mov edi, OFFSET highscoreNames
    mov eax, 20
    mul esi
    add edi, eax 
    mov eax, 20
    mov ebx, esi 
    dec ebx      
    mul ebx      
    mov edx, OFFSET highscoreNames 
    add edx, eax 
    mov esi, edx 
    mov ecx, 20
    cld
    rep movsb
    pop esi     
    pop ecx     
    dec esi
    jmp ShiftLoop
DoInsert:
    mov eax, playerScore
    mov highscoreValues[ecx*4], eax
    push ecx 
    mov edi, OFFSET highscoreNames
    mov eax, 20
    mul ecx
    add edi, eax 
    mov esi, OFFSET currentPlayerName
    mov ecx, 20
    cld
    rep movsb
    pop ecx
    mov eax, highscoreCount
    cmp eax, MAX_HIGHSCORES
    jge SaveIt
    inc highscoreCount
SaveIt:
    call SaveHighscores
NoHighscore:
    ret
CheckHighscore ENDP

DisplayHighscores PROC
    call Clrscr
    mov dh, 3
    mov dl, 25
    call Gotoxy
    mov edx, OFFSET strHeader
    call WriteString
    call Crlf
    mov dh, 4
    mov dl, 25
    call Gotoxy
    mov edx, OFFSET strSeparator
    call WriteString
    cmp highscoreCount, 0
    je NoScores
    mov ecx, highscoreCount
    mov esi, 0
    mov ebx, 5
PrintScoreLoop:
    push ecx
    mov dh, bl      
    mov dl, 25      
    call Gotoxy
    mov eax, 20
    mul esi         
    mov edx, OFFSET highscoreNames
    add edx, eax    
    call WriteString
    mov dh, bl      
    mov dl, 50      
    call Gotoxy
    mov eax, highscoreValues[esi*4]
    call WriteDec
    inc ebx         
    inc esi         
    pop ecx
    dec ecx
    cmp ecx, 0
    je EndPrintLoop 
    jmp PrintScoreLoop
EndPrintLoop:
    jmp WaitKey
NoScores:
    mov dh, 6
    mov dl, 30
    call Gotoxy
    mov edx, OFFSET strNoScores
    call WriteString
WaitKey:
    mov dh, 15
    mov dl, 25
    call Gotoxy
    mov edx, OFFSET strPressKey
    call WriteString
    call ReadChar
    ret
DisplayHighscores ENDP

ShowGameOver PROC
    call Clrscr
    mov dh, 10
    mov dl, 30
    call Gotoxy
    
    ; Check if Won or Lost
    cmp gameWon, 1
    je DrawWinMsg
    
    mov edx, OFFSET strGameOver
    call WriteString
    jmp DrawFinalScore
    
DrawWinMsg:
    mov edx, OFFSET strWin
    call WriteString
    
DrawFinalScore:
    mov dh, 11
    mov dl, 30
    call Gotoxy
    mov edx, OFFSET strFinal
    call WriteString
    mov eax, playerScore
    call WriteDec
    
    ; FIX: Wait here so user sees result before High Score check
    mov dh, 13
    mov dl, 30
    call Gotoxy
    mov edx, OFFSET strContinueMsg
    call WriteString
    call ReadChar
    
    call CheckHighscore
    
    ; No need for final wait here since CheckHighscore/Display already waits
    ret
ShowGameOver ENDP

END main
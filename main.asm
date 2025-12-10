; TITLE: Rush Hour Game

INCLUDE Irvine32.inc

; Define Windows API Beep if not already defined by Irvine
; PROTO directive tells the assembler about a procedure defined externally
Beep PROTO :DWORD, :DWORD

; ========================================================================
;                              CONSTANTS
; ========================================================================
; Constants make the code easier to read and modify.
;To avoid "magic numbers" and make updates easy.
BOARD_SIZE      = 20
BOARD_AREA      = BOARD_SIZE * BOARD_SIZE   ; Total cells (400) for linear mapping
MAX_PASSENGERS  = 5     
MIN_PASSENGERS  = 3     
MAX_BONUS_ITEMS = 3     
NPC_COUNT       = 5     ; Number of traffic cars
MAX_HIGHSCORES  = 10    ; Leaderboard size
SAVE_SIGNATURE  = 12345678h ; "Magic Number": Used to verify if a save file is valid before loading

; Game Modes identifiers (used for comparisons)
MODE_CAREER     = 1
MODE_TIME       = 2
MODE_ENDLESS    = 3
CAREER_TARGET   = 200   ; Score needed to win Career mode

; Key Codes (Hex values for keyboard input)

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
; --- UI Strings (Null-terminated for WriteString) ---
strTitle        BYTE "=== RUSH HOUR - Game ===",0
strMenu1        BYTE "1. Start New Game",0
strMenu2        BYTE "2. Continue Game",0 
strMenu3        BYTE "3. Change Difficulty",0 
strMenu4        BYTE "4. High Scores",0 
strMenu5        BYTE "5. Instructions",0 
strMenu6        BYTE "6. Exit",0         
strScore        BYTE "Score: ",0
strLevel        BYTE "   Level: ",0
strTime         BYTE "   Time: ",0 
strPausedMsg    BYTE "=== PAUSED ===",0  
strSavedMsg     BYTE "GAME SAVED!",0      
strNoSaveMsg    BYTE "Invalid or no save file found.",0
strClearPause   BYTE "              ",0  ; Empty string to overwrite "PAUSED" text
strGameOver     BYTE "GAME OVER!",0
strWin          BYTE "Mission passed! You Won!",0 
strFinal        BYTE "Final Score: ",0
strNewHigh      BYTE "NEW HIGH SCORE!",0
strEnterName    BYTE "Enter Name: ",0
strHeader       BYTE "   NAME                 SCORE",0
strSeparator    BYTE "------------------------------",0
strNoScores     BYTE "No high scores yet.",0
strPressKey     BYTE "Press any key to return...",0
strContinueMsg  BYTE "Press any key to continue...",0 

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
saveSignature   DWORD ?                   ; Buffer to check file validity

; --- Game Variables ---
;  32-bit integer, standard size for Irvine32 registers.
playerScore     DWORD 0
passengersDelivered DWORD 0 
level           DWORD 1
gameTime        DWORD 60    
lastTick        DWORD 0     ; Tracks real system time for the countdown
gameActive      DWORD 0     ; 1 = Game Running, 0 = Game Over
gamePaused      DWORD 0     ; Boolean flag: 0=Running, 1=Paused
gameSpeed       DWORD 100   ; Delay in ms (Lower value = Faster game)
playerColor     DWORD 0F6h  ; Stores console color code (BG+FG)
currentMode     DWORD 2     
gameWon         DWORD 0     

; --- Settings ---
difficultySetting DWORD 2   
baseDifficultySpeed DWORD 100

; --- Taxi Statistics ---
taxiBaseSpeed   DWORD 100 
penaltyObstacle DWORD 2
penaltyCar      DWORD 3

; --- Board Data ---
board           BYTE BOARD_AREA DUP(0)  ; 1D array representing 2D grid (20x20)
;  Memory is linear. map 2D (x,y) to 1D index (row*width + col).

; --- Player Data ---
playerX         DWORD 1
playerY         DWORD 1
hasPassenger    DWORD 0     ; Boolean: 0 = Empty, 1 = Full
currentPlayerName BYTE 20 DUP(0)

; --- Passenger Arrays ---
;  This is a "Struct of Arrays" pattern.
; Index 0 in passX corresponds to Index 0 in passY, passActive, etc.
passX           DWORD MAX_PASSENGERS DUP(0)
passY           DWORD MAX_PASSENGERS DUP(0)
destX           DWORD MAX_PASSENGERS DUP(0)
destY           DWORD MAX_PASSENGERS DUP(0)
passActive      DWORD MAX_PASSENGERS DUP(0) ; State: 0=Empty, 1=Waiting on road, 2=In Taxi

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

; ------------------------------------------------------------------------
; PROCEDURE: main
;    Entry point of the program.
;      Initializes the console, loads high scores, and runs the main
;            menu loop where the user can navigate to different screens.
; ------------------------------------------------------------------------
main PROC
    ; Initialize console: Set text to White (15) on Black (0)
    ; Calculation: (Background * 16) + Foreground
    mov eax, 15 + (0 * 16) 
    call SetTextColor
    call Clrscr
    
    call Randomize      ; Seed Random Number Generator using system time
    call LoadHighscores ; Read persistent high scores from file
    
MainMenu:
    ; Reset color for menu display
    mov eax, 15
    call SetTextColor
    call Clrscr
    
    ; === UI RENDERING ===
    ; Move cursor to specific row (DH) and column (DL)
    mov dh, 5
    mov dl, 30
    call Gotoxy
    mov edx, OFFSET strTitle ; Load address of string
    call WriteString         ; Print string at EDX
    
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
    
    ; Blocking input wait - gets ASCII code in AL
    call ReadChar
    
    ; Compare input and jump to appropriate label
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
    jmp MainMenu ; Loop if invalid input

StartGame:
    ; Game Setup Flow: Mode -> Color -> Name -> Init -> Play
    call SelectGameMode  
    call SelectTaxiColor 
    call GetPlayerName   
    call SetupGame
    call GameLoop        ; Enter the main game loop
    jmp MainMenu         ; Return to menu when game ends

ContinueGame:
    ; Try to load game state from file
    call LoadGameState   
    cmp eax, 0           ; Check return value (0 = Failure)
    je MainMenu          ; If load failed, go back to menu
    
    ; If load success, resume logic
    mov gameActive, 1
    mov gamePaused, 0
    call GetMseconds
    mov lastTick, eax    ; Reset time tracker so we don't count time spent in menu
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
    exit    ; Terminate process
main ENDP

; ------------------------------------------------------------------------
; PROCEDURE: SelectDifficulty
;    Allows user to choose Easy, Medium, or Hard mode.
;     Adjusts `baseDifficultySpeed`, which controls the delay between
;            frames. Lower delay = Faster game = Harder.
; ------------------------------------------------------------------------
SelectDifficulty PROC
    call Clrscr
    mov dh, 5
    mov dl, 30
    call Gotoxy
    mov edx, OFFSET strDiffTitle
    call WriteString
    
    ; Print options
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
    mov baseDifficultySpeed, 120 ; Higher delay = Slower game
    ret
    SetMed:
    mov difficultySetting, 2
    mov baseDifficultySpeed, 100 ; Standard delay
    ret
    SetHard:
    mov difficultySetting, 3
    mov baseDifficultySpeed, 80  ; Lower delay = Faster game
    ret
SelectDifficulty ENDP

; ------------------------------------------------------------------------
; PROCEDURE: SaveGameState
;    Dumps all critical game variables and arrays to a binary file.
;      Uses a "Magic Number" header first, then writes variables in a
;            specific order so LoadGameState knows exactly what to read.
; ------------------------------------------------------------------------
SaveGameState PROC
    mov edx, OFFSET saveFilename
    call CreateOutputFile
    cmp eax, INVALID_HANDLE_VALUE
    je SaveError
    
    mov fileHandle, eax
    
    ; Write Magic Number (Signature) first for validation
    mov saveSignature, SAVE_SIGNATURE
    mov edx, OFFSET saveSignature
    mov ecx, 4
    call WriteToFile
    
    ; Dump all core DWORD variables (4 bytes each)
    
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
    
    ; Save Arrays (Variable Size)
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
    
    ; Save Board Map
    mov edx, OFFSET board
    mov ecx, BOARD_AREA
    call WriteToFile
    
    mov eax, fileHandle
    call CloseFile
    
    ; Visual Feedback
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

; ------------------------------------------------------------------------
; PROCEDURE: LoadGameState
;    Reads game variables from binary file to restore state.
;      Checks for the Magic Number header first. If valid, it reads
;            memory blocks in the exact same order they were saved.
; ------------------------------------------------------------------------
LoadGameState PROC
    mov edx, OFFSET saveFilename
    call OpenInputFile
    cmp eax, INVALID_HANDLE_VALUE
    je LoadFail
    
    mov fileHandle, eax
    
    ; Read Magic Number to check if file is valid
    mov edx, OFFSET saveSignature
    mov ecx, 4
    call ReadFromFile
    mov eax, saveSignature
    cmp eax, SAVE_SIGNATURE
    jne BadSaveFile ; If signature is wrong, don't load garbage
    
    ; Read variables in exact order
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
    
    ; Restore Arrays
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
    
    ; Restore Board
    mov edx, OFFSET board
    mov ecx, BOARD_AREA
    call ReadFromFile
    
    mov eax, fileHandle
    call CloseFile
    mov eax, 1 ; Return 1 for Success
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
    mov eax, 0 ; Return 0 for Fail
    ret
LoadGameState ENDP

; ------------------------------------------------------------------------
; PROCEDURE: SelectGameMode
;    Menu for choosing Career, Time, or Endless mode.
; ------------------------------------------------------------------------
SelectGameMode PROC
    call Clrscr
    mov dh, 5
    mov dl, 30
    call Gotoxy
    mov edx, OFFSET strModeTitle
    call WriteString
    
    ; Display mode options
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
    
    ; Clear input buffer to prevent accidental selection
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
; PROCEDURE: ShowInstructions
;    Displays game rules and controls page.
; ------------------------------------------------------------------------
ShowInstructions PROC
    call Clrscr
    mov dh, 3
    mov dl, 30
    call Gotoxy
    mov edx, OFFSET strInstrTitle
    call WriteString
    
    ; Display lines sequentially
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
; PROCEDURE: GetPlayerName
;    Gets user input string for the leaderboard.
; ------------------------------------------------------------------------
GetPlayerName PROC
    call Clrscr
    mov dh, 10
    mov dl, 30
    call Gotoxy
    mov edx, OFFSET strEnterName
    call WriteString
    
    mov edx, OFFSET currentPlayerName
    mov ecx, 19 ; Max string length + null terminator
    call ReadString
    ret
GetPlayerName ENDP

; ------------------------------------------------------------------------
; PROCEDURE: SelectTaxiColor
;    Lets user pick Yellow (Fast/Risky) or Red (Slow/Safe) Taxi.
;      Sets `playerColor` for drawing and `taxiBaseSpeed` for logic.
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
    mov playerColor, 0E0h ; Yellow BG + Black Text (1110 0000)
    mov taxiBaseSpeed, 60 ; Faster base speed
    mov penaltyObstacle, 4
    mov penaltyCar, 2
    ret
    
    SetRed:
    mov playerColor, 0C0h ; Red BG + Black Text (1100 0000)
    mov taxiBaseSpeed, 100 ; Slower base speed
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
; PROCEDURE: SetupGame
;    Initializes a fresh game state.
;     1. Resets scores and timer.
;            2. Clears board array (fills with 0).
;            3. Randomly places Walls (1).
;            4. Ensures Player Start area is clear.
;            5. Spawns NPCs, Bonus items, and Passengers.
; ------------------------------------------------------------------------
SetupGame PROC
    ; Initialize game state variables
    mov playerScore, 0
    mov passengersDelivered, 0 
    mov level, 1
    mov gameTime, 60 
    call GetMseconds 
    mov lastTick, eax
    
    ; Apply base speed modified by difficulty
    mov eax, taxiBaseSpeed 
    ; Easy (+20ms delay), Hard (-20ms delay)
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
    
    ; Clear Board Memory
    mov ecx, BOARD_AREA
    mov edi, OFFSET board
    mov al, 0
    ; Loop to clear memory block 
    ClearLoop:
    mov [edi], al
    inc edi
    dec ecx
    jnz ClearLoop
    
    ; Generate Random Walls
    mov ecx, 60     
GenWalls:
    mov eax, BOARD_AREA
    call RandomRange
    mov edi, OFFSET board
    add edi, eax
    mov BYTE PTR [edi], 1   ; Set Wall (1)
    dec ecx
    jnz GenWalls
    
    ; Clear Start Area (Top-Left 3x3) to ensure player isn't stuck
    mov ecx, 3
    mov esi, 0
ClearRow:
    push ecx
    mov ecx, 3
    mov edi, 0
ClearCol:
    ; Calculate 1D index: (Y * Width) + X
    mov eax, esi
    mov ebx, BOARD_SIZE
    mul ebx 
    add eax, edi
    mov ebx, OFFSET board
    mov BYTE PTR [ebx + eax], 0 ; Set Road (0)
    inc edi
    dec ecx
    jnz ClearCol
    pop ecx
    inc esi
    dec ecx
    jnz ClearRow

    ; Reset Arrays
    mov ecx, MAX_PASSENGERS
    mov esi, 0
ClearPass:
    mov passActive[esi*4], 0 
    inc esi
    dec ecx
    jnz ClearPass

    ; Initialize Entities
    call InitNPCs
    call InitBonusItems 
    call InitPassengers 
    
    ; Drill paths to ensure map is solvable
    call EnsureAllPaths
    
    ret
SetupGame ENDP

; ------------------------------------------------------------------------
; PROCEDURE: InitBonusItems
; :   Spawns the initial set of Bonus Items.
; ------------------------------------------------------------------------
InitBonusItems PROC
    mov ecx, MAX_BONUS_ITEMS
    mov esi, 0
BonusLoop:
    mov bonusActive[esi*4], 0 ; Clear first
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
; PROCEDURE: SpawnOneBonus
;    Finds a random empty spot on the board for a bonus item.
; ------------------------------------------------------------------------
SpawnOneBonus PROC
FindBonusPos:
    mov eax, BOARD_AREA
    call RandomRange
    mov ebx, OFFSET board
    cmp BYTE PTR [ebx + eax], 0 ; Must be on Road
    jne FindBonusPos
    
    ; Convert 1D index to 2D coords (div width)
    mov edx, 0
    mov ecx, BOARD_SIZE
    div ecx
    mov bonusY[esi*4], eax
    mov bonusX[esi*4], edx
    mov bonusActive[esi*4], 1
    ret
SpawnOneBonus ENDP

; ------------------------------------------------------------------------
; PROCEDURE: CheckBonusCollection
;    Checks if player is on same tile as a bonus. Awards points.
; ------------------------------------------------------------------------
CheckBonusCollection PROC
    mov ecx, MAX_BONUS_ITEMS
    mov esi, 0
CheckLoop:
    cmp bonusActive[esi*4], 1
    jne NextBonus
    
    ; Check if player coordinates match bonus coordinates
    mov eax, playerX
    cmp eax, bonusX[esi*4]
    jne NextBonus
    mov eax, playerY
    cmp eax, bonusY[esi*4]
    jne NextBonus
    
    ; Collected!
    add playerScore, 10
    call Snd_GetPassenger ; Success sound
    call SpawnOneBonus    ; Respawn immediately
    
NextBonus:
    inc esi
    dec ecx
    jnz CheckLoop
    ret
CheckBonusCollection ENDP

; ------------------------------------------------------------------------
; PROCEDURE: InitPassengers
;    Spawns the initial required minimum passengers.
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
; PROCEDURE: RefillPassengers
;   Checks if active passengers < MIN_PASSENGERS and spawns more.
; ------------------------------------------------------------------------
RefillPassengers PROC
    pushad
    mov ecx, MAX_PASSENGERS
    mov esi, 0
    mov ebx, 0 ; Counter
CountLoop:
    cmp passActive[esi*4], 1 
    jne NextCount
    inc ebx
NextCount:
    inc esi
    dec ecx
    jnz CountLoop
    
    ; If count < MIN, spawn more
    cmp ebx, MIN_PASSENGERS
    jge RefillDone
    call SpawnOnePassenger
    
RefillDone:
    popad
    ret
RefillPassengers ENDP

; ------------------------------------------------------------------------
; PROCEDURE: SpawnOnePassenger
;    Finds an empty slot in passenger array and initializes pos/dest.
; ------------------------------------------------------------------------
SpawnOnePassenger PROC
    pushad
    mov ecx, MAX_PASSENGERS
    mov esi, 0
    ; Find unused slot in array
FindSlot:
    cmp passActive[esi*4], 0
    je FoundSlot
    inc esi
    dec ecx
    jnz FindSlot
    jmp SpawnDone ; Full
    
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
    
    mov passActive[esi*4], 1 ; Set Active
    
SpawnDone:
    popad
    ret
SpawnOnePassenger ENDP

; ------------------------------------------------------------------------
; PROCEDURE: EnsureAllPaths
;    Calls pathfinding drill for every active passenger.
; ------------------------------------------------------------------------
EnsureAllPaths PROC
    pushad
    mov ecx, MAX_PASSENGERS
    mov esi, 0
PathLoop:
    cmp passActive[esi*4], 1
    jne NextPath
    
    ; Path from Player -> Pickup
    mov eax, playerX
    mov ebx, playerY
    mov ecx, passX[esi*4]
    mov edx, passY[esi*4]
    call CarveRoute
    
    ; Path from Pickup -> Destination
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
; PROCEDURE: CarveRoute
;    Clears walls between two points to guarantee a path exists.
;      Drills horizontally then vertically to create an "L" shaped path.
; ------------------------------------------------------------------------
CarveRoute PROC
    pushad
DrillLoop:
    ; Simple X-first, then Y routing logic
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
    ; Set board[Y*Width+X] = 0 (Road)
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
    mov BYTE PTR [esi + edx], 0 ; Clear wall
    pop edx
    pop ebx
    pop eax
    jmp DrillLoop
DrillDone:
    popad
    ret
CarveRoute ENDP

; ------------------------------------------------------------------------
; PROCEDURE: InitNPCs
;    Randomly places NPCs on the board.
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
; PROCEDURE: GameLoop
;  The main execution loop. Handles Input, Updates, and Drawing.
; ------------------------------------------------------------------------
GameLoop PROC
    call Clrscr
LoopStart:
    cmp gameActive, 0
    je LoopEnd
    
    ; Non-blocking input check
    call ReadKey
    jz Update
    
    ; Check special keys
    cmp al, 's'
    je SaveGameAction
    cmp al, 'S'
    je SaveGameAction
    cmp al, 'p'
    je TogglePause
    cmp al, 'P'
    je TogglePause
    cmp al, KEY_ESC
    je QuitToMenu
    
    cmp gamePaused, 1
    je Update
    
    ; Movement keys
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
    
    ; Check Win Condition
    cmp currentMode, MODE_CAREER
    jne DrawOnly
    cmp playerScore, CAREER_TARGET
    jb DrawOnly
    
    mov gameActive, 0
    mov gameWon, 1
    jmp LoopEnd
    
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
; PROCEDURE: UpdateTimer
;   Decrements game clock every second. Ends game if time = 0.
; ------------------------------------------------------------------------
UpdateTimer PROC
    cmp currentMode, MODE_ENDLESS
    je NoTimeUpdate
    cmp currentMode, MODE_CAREER 
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
; PROCEDURE: TryMove
;    Validates player movement request (Boundaries, Walls).
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
    
    ; Check Walls
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
; PROCEDURE: PlayerAction
;  Handles Spacebar input for picking up or dropping off passengers.
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
    ; Absolute distance calculation
    mov ebx, 0
    mov eax, playerX
    sub eax, passX[esi*4]
    ; Get absolute value using manual bitwise logic (NOT + INC)
    cmp eax, 0
    jge SkipNegX
    not eax
    inc eax
SkipNegX:
    add ebx, eax
    
    mov eax, playerY
    sub eax, passY[esi*4]
    cmp eax, 0
    jge SkipNegY
    not eax
    inc eax
SkipNegY:
    add ebx, eax
    
    mov eax, ebx 
    pop edx
    pop ebx
    
    cmp eax, 1 ; Must be adjacent (dist=1)
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
    
    cmp currentMode, MODE_TIME
    jne CheckCareerWin
    add gameTime, 5
    
CheckCareerWin:
    inc passengersDelivered 
    call Snd_JobComplete 
    ret
NextDrop:
    inc esi
    dec ecx
    jnz DropLoop
ActionDone:
    ret
PlayerAction ENDP

; ------------------------------------------------------------------------
; PROCEDURE: CheckLevelUp
;   Increases difficulty every 2 passengers delivered.
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
    ; Optimization: Mult by 5 using shifts
    ; x * 5 = (x * 4) + x
    mov ecx, ebx   ; copy level
    shl ebx, 2     ; ebx = level * 4
    add ebx, ecx   ; ebx = level * 5
    
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
; PROCEDURE: UpdateNPCs
;   Moves traffic cars and handles bouncing off walls.
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
    je EndUpdateLoop ; Use trampoline for long jumps
    jmp NPCMoveLoop  
EndUpdateLoop:
    
    ; Increment global NPC timer
    
SkipNPCMove:
    ret
UpdateNPCs ENDP

; ------------------------------------------------------------------------
; PROCEDURE: CheckCollisions
;    Detects crashes between player and NPCs.
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
; PROCEDURE: DrawBoard
;    Renders the game grid, entities, and UI to the console.
;    Iterates through 20x20 grid. For each cell, checks if it contains
;            Player, NPC, Passenger, Bonus, or Wall. Draws colored char block.
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
    cmp currentMode, MODE_ENDLESS
    je DrawTimeDone
    cmp currentMode, MODE_CAREER 
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
    ; --- PRINT VERTICAL SEPARATOR START ---
    mov eax, 0F8h ; Gray on White
    call SetTextColor
    mov al, '|'
    call WriteChar
    ; -------------------------------------
ColLoop:
    cmp ecx, playerX
    jne CheckNPC
    cmp ebx, playerY
    jne CheckNPC
    mov eax, playerColor ; Use Block Background Color directly
    call SetTextColor
    mov al, 'T'
    call WriteChar
    jmp DrawSeparator
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
    mov eax, 090h   ; Light Blue Block (9), Black Text (0)
    call SetTextColor
    mov al, 'C'
    call WriteChar
    jmp DrawSeparator    
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
    mov eax, 0A0h   ; Green Block (A), Black Text (0)
    call SetTextColor
    mov al, 'P'
    call WriteChar
    jmp DrawSeparator
TryDrawDest:
    cmp passActive[esi*4], 2 
    jne NextPass
    cmp ecx, destX[esi*4]
    jne NextPass
    cmp ebx, destY[esi*4]
    jne NextPass
    pop ebx
    pop ecx
    mov eax, 0A0h ; Green Block for Destination
    call SetTextColor
    mov al, 'D'
    call WriteChar
    jmp DrawSeparator
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
    mov eax, 0D0h ; Magenta Block (D), Black Text (0)
    call SetTextColor
    mov al, 'B'
    call WriteChar
    jmp DrawSeparator
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
    pushad  ; SAVE ALL REGS
    
    ; Calculate Current Index
    mov eax, ebx ; Y
    mov ecx, BOARD_SIZE
    mul ecx
    add eax, [esp+24] ; Restore ECX (Col) from stack frame (pushad pushes 8 regs * 4 bytes = 32 bytes)
   ;push registers manually before check or re-calculate.
    ; stick to safe push/pop logic.
    popad
    
    push ecx
    push ebx
    
    mov eax, ebx
    push ecx
    mov ecx, BOARD_SIZE
    mul ecx
    pop ecx
    add eax, ecx ; EAX = Current Index
    
    mov esi, OFFSET board
    cmp BYTE PTR [esi + eax], 1
    jne DrawEmpty
    
    ; Draw Wall
    ; Check Next Cell for Fusion
    mov dl, 0 ; Flag for fusion
    
    ; Boundary check: if last col, no fusion
    mov ebx, ecx
    inc ebx
    cmp ebx, BOARD_SIZE
    jge NoFusion
    
    ; Check next cell content
    cmp BYTE PTR [esi + eax + 1], 1
    jne NoFusion
    mov dl, 1 ; Fusion active
    
NoFusion:
    mov eax, 0 ; Black Block
    call SetTextColor
    mov al, 0DBh
    call WriteChar
    
    ; Draw Separator or Fuse?
    cmp dl, 1
    je DrawFusedSep
    
    ; Normal Separator
    mov eax, 0F8h 
    call SetTextColor
    mov al, '|'
    call WriteChar
    jmp RestoreWallRegs
    
DrawFusedSep:
    mov eax, 0 ; Black Block for Separator
    call SetTextColor
    mov al, 0DBh
    call WriteChar
    jmp RestoreWallRegs
    
DrawEmpty:
    mov eax, 0F0h ; White Strip
    call SetTextColor
    mov al, ' '
    call WriteChar
    
    ; Normal Separator
    mov eax, 0F8h
    call SetTextColor
    mov al, '|'
    call WriteChar

RestoreWallRegs:
    pop ebx
    pop ecx
    jmp NextCell

DrawSeparator:
    mov eax, 0F8h
    call SetTextColor
    mov al, '|'
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
    ; Standard stdcall convention
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

; ------------------------------------------------------------------------
; PROCEDURE: SaveHighscores
;    Writes top 10 scores to file.
; ------------------------------------------------------------------------
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

; ------------------------------------------------------------------------
; PROCEDURE: CheckHighscore
;    Determines if score qualifies for leaderboard and inserts it.
; ------------------------------------------------------------------------
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

; ------------------------------------------------------------------------
; PROCEDURE: ShowGameOver
;    Displays final score and checks high scores logic.
; ------------------------------------------------------------------------
ShowGameOver PROC
    call Clrscr
    mov dh, 10
    mov dl, 30
    call Gotoxy
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
    ; Wait here so user sees result before High Score check
    mov dh, 13
    mov dl, 30
    call Gotoxy
    mov edx, OFFSET strContinueMsg
    call WriteString
    call ReadChar
    call CheckHighscore
    mov dh, 15
    mov dl, 30
    call Gotoxy
    mov edx, OFFSET strPressKey
    call WriteString
    call ReadChar
    ret
ShowGameOver ENDP

END main
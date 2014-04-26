\ LOCALS.4TH  -  Local variable extensions to Forth/2     3/14/93 bbm
\ Copyright (c) 1993  BLUE STAR SYSTEMS
\
\
\ Locals enhance Forth by reducing the complexity of stack operations,
\   and allow you to assign descriptive labels to the numbers passed 
\   to the word on the stack.
\
\ Usage:
\
\ : WordName  LOCALS|  local1  local2  local3  ...  local8 |
\                      ...  local1  ...
\                      ...  local2  ...  local3  ... etc.  ;
\
\ The entire  LOCALS| ... |  must be on the same line.
\
\
\ Example:
\
\ : DIGITS    LOCALS|  digit1 digit2 digit3 |
\
\                      digit1  100 *
\                      digit2   10 *
\                      digit3  + + ;   \ turns  1 2 3 DIGITS  into  123


FORTH ONLY
DECIMAL

: LOCALS.4TH ;

36 CONSTANT NAME_LENGTH    \ Length of names as stored in dictionary
 8 CONSTANT #LOCALS_MAX    \ Maximum number of LOCALS
   VARIABLE #LOCALS
   VARIABLE LOCAL_NAMES_BUF   #LOCALS_MAX NAME_LENGTH * ALLOT


: !LOCALBUF ( " -- )  LOCAL_NAMES_BUF
                      #LOCALS @ NAME_LENGTH *  +  "MOVE  1 #LOCALS +! ;

: @LOCALBUF ( n -- " ) NAME_LENGTH *  LOCAL_NAMES_BUF + ;

USER LOCAL_BASE  #LOCALS_MAX CELLS UDP +!


VOCABULARY LOCALS  LOCALS DEFINITIONS

: LOCAL8  LOCAL_BASE 28 + @ ;
: LOCAL7  LOCAL_BASE 24 + @ ;
: LOCAL6  LOCAL_BASE 20 + @ ;
: LOCAL5  LOCAL_BASE 16 + @ ;
: LOCAL4  LOCAL_BASE 12 + @ ;
: LOCAL3  LOCAL_BASE  8 + @ ;
: LOCAL2  LOCAL_BASE  4 + @ ;
: LOCAL1  LOCAL_BASE      @ ;

FORTH ONLY

: !LOCALS  SP@  LOCAL_BASE  I @ CELLS CMOVE
           I @ DROPS  R> CELL+ >R ;


: LOCALS|  [COMPILE] LOCALS   ?COMPILE   0 #LOCALS !
           LOCAL_NAMES_BUF  #LOCALS_MAX NAME_LENGTH *  0 FILL
           BEGIN
              BL WORD
              DUP " ;" =" ABORT" Missing final | after locals."
              DUP @    0= ABORT" Missing final | on same line as LOCALS|"
              DUP " |" =" NOT WHILE  !LOCALBUF  
              #Locals @  #LOCALS_MAX > ABORT" Too many locals"
           REPEAT DROP
           CONTEXT @  +VLINK @
           #LOCALS @ 0 DO
              #LOCALS @ 1- I - @LOCALBUF  OVER NFA NAME_LENGTH CMOVE
           @ LOOP  DROP
           COMPILE !LOCALS  #LOCALS @ , ;    IMMEDIATE

\ REMOVEVOC  removes the top vocabulary from CONTEXT:  LOCALS RemoveVoc
: REMOVEVOC ( -- ) CONTEXT CELL+  CONTEXT  ContextSize 1- CELLS CMOVE ;


\ Redefine  ;  to hide the  LOCALS  so they don't interfere later
: ;  #LOCALS @ IF  POSTPONE LOCALS  REMOVEVOC   0 #LOCALS !
             THEN  POSTPONE ;  ;    IMMEDIATE


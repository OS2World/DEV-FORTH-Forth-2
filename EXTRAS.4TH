\ Extra Forth Definitions for Forth/2            3/08/93 bbm
\ Copyright (c) 1993  BLUE STAR SYSTEMS


1 constant IMMEDIATE_BIT
2 constant COMPILE_ONLY_BIT
4 constant HIDDEN_BIT

: HIDDEN  ( -- )  \ Marks latest word as hidden from WORDS listing
          Current @ +VLink @  FFA  DUP @  HIDDEN_BIT OR  SWAP ! ;

: IMMEDIATE? ( lfa -- f )  FFA @  IMMEDIATE_BIT AND ;
: HIDDEN?    ( lfa -- f )  FFA @  HIDDEN_BIT    AND ;


\ For TO variables or VALUE's

: VALUE ( n -- )  INTEGER  HERE CELL - ! ;    \ For compatibility
: !>             TO ;
: +>            +TO ;
: INCR>       1 +TO ;
: DECR>      -1 +TO ;
: ON>       TRUE TO ;
: OFF>     FALSE TO ;



-1 constant ?DOFlag       \ Flag signals a ?DO versus a DO
: DoCheck  2DUP > ;       \ Check if DO can be called
: ?DOLoop  SP@ CSP @ U< IF  DUP ?DOFlag <> IF 0 THEN
           ELSE  0  THEN ;

: ?DO   POSTPONE DoCheck  POSTPONE IF  ?DOFlag
        POSTPONE DO ;  IMMEDIATE

: LOOP   POSTPONE LOOP
         ?DOLoop IF          \ Only if ?DO was issued
             POSTPONE ELSE   POSTPONE 2DROP   POSTPONE THEN
         THEN ;  IMMEDIATE

: +LOOP  POSTPONE +LOOP      \ ?DO will not work with a negative index
         ?DOLoop IF          \ Only if ?DO was issued
             POSTPONE ELSE   POSTPONE 2DROP   POSTPONE THEN
         THEN ;  IMMEDIATE


\ REMOVEVOC  removes the top vocabulary from CONTEXT:  LOCALS RemoveVoc
: REMOVEVOC ( -- ) CONTEXT CELL+  CONTEXT  ContextSize 1- CELLS CMOVE ;


\ Planned support:

: .VOCS  ( -- )  ( Show names of all vocabularies currently defined ) ;


: COMMENT:  ( like     0 #if   )  ;
: COMMENT;  ( like  \  #endif  )  ; 


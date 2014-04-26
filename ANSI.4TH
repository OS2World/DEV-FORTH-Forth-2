\ ANSI Escape Sequence Drivers for Forth/2                01/12/93 BBM
\ Copyright (c) 1993  BLUE STAR SYSTEMS


: ANSI. ( n -- ) ABS <# #S #> TYPE ;
: ESCAPE         27 EMIT ;
: XY  ( row col -- ) ESCAPE ." ["  SWAP ANSI.  59 EMIT  ANSI.  72 EMIT ;

: +XY ( +row +col ) ?DUP IF  ESCAPE ." ["  DUP  ANSI.  0 > 68 + EMIT  THEN
                    ?DUP IF  ESCAPE ." ["  DUP  ANSI.  0 < 66 + EMIT  THEN ;

: CEOL ( Clear to End Of Line ) ESCAPE  ." [K" ;

: IS  CONSTANT ;

1 IS BOLD     ( Attributes. )
2 IS DIM
3 IS ITALIC
5 IS BLINK
7 IS REV
8 IS BLANK

0 IS BLACK    ( Text and background colors. )
1 IS RED
2 IS GREEN
3 IS YELLOW
4 IS BLUE
5 IS MAGNETA
6 IS CYAN
7 IS WHITE

: ATTR   ( attribute ) ESCAPE ." [" ANSI. ." m" ;  \ Ex:  BOLD ATTR
: TEXT       ( color ) 30 + ATTR ;                 \ Ex:  YELLOW TEXT
: BACKGROUND ( color ) 40 + ATTR ;                 \ Ex:  BLUE BACKGROUND

: SAVE-CURSOR   ESCAPE  ." [s" ;  \ Save    cursor position
: REST-CURSOR   ESCAPE  ." [u" ;  \ Restore cursor position

\ Example:
\
\  RED TEXT   BOLD   BLACK BACKGROUND



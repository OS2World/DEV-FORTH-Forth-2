\ BLOCKS.4TH  -  Preliminary BLOCK File Support for Forth/2   2/13/93 bbm
\ Copyright (c) 1993  BLUE STAR SYSTEMS
\
\ This is NOT a complete BLOCK file support system, it's just something
\  to help people to view and load BLOCK files.  Updating blocks is not
\  implemented, although it would be fairly easy to add.

ECHO ON
\ Usage:  0" BLKFILE.BLK" OpenBlock
\
\ Then:   1 L        Shows screen 1
\         LN         Shows next screen
\         LB         Shows previous screen
\         LL         Shows current screen
\         10 FH L    Shows screen 10 screens From Here
\         MaxBlk @   Highest block number
\         2 Load     Loads (compiles) screen 2
\         LO         Load current screen
\         2 6 THRU   Loads screens 2 through 6
\         10 Block   Loads block 10, returns address of block
\         2 8 Index  Shows top lines of screens 2 through 8
\
\         2 6 ConvertTo" NewFile.4TH"  Converts block file to DOS text file
\
\         CloseBlock  Closes current block file
ECHO OFF

DECIMAL
FORTH Only DEFINITIONS
SYSTEM

: BLOCKS.4TH ;

1024 Constant 1K          \ Length of one block or screen
  64 Constant C/L         \ Characters per Line of blocks
  16 Constant #BlkLines   \ Number of lines per block

Variable BlkHandle    0 BlkHandle !
Variable BlkFileSize
Variable MaxBlk       0 MaxBlk !
Variable SCR

: FSize ( handle -- size )    >R  BlkFileSize  2  0  R> SYS$SEEK SYSCALL
                              5 Drops   BlkFileSize @ ;

: OpenBlock ( 0name -- )  BlkHandle @ ?DUP IF  Close  THEN
                          Open  BlkHandle !  1 SCR !
                          BlkHandle @ FSize  1K /  1- MaxBlk ! ;

: CloseBlock ( -- )       BlkHandle @ Close  0 BlkHandle !  0 MaxBlk ! ;

: BLOCK ( n -- addr )     1K *  BlkHandle @ FSeek  ABORT" Load error"
                          BlkHandle @  FBuffer  1K  FRead  FBuffer ;

: LOAD  ( n -- )
        TIB @  #TIB @
          ROT BLOCK TIB !  1K #TIB !
          INTERPRET
        #TIB !  TIB ! ;


: <LINE> ( line# scr# -- addr len ) Block  swap C/L *  +  C/L ;


Variable ?CLS  1 ?CLS !  \ Determine if you want to CLS or scroll new screen

: LIST ( n -- ) DUP SCR !  
                ?CLS @ IF  CLS  ELSE  CR  THEN   DUP ." SCR " .  BLOCK
                #BlkLines 0 DO  
                    CR  3 SPACES  DUP C/L -TRAILING Type  
                C/L +  LOOP  DROP ;

: L     ( n -- ) LIST ;
: LL    ( -- ) SCR @ LIST ;
: LN    ( -- ) SCR @  MaxBlk @ MIN  1+ LIST ;
: LB    ( -- ) SCR @         0 MAX  1- LIST ;
: LO    ( -- ) SCR @ LOAD ;
: S     ( -- scr )  SCR @ ;

: FH    ( n -- SCR+n ) SCR @ + ;
: INDEX ( n1 n2 -- )  SWAP DO  CR  ." SCR " I .
                      I BLOCK C/L -TRAILING TYPE  LOOP ;

: -->  ( -- ) 1 SCR +!  SCR @ LOAD ;  IMMEDIATE


Create CrLfStr    2 ,  13 C, 10 C,
Create CntrlZStr  1 ,  26 C,

\ ConvertTo" converts a range of screens from a block file
\            into a DOS text (sequential) file.

: ConvertTo" ( first_scr last_scr ConvertTo" Filename.4TH" -- )
             POSTPONE 0"  Open  -ROT
             1+ swap DO
               #BlkLines 0 DO
                   dup  I J <LINE> -Trailing FWrite
                   dup  CrLfStr   @+         FWrite
               LOOP
                   dup  CrLfStr   @+         FWrite
             LOOP  dup  CntrlZStr @+         FWrite  close ;

\ Example:   0" OldStuff.BLK" OpenBlock
\
\            0 30  ConvertTo" NewStuff.4TH"



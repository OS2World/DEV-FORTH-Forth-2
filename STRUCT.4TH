\ STRUCT.4TH  Arrays Structures Memory management Words  2/08/93 bbm
\ for Forth/2
\ Copyright <c> 1993  BLUE STAR SYSTEMS

Echo @  Echo ON
\
\ These words let you create arrays of numbers, structures which group
\   various types of data into one logical entity, and arrays of
\   structures.
Echo !


\ ARRAYS

: CARRAY ( n <name>-- Does: i -- n )   CREATE  HERE  OVER ALLOT
         SWAP 0 FILL  DOES>  + ;

: ARRAY  ( n <name>-- Does: i -- n )   CREATE  HERE  OVER CELLS ALLOT
         SWAP 0 FILL  DOES>  SWAP CELLS + ;

\ Example
\
\ 100 CARRAY XList
\      5 XList C@ .    \ Print value of fifth  element
\ 130 35 XList C!      \ Store a 130 into 35th element
\
\ Same for ARRAY, except use the 32-bit @'s and !'s



( Memory Structure Definition Creation )

: STRUCT      CREATE  0 ( not used ) , HERE      \ Creates structure def.
                      0 ( size     ) , 0  
              DOES>  CREATE  CELL+ @ ALLOT ;
: FIELD       CREATE OVER ( offset ) ,           \ Create byte-length field
                      DUP ( size   ) , +  
              DOES>  @ + ;
: ENDSTRUCT   SWAP ! ;                           \ Stores structure size

\ : SIZEOF      '  PFA 9 + @ ;  IMMEDIATE          \ Size of STRUCT or FIELD

\ : NEST        POSTPONE SIZEOF  FIELD ;           \ Use to nest structures

STRUCT   DateTime
  1 Field Hours
  1 Field Minutes
  1 Field Seconds
  1 Field Hundredths
  1 Field Day
  1 Field Month
  2 Field Year
  1 Field TimeZone
  1 Field DayOfWeek
EndStruct

DateTime  CurrentTimeStamp

: GetTime CurrentTimeStamp Sys$GetDateTime Syscall drop drop ;

: ShowTime GetTime ."Current Hour = " Hours DateTime c@ . cr ;
  
\ Example 1 - Date Structure for holding system date and time
\
\ STRUCT DateTimeStruct
\    1 Field Hour
\    1 Field Minute
\    1 Field Seconds
\    1 Field Hundreths
\    1 Field Day
\    1 Field Month
\    2 Field Year
\    2 Field TimeZone
\ ENDSTRUCT
\
\
\ Usage Example 
\
\  DateTimeStruct BeginDate      \ Allocate memory for structure
\
\     4 BeginDate Month C!
\     1 BeginDate Day   C!
\  1993 BeginDate Year  W!
\
\  BeginDate SYS$GetDateTime SYSCALL 2DROP
\
\  : DATE.  DUP Day C@ 1 .R  ." /"  DUP Month C@ 2 .R ." /"  Year W@ U. ;
\



( TO Variable Memory Structure Field Creation )

: C+!       ( b addr -- )   TUCK C@ + SWAP C! ;
: <CTODOES> ( addr -- ? )   %TO @ 0 = IF  C@  ELSE
                            %TO @ 0 > IF  C!  ELSE  C+!  THEN THEN
                            0 %TO ! ;
: CHAR        CREATE DUP  , 1  DUP , +  DOES>       @ + <CTODOES> ;

: W+!       ( w addr -- )   TUCK W@ + SWAP W! ;
: <WTODOES> ( addr -- ? )   %TO @ 0 = IF  W@  ELSE
                            %TO @ 0 > IF  W!  ELSE  W+!  THEN THEN
                            0 %TO ! ;
: SHORT       CREATE DUP  , 2  DUP , +  DOES>       @ + <WTODOES> ;

: INT         CREATE DUP  , CELL  DUP , +  DOES>       @ +  <TODOES> ;
: INT[]       CREATE OVER , CELLS DUP , +  DOES> @ SWAP CELLS + + <TODOES> ;

\ : ARRAYOF   ( size struct_name-- )  POSTPONE SizeOf
\               CREATE  DUP ,  *  HERE OVER  ALLOT
\               SWAP 0 FILL  DOES>  TUCK @ * + CELL+ ;


\ Example 2 - Data Structures using TO variables
\
\ You can intermix any of:
\
\    FIELD  CHAR  SHORT  INT  and INT[]
\
\ in the same structure definition.  To add to a STRUCT definition use:
\
\ size FIELD <fieldname>  creates a size-byte length field named <fieldname>
\      CHAR  <varname>    creates a byte   TO variable
\      SHORT <varname>    creates a 2-byte TO variable
\      INT   <varname>    creates a 4-byte TO variable
\ size INT[] <varname>    creates an array of 4-byte TO variables
\
\
\ To use the fields, precede each field name by the starting address of the
\ structure.
\
\
\ STRUCT DateTimeStruct
\       CHAR Hour
\       CHAR Minute
\       CHAR Seconds
\       CHAR Hundreths
\       CHAR Day
\       CHAR Month
\      SHORT Year
\      SHORT TimeZone
\ ENDSTRUCT
\
\ DateTimeStruct BeginDate      \ Allocate memory for structure
\
\    4 TO BeginDate Month       \ Store numbers into fields
\    1 TO BeginDate Day
\ 1993 TO BeginDate Year
\
\ BeginDate SYS$GetDateTime SYSCALL 2DROP   \ Pass structure to OS/2 call
\
\ : DATE. ( DateTimeStruct -- )   \ Fetch field contents
\         DUP Month 1 .R  ." /"
\         DUP Day   2 .R  ." /"
\             Year     U. ;


\ Example 3 - Mixed and Nested Structure
\
\ STRUCT Transaction
\      INT TransID
\     NEST DateTimeStruct TransDate     \ Nests DateTime structure
\     CHAR TransType
\ 14 INT[] Hours[]
\ 80 FIELD TransDesc
\ ENDSTRUCT
\
\
\ Transaction Trans1               \ Create transaction structure
\
\ 1000  TO  Trans1 TransID         \ Store 100 into TransID
\
\ Trans1 TransType EMIT            \ Emits the Transaction Type
\
\ 1993  TO  Trans1 TransDate Year  \ Set Transaction date to 1993
\
\   81  TO  Trans1 5 Hours[]       \ Store 81 into  Hours[5]  of Trans1
\
\ Trans1 5 Hours[] .               \ Display  Hours[5]  of Trans1
\
\ " Overtime OK'd by M.E.D."  Trans1 TransDesc "MOVE  \ Store to TransDesc
\
\ Trans1 TransDesc ".              \ Types contents of TransDesc


\ Example 4 - Creating an array of structures
\
\
\ 50 ArrayOf Transaction Trans[]      \ Create array of 50 transactions
\
\ 50 0 DO
\    I 100 +  TO  I Trans[] TransID        \ Store unique ID's into TransID's
\    1993     TO  I Trans[] TransDate Year \ Store 1993 into year
\    40       TO  I Trans[] 0 Hours[]      \ Store 40 into Hours[0]
\ LOOP
\
\ 23 Trans[] TransDate Year .      \ Show transaction 23's year
\



\ THREADS.4TH  -  Thread creation under Forth/2   03/18/93
\ Copyright (c) 1993,1994  BLUE STAR SYSTEMS
\
\ These are some preliminary words to run threads under Forth/2 using
\ the OS/2 function CreateThread.  Any output they do shows up in the
\ Forth/2 screen, but the output is harmless.
\
\ You can THREAD just about any word which operates independently and
\ does not require any stack parameters.
\
\ Warning: The thread does not start immediately, so be carefull of any
\          variables used to pass parameters to the new thread.
\
\  i.e.    1 alarm 2 alarm 10 alarm
\
\  will PROBABLY not result in the correct results, but rather all
\  three alarms going off in 10 seconds

decimal

variable ThreadInfo   \ Information to be passed to thread, USER area
       4 allot        \   and execution address of thread

variable ThreadID
variable ThreadArg              \ Allot parameter space after this
8192 constant ThreadStackSize
variable ThreadStack  ThreadStackSize allot

: sleep  ( seconds -- )  1000 * MS ;

: StartThread ( code_addr -- )
    ThreadInfo CELL+ !  'USER @ ThreadInfo !
              ThreadInfo ThreadArg !
              ThreadStackSize
              0                \ Flags: 0=Start now, 1=Start suspended
              ThreadArg
              ['] ThreadProc
              ThreadID           SYS$CREATETHREAD
                                 SYSCALL
              6 DROPS ;

: KillThread  ( pid -- )  SYS$KillThread SYSCALL 2drop ;

\ THREAD   Usage:  THREAD <name>  starts <name> running as a separate thread

: THREAD   State @ 0= If
             ' StartThread
           Else
             ' Postpone Literal
             Postpone StartThread
           Then
           ; IMMEDIATE

\ Examples

: Bunny            5 sleep ." It keeps going, and going..."
           50 0 do 2 sleep cr   ." and going, and going..."
                   loop ;

variable TimeLength

: Timer ( -- )      TimeLength @ sleep  ." It's time! " ;

: Alarm ( secs -- ) TimeLength ! Thread Timer ;

\ Try  THREAD bunny    or  10 Alarm    Do a bunch of them!


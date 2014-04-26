	       Title   _FORTH_32 '32 BIT FORTH FOR OS/2'
;
; FORTH/2 -- Copyright(C) 1992-1994 BLUE STAR SYSTEMS, all rights reserved
; Produced in the United States of America
;
;   This software is furnished under a license agreement or nondisclosure
; agreement.  The software may be used or copied only in accordance with
; the terms of the agreement. No part of this program may be reproduced
; or transmitted in any form or by any means, electronic or mechanical,
; including photo-copying and recording, for any purpose without the
; express written permission of the author.
;
;   The following paragraph does not apply in the United Kingdom or any
; country where such provisions are inconsistent with local law:
;   BLUE STAR SYSTEMS OFFERS THIS PROGRAM "AS IS" WITHOUT WARRANTY OF
; ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE
; IMPLIED WARRANTIES OF MERCHANTABILITY OR FITNESS FOR A PARTICULAR PURPOSE.
; Some states do not allow disclaimer of express or implied warranties in
; certain transactions, therefore, this statement may not apply to you.
;
; BLUE STAR SYSTEMS may have patents or pending patent applications covering
; the subject matter in this program. The furnishing of this program does
; not give you any license to these patents. You can send license inquiries,
; to any of the following:
;
;   US Mail: BLUE STAR SYSTEMS
;            PO Box 4043
;            Hammond, Indiana 46324
;
;   Email:   ka9dgx@chinet.chinet.com
;            ka9dgx@interaccess.com
;
;   Voice:   (219) 844-7325    { 10:00 AM - 10:00 PM CDST ONLY!!! }
;
; Note: 16 Bit calls EAT STACK PARAMS
;       32 Bit calls LEAVE stack params
;
; Thanks to Larry Bank for his sample code in VIO32.ASM
; Thanks to Brian Mathewson for his $$$ and suggestions, and CODE
; Thanks to Michael Thompson (tommy@msc.cornell.edu) for PORTIO.ASM
;
	      .386
	      .model   flat,syscall,os_os2

	      .code

Reserve_Size   =       010000h ; Reserve 64k Of Memory for Dictionary

STACK_SIZE       = 1000h   ; Memory reserved for stack
STACK_UNDERFLOW  = 1000h
RSTACK_SIZE      = 1000h   ; Return stack size for threads

	       EXTRN   Dos32AllocMem:Near,Dos32Read:Near
	       EXTRN   Dos32Beep:Near,Dos32SetFilePtr:Near
	       EXTRN   Dos32CallNPipe:Near,Dos32ConnectNPipe:Near
	       EXTRN   Dos32CreateNPipe:Near
	       EXTRN   Dos32CreateThread:Near
	       EXTRN   Dos32DevIOCtl:Near
	       EXTRN   Dos32DisConnectNPipe:Near
	       EXTRN   Dos32ExecPgm:Near
	       EXTRN   Dos32Exit:Near
	       EXTRN   Dos32GetDateTime:Near
               EXTRN   Dos32GetInfoBlocks:Near
	       EXTRN   Dos32KillProcess:Near
	       EXTRN   Dos32KillThread:Near
	       EXTRN   Dos32LoadModule:Near,Dos32FreeModule:Near
	       EXTRN   Dos32Open:Near,Dos32Close:Near
	       EXTRN   Dos32PeekNPipe:Near
	       EXTRN   Dos32QueryModuleHandle:Near
	       EXTRN   Dos32QueryModuleName:Near
	       EXTRN   Dos32QueryNPHState:Near,Dos32QueryNPipeInfo:Near
	       EXTRN   Dos32QueryProcAddr:Near
	       EXTRN   Dos32QueryProcType:Near
	       EXTRN   Dos32ResumeThread:Near
	       EXTRN   Dos32SetNPHState:Near
	       EXTRN   Dos32Sleep:Near,Dos32StartSession:Near
	       EXTRN   Dos32SuspendThread:Near
	       EXTRN   Dos32TransactNPipe:Near
	       EXTRN   Dos32WaitChild:Near
	       EXTRN   Dos32WaitNPipe:Near
	       EXTRN   Dos32WaitThread:Near
	       EXTRN   Dos32Write:Near


	       EXTRN   DosFlatToSel:near,DosSelToFlat:near
	       EXTRN   KbdCharIn:far16,VIOwrtTTY:far16
	       EXTRN   Dos32Shutdown:Near

	       EXTRN   @inp:far16,@outp:far16

PULLFORTH      MACRO
	       mov     eax,[ebx]
	       add     ebx,4
	       ENDM

PUSHFORTH      MACRO
	       sub     ebx,4
	       mov     [ebx],eax
	       ENDM

COMPILES       MACRO   varg:VARARG
		 FOR     arg, <varg>
		   mov     al,arg
		   stosb
		 ENDM
	       ENDM

UREG           EQU  EBP                 ; USER Variable register
UserAreaSize   EQU  400h                ; Size of user variable area
USER           EQU  -U_UserVPtr [UREG]  ; USER variable
; USER         EQU                      ; Use to disable USER variables

VocLinkOffset  =       4        ; Offset from vocabulary of link
ContextSize    =       16       ; Size of Context buffer

	      .stack   8192
	      .data

;
; Data returned from getkey...
;
ascii         db     0
scancode      db     0
status        db     0
reserved      db     0
shift_state   dw     0
time_stamp    dd     0
;

;---------------- I/O DOS Calls Only---------------
stdin          equ   0
stdout         equ   1
stderr         equ   2

;---------------- Useful ---------------
cr             equ   0dh
lf             equ   0ah
crlf           equ   0dh,0ah   ;cr+lf
BEL            equ   07h
NULL           equ   0000h

SavedESP       dd    ?

Environment    dd    ?
CommandLine    dd    ?
FooBar         dd    ?


;********* Forth REGISTER USE:
;
;  EBX - Numeric Stack pointer, growing downward from FStackBase
;
;  EDI - Current CODE generating address
;
;  EBP - Pointer to USER variable block ( one block per thread! )
;
;  All other variables my be used, and trashed, at ANY time....!
;

Message        MACRO  name:REQ,string:VARARG

&name&msg      dd     @f-($+4)  ;; define a DWORD which gives size

	       FOR arg, <string>
		 DB    arg             ;; Store the byte(s)
	       ENDM
@@:
ENDM


MESSAGE Welcome,   "FORTH/2 -- Version 0.40 áeta"

MESSAGE CopyRight, "Copyright(C) 1992-1994 - BLUE STAR SYSTEMS, all rights reserved",CrLf,"Produced in the United States of America",CrLf,CrLf

MESSAGE Greet,     "Type BYE to exit, WORDS to see word list.",CrLf

MESSAGE Break,     "Breakpoint Encountered! ",CrLf

MESSAGE StackOver, "Stack Overflow!",07h,CrLf

MESSAGE StackUnder,"Stack Underflow!",07h,CrLf

MESSAGE IOerror,   "I/O Error #"

MESSAGE StackLoad, "FORTH.INI should not change the stack",CrLf

MESSAGE Prompt,    "Ok: "

MESSAGE CompileOnly "Not in compile mode!",CrLf

MESSAGE Semicolon  "ERROR: Semicolon was expected",CrLf

MESSAGE LineNum    "at line number: "

MESSAGE WHAT1      "What does ",022h
MESSAGE WHAT2      022h," mean? (type BYE to exit to OS/2) ",CrLf

MESSAGE DivByZero  "DIVISION BY ZERO ATTEMPTED!",CrLf

MESSAGE NotCompiling "Only in compile mode!",CrLf

MESSAGE Huh        " ?",CrLf

MESSAGE NotCreateWord "not a CREATE'd word!",CrLf

MESSAGE Register   "   EDI      ESI      EBP      ESP      EBX      EDX      ECX      EAX",CrLf

MESSAGE Pause      "--PRESS ANY KEY--",Cr

MESSAGE PauseClear "                 ",Cr

CrLfStr        dd     2
	       db     0dh,0ah

CrStr          dd     1
	       db     0dh

SpStr          dd     1
	       db     20h

UpperCaseTable db     000h,001h,002h,003h,004h,005h,006h,007h
	       db     008h,009h,00ah,00bh,00ch,00dh,00eh,00fh
	       db     010h,011h,012h,013h,014h,015h,016h,017h
	       db     018h,019h,01ah,01bh,01ch,01dh,01eh,01fh
	       db     020h,021h,022h,023h,024h,025h,026h,027h
	       db     028h,029h,02ah,02bh,02ch,02dh,02eh,02fh
	       db     030h,031h,032h,033h,034h,035h,036h,037h
	       db     038h,039h,03ah,03bh,03ch,03dh,03eh,03fh
	       db     040h,041h,042h,043h,044h,045h,046h,047h
	       db     048h,049h,04ah,04bh,04ch,04dh,04eh,04fh
	       db     050h,051h,052h,053h,054h,055h,056h,057h
	       db     058h,059h,05ah,05bh,05ch,05dh,05eh,05fh
	       db     060h,041h,042h,043h,044h,045h,046h,047h
	       db     048h,049h,04ah,04bh,04ch,04dh,04eh,04fh
	       db     050h,051h,052h,053h,054h,055h,056h,057h
	       db     058h,059h,05ah,07bh,07ch,07dh,07eh,07fh
	       db     080h,081h,082h,083h,084h,085h,086h,087h
	       db     088h,089h,08ah,08bh,08ch,08dh,08eh,08fh
	       db     090h,091h,092h,093h,094h,095h,096h,097h
	       db     098h,099h,09ah,09bh,09ch,09dh,09eh,09fh
	       db     0a0h,0a1h,0a2h,0a3h,0a4h,0a5h,0a6h,0a7h
	       db     0a8h,0a9h,0aah,0abh,0ach,0adh,0aeh,0afh
	       db     0b0h,0b1h,0b2h,0b3h,0b4h,0b5h,0b6h,0b7h
	       db     0b8h,0b9h,0bah,0bbh,0bch,0bdh,0beh,0bfh
	       db     0c0h,0c1h,0c2h,0c3h,0c4h,0c5h,0c6h,0c7h
	       db     0c8h,0c9h,0cah,0cbh,0cch,0cdh,0ceh,0cfh
	       db     0d0h,0d1h,0d2h,0d3h,0d4h,0d5h,0d6h,0d7h
	       db     0d8h,0d9h,0dah,0dbh,0dch,0ddh,0deh,0dfh
	       db     0e0h,0e1h,0e2h,0e3h,0e4h,0e5h,0e6h,0e7h
	       db     0e8h,0e9h,0eah,0ebh,0ech,0edh,0eeh,0efh
	       db     0f0h,0f1h,0f2h,0f3h,0f4h,0f5h,0f6h,0f7h
	       db     0f8h,0f9h,0fah,0fbh,0fch,0fdh,0feh,0ffh

WordScanTable  db     020h,020h,020h,020h,020h,020h,020h,020h
	       db     020h,020h,020h,020h,020h,020h,020h,020h
	       db     020h,020h,020h,020h,020h,020h,020h,020h
	       db     020h,020h,020h,020h,020h,020h,020h,020h
	       db     020h,021h,022h,023h,024h,025h,026h,027h
	       db     028h,029h,02ah,02bh,02ch,02dh,02eh,02fh
	       db     030h,031h,032h,033h,034h,035h,036h,037h
	       db     038h,039h,03ah,03bh,03ch,03dh,03eh,03fh
	       db     040h,041h,042h,043h,044h,045h,046h,047h
	       db     048h,049h,04ah,04bh,04ch,04dh,04eh,04fh
	       db     050h,051h,052h,053h,054h,055h,056h,057h
	       db     058h,059h,05ah,05bh,05ch,05dh,05eh,05fh
	       db     060h,061h,062h,063h,064h,065h,066h,067h
	       db     068h,069h,06ah,06bh,06ch,06dh,06eh,06fh
	       db     070h,071h,072h,073h,074h,075h,076h,077h
	       db     078h,079h,07ah,07bh,07ch,07dh,07eh,07fh
	       db     080h,081h,082h,083h,084h,085h,086h,087h
	       db     088h,089h,08ah,08bh,08ch,08dh,08eh,08fh
	       db     090h,091h,092h,093h,094h,095h,096h,097h
	       db     098h,099h,09ah,09bh,09ch,09dh,09eh,09fh
	       db     0a0h,0a1h,0a2h,0a3h,0a4h,0a5h,0a6h,0a7h
	       db     0a8h,0a9h,0aah,0abh,0ach,0adh,0aeh,0afh
	       db     0b0h,0b1h,0b2h,0b3h,0b4h,0b5h,0b6h,0b7h
	       db     0b8h,0b9h,0bah,0bbh,0bch,0bdh,0beh,0bfh
	       db     0c0h,0c1h,0c2h,0c3h,0c4h,0c5h,0c6h,0c7h
	       db     0c8h,0c9h,0cah,0cbh,0cch,0cdh,0ceh,0cfh
	       db     0d0h,0d1h,0d2h,0d3h,0d4h,0d5h,0d6h,0d7h
	       db     0d8h,0d9h,0dah,0dbh,0dch,0ddh,0deh,0dfh
	       db     0e0h,0e1h,0e2h,0e3h,0e4h,0e5h,0e6h,0e7h
	       db     0e8h,0e9h,0eah,0ebh,0ech,0edh,0eeh,0efh
	       db     0f0h,0f1h,0f2h,0f3h,0f4h,0f5h,0f6h,0f7h
	       db     0f8h,0f9h,0fah,0fbh,0fch,0fdh,0feh,0ffh
;
; Modified 4/21/93 to handle up to base 36!
;
ValueTable     db     02ch    dup(0ffh)
	       db     0feh,0fdh,0feh,0ffh        ; skip , and .
	       db     0,1,2,3,4,5,6,7,8,9
	       db     007h    dup(0ffh)
	       db     10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26
	       db     27,28,29,30,31,32,33,34,35
	       db     006h    dup(0ffh)
	       db     10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26
	       db     27,28,29,30,31,32,33,34,35
	       db     085h    dup(0ffh)


strbuffer      db     104h dup(?)   ; temporary string buffer
numbuffer      db     104h dup(?)   ; for number strings for debugging

number_fill    db     30h           ; '0'
table          db     '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ'
Debug          dd     0             ; True if debugging

ExitCode       dd     0             ; Exit code passed to OS/2 after BYE

CommandStr     db     100h dup(?)
CommandLen     EQU    $-CommandStr

OurStack       dd     STACK_SIZE dup(?)  ; should be big enough for a start
FStackBase     dd     STACK_UNDERFLOW dup(?)   ; provide room for underflow


; DO NOT ADD ANY VARIABLES HERE.  Stack is relative to USER variables.
; USER Data Area Starts Here.  Not all the variables here are USER variables.
;   Some may be converted, others may not.

U_UserVPtr         dd      0           ; User variable pointer
U_UserDefaultPtr   dd      0           ; Pointer to default USER variable area
UserVPtr           EQU     U_UserVPtr USER
UserDefaultPtr     EQU     U_UserDefaultPtr USER

U_StackBase        dd      FStackBase    ; Holds base address of stack
StackBase          EQU     U_StackBase USER

U_TickAbort        dd      VecAbort      ; Pointer to code for ABORT
TickAbort          EQU     U_TickAbort USER

CodeSpace          dd      0             ; Ptr to next avail. dictionary location
NewWord            dd      ?             ; Header of very last word defined

CompileMode        dd      0             ; Non-zero if compiling
U_LineNumber       dd      0             ; Line number of file being loaded
LineNumber         EQU     U_LineNumber USER

U_TIB              dd      0             ; Address of Terminal Input Buffer
TIB                EQU     U_TIB USER
U_NTIB             dd      0             ; Number of characters input
NTIB               EQU     U_NTIB USER
U_Offsett          dd      0             ; Offset from start of buffer
Offsett            EQU     U_Offsett USER

U_number_base      dd      10            ; Decimal
number_base        EQU     U_number_base ; Should be a USER, change _NumberQ 1st
OkVal              dd      0
Value              dd      0
Negative           dd      0
DPL                dd      0

U_SysTo            dd      0          ; TO variables: 0=fetch; 1=store; -1=add
SysTo              EQU     U_SysTo USER
U_OutPos           dd      0          ; Output position
OutPos             EQU     U_OutPos USER
CharPerLine        dd      80

FoundAddr          dd      0
Current            dd      ForthLink   ; Vocabulary where definitions are created
Context            dd      ForthLink,SysLink, ContextSize dup (0)
                           ; Context is where searching dictionary starts

UserArea           dd      UserAreaSize dup (0)

; END OF USER VARIABLES
;StackBase      dd      FStackBase    ; Holds base address of stack
;TickAbort      dd      VecAbort      ; Pointer to code for ABORT
;
;CodeSpace      dd      0             ; Ptr to next avail. dictionary location
;NewWord        dd      ?             ; Header of very last word defined
;
;CompileMode    dd      0             ; Non-zero if compiling
;LineNumber     dd      0             ; Line number of file being loaded
;
;number_base    dd      10            ; Decimal
;OkVal          dd      0
;Value          dd      0
;Negative       dd      0
;DPL            dd      0
;
;SysTo          dd      0          ; TO variables: 0=fetch; 1=store; -1=add
;OutPos         dd      0          ; Output position
OutLine        dd      0          ; counts UP
;CharPerLine    dd      80
MoreLength     dd      22
MoreVector     dd      Pause

TickExecute    dd      _DoExecute

;FoundAddr      dd      0
;Current        dd      ForthLink   ; Vocabulary where definitions are created
;Context        dd      ForthLink,SysLink, ContextSize dup (0)
		       ; Context is where searching dictionary starts

ForthLink      dd      0,LastForthWord,0       ; FORTH vocabulary pointer
SysLink        dd      0,LastHeader,ForthLink  ; SYSTEM vocabulary pointer
Voc_link       dd      SysLink           ; Pointer to last vocabulary created

FopenAction    dd      0
FopenHandle    dd      0
FopenName      db     "FORTH.INI",0
	       db      80 dup (?)

FileBufferSize =      16384
FileBuffer     db     FileBufferSize dup (?)

Date1          equ    <>
Date1          CatStr <">, @Date, <">

Paren1         equ    <>
Paren1         CatStr <(>

MESSAGE        Version," (Compiled: ",Date1,")",CrLf


InputBufferSize =      1024
InputSpace     db      InputBufferSize dup (?)
InputBuffer    dd      Offset InputSpace
InputCount     dd      0
InputOffset    dd      0

LastWordEnd    dd      0

;
; END OF FORTH SOURCE.....
;

	       .CODE

BREAK          MACRO
	       Call   Do_Breakpoint
	       ENDM

IMMEDIATE      EQU     1
COMPILEONLY    EQU     2
HIDDEN         EQU     4


_HEADER        STRUC
  Prev           DWORD  ?
  Flags          DWORD  ?     ; Not immediate, function call
  CodePointer    DWORD  ?
  NameSize       DWORD  ?
  ThisName       BYTE   20h dup (?)
_HEADER        ENDS


LASTHEADER     =       0

CodeDef        MACRO   ThisName:Req,Flg := <0>
	       LOCAL   ThisOne,ThisCode

  ThisOne      _HEADER { LastHeader, (Flg), ThisCode,@SIZESTR(ThisName)-2,ThisName }
  LASTHEADER   =       ThisOne

  ThisCode:
	       ENDM

	       .code
;*****************************************
;*                                       *
;*            CORE VOCABULARY            *
;*                                       *
;*****************************************

               CodeDef 'NOP'
DoNothing:     ret

	       CodeDef '!'
Store:         mov     edx,[ebx  ] ; value addr .... poke
	       mov     eax,[ebx+4]
	       mov     [edx],eax
	       add     ebx,8       ; pop both values
	       ret

	       CodeDef "'"              ; Tick, return address of next word
Tick:          mov     eax,' '
	       PushForth
	       Call    _Word
	       Call    _Find
	       PullForth
	       and     eax,eax
	       jz      @f
	       ret

@@:            lea     edx,What1Msg
	       call    WriteStr
	       call    _Count
	       call    _Type
	       lea     edx,What2Msg
	       call    WriteStr
	       jmp     Abort


_Comment       _Header { LastHeader, Immediate, Do_Comment, 1, '(' }
LastHeader     =       _Comment


Do_Comment:    mov     esi,InputBuffer
	       add     esi,InputOffset
	       mov     ecx,InputCount
	       sub     ecx,InputOffset
	       jbe     CommentDone

@@:            lodsb
	       cmp     al,')'
	       loopne  @b

CommentDone:   sub     esi,Inputbuffer
	       mov     inputoffset,esi
	       ret



	       CodeDef '*'
	       PULLFORTH
	       imul    eax,[ebx]
	       mov     [ebx],eax
	       ret

	       CodeDef '*/'           ; ( a b c -- a*b/c )
               mov     eax,[ebx+8]
               mov     edx,[ebx+4]
               mov     ecx,[ebx+0]
               or      ecx,ecx
               jz      DivByZero
               add     ebx,8          ; we eat 2 more than we make
               imul    edx
               idiv    ecx
               mov     [ebx+0],eax
	       ret

	       CodeDef '*/MOD'        ; ( a b c -- a*b/c a*b mod c )
               mov     eax,[ebx+8]
               mov     edx,[ebx+4]
               mov     ecx,[ebx+0]
               or      ecx,ecx
               jz      DivByZero
               add     ebx,4          ; we eat 2 more than we make
               imul    edx
               idiv    ecx
               mov     [ebx+4],edx    ; remainder
               mov     [ebx+0],eax    ; quotient  on "TOP"
	       ret

	       CodeDef '+'
	       PULLFORTH
	       add     [ebx],eax
	       ret

	       CodeDef '+!'          ; ( n addr -- ) adds n to addr
PlusStore:     mov     edx,[ebx  ]
	       mov     eax,[ebx+4]
	       add     [edx],eax
	       add     ebx,8
	       ret

	       CodeDef ','           ; ( Compiles a CELL )
Comma:         cld
	       PULLFORTH
	       stosd
	       mov     CodeSpace,EDI
	       ret

	       CodeDef '-'           ; ( n1 n2 -- n1-n2 )
	       PULLFORTH
	       sub     [ebx],eax
	       ret

	       CodeDef '."',3           ; Immediate, Compile Only
	       Call    S_Quote
	       lea     eax,_Type
	       PushForth
	       call    Do_CompileCall
	       ret

	       CodeDef '/'
	       PULLFORTH
	       or      eax,eax
	       jz      DivByZero
	       xchg    eax,[ebx]
	       CDQ                     ; convert AX to DX:AX
	       idiv    DWORD PTR[ebx]
	       mov     [ebx],eax
	       ret

	       CodeDef '/MOD'          ; ( a b -- {a mod b}  {a div b} )
	       mov     eax,[ebx]       ; one up on the stack
	       or      eax,eax
	       jz      DivByZero
	       xchg    eax,[ebx+4]
	       CDQ                     ; convert AX to DX:AX
	       idiv    DWORD PTR[ebx+4]
	       mov     [ebx],eax       ; Store quotient
	       mov     [ebx+4],edx     ; Store remainder
	       ret

	       CodeDef 'SM/REM'        ; ( D n -- {D mod n}  {D div n} )
               push    ecx
               push    edx
               PullForth
               mov     ecx,eax         ; ecx <-- n
               PullForth
               mov     edx,eax         ; Top half in edx
               PullForth               ; bottom in eax
               idiv    ecx
               xchg    eax,edx         ; swap the result order
               PushForth
               mov     eax,edx
               PushForth               ; push the other answer
               pop     edx
               pop     ecx
               ret

	       CodeDef 'UM/MOD'        ; ( D n -- {D mod n}  {D div n} )
               push    ecx
               push    edx
               PullForth
               mov     ecx,eax         ; ecx <-- n
               PullForth
               mov     edx,eax         ; Top half in edx
               PullForth               ; bottom in eax
               div     ecx
               xchg    eax,edx         ; swap the result order
               PushForth
               mov     eax,edx
               PushForth               ; push the other answer
               pop     edx
               pop     ecx
               ret

               CodeDef 'FM/MOD'        ; ( D n -- {D mov n}  {D div n} )
               push    ecx
               push    edx
               mov     ecx,[ebx+0]     ; n is on "top"
               mov     edx,[ebx+4]     ; D msw
               mov     eax,[ebx+8]     ; D lsw
               add     ebx,4           ; we will consume 1 more than we make

               or      ecx,ecx
               jz      DivByZero       ; don't even attempt it if = 0
               js      @f
               or      edx,edx
               jns     DivQ1           ; +/+
               jmp     DivQ2           ; -/+

@@:            or      edx,edx
               jns     DivQ3           ; +/-
               jmp     DivQ4           ; -/-


DivQ1:         div     ecx             ; +/+, simple math
DivDone:       mov     [ebx+0],eax
               mov     [ebx+4],edx
               pop     edx
               pop     ecx
               ret


DivQ2:         not     eax             ; -/+   Negate EDX:EAX
               not     edx
               add     eax,1
               adc     edx,0
               div     ecx
               neg     eax             ; neg quotient
               or      edx,edx
               jz      @f
               sub     edx,ecx         ; dec remainder my divisor
               dec     eax             ; dec quotient by 1
               neg     edx             ; negate divisor
@@:            jmp     DivDone

DivQ3:         neg     ecx             ; +/-   Negate cx
               div     ecx
               neg     eax             ; neg quotient
               or      edx,edx
               jz      @f
               sub     edx,ecx         ; dec remainder my divisor
               dec     eax             ; dec quotient by 1
@@:            jmp     DivDone

DivQ4:         neg     ecx             ; -/-   Negate cx
               not     eax             ; negate dx:ax, 1's comp
               not     edx
               add     eax,1           ; and add +1
               adc     edx,0
               div     ecx             ; do the division
               neg     edx             ; negate remainder
               jmp     DivDone         ; whew!





	       CodeDef '0<'
	       xor     eax,eax
	       jmp     LessThan

	       CodeDef '0='            ; returns true if A = 0
	       xor     eax,eax
	       cmp     eax,[ebx]
	       jnz     @f
	       not     eax
@@:            mov     [ebx],eax
	       ret

	       CodeDef '1+'
	       mov     eax,1
	       add     [ebx],eax
	       ret

	       CodeDef '1-'
	       mov     eax,1
	       sub     [ebx],eax
	       ret

	       CodeDef '2!'    ; ( x1 x2 a-addr -- )
	       mov     edx,[ebx]            ; MAW - ANSforth Fix 10/23/93
	       mov     eax,[ebx+4]
	       mov     [edx],eax
	       mov     eax,[ebx+8]
	       mov     [edx+4],eax
	       add     ebx,12
	       ret

	       CodeDef '2*'
	       shl     DWORD PTR[ebx],1
	       ret

	       CodeDef '2/'
	       sar     DWORD PTR[ebx],1     ; MAW - ANSforth Fix 6/8/93
	       ret

	       CodeDef '2@'
               PullForth                    ; MAW - ANSforth Fix 10/23/93
               mov     edx,eax
               mov     eax,[edx+4]
               PushForth
               mov     eax,[edx]
               PushForth
	       ret

	       CodeDef '2DROP'
	       add     ebx,8
	       ret

	       CodeDef '2DUP'
	       mov     eax,[ebx+4]
	       mov     edx,[ebx]
	       PushForth
	       sub     ebx,4
	       mov     [ebx],edx
	       ret

	       CodeDef '2OVER'
	       mov     eax,[ebx+12]
	       mov     ecx,[ebx+8]
	       sub     ebx,8
	       mov     [ebx],ecx
	       mov     [ebx+4],eax
	       ret

	       CodeDef '2SWAP'
	       mov     ecx,[ebx]
	       mov     edx,[ebx+4]
	       mov     eax,[ebx+8]
	       mov     [ebx],eax
	       mov     eax,[ebx+12]
	       mov     [ebx+4],eax
	       mov     [ebx+8],ecx
	       mov     [ebx+12],edx
	       ret

	       CodeDef ':'
Do_Colon:      mov     eax,CompileMode
	       or      eax,eax
	       jnz     NoSemicolon
	       mov     EDI,CodeSpace
	       mov     NewWord,EDI
	       cld
	       mov     eax,Current
	       mov     eax,[eax+VocLinkOffset]
	       stosd                    ; Store the pointer to previous
	       mov     eax,0            ; Flags to store
	       stosd                    ; Store the Words flags
	       mov     eax,0            ; Execution Address (0 for now)
	       push    edi              ; save this address for a while
	       stosd                    ; Store the code address
	       mov     edx,edi
	       mov     eax,' '
	       PushForth
	       Call    _Word            ; Get string, stored at EDI!
	       mov     edi,LastWordEnd  ; Get the end of the string
	       Call    ToUpper          ; (Uses address from forth stack)
	       pop     eax              ; Get the place to stuff code address

	       mov     edi,eax          ; Fix so headers are always
	       add     edi,024h         ; the same size

	       mov     [eax],edi        ; Update the code address
	       mov     CompileMode,1    ; We are now in compile mode
	       ret                      ; done for now

               CodeDef ':NONAME'
Colon_NoName:  mov     eax,CompileMode
	       or      eax,eax
	       jnz     NoSemicolon
	       mov     EDI,CodeSpace
               mov     eax,edi          ; Get adress of start in eax
               PushForth
               mov     CompileMode,1
               ret

NoSemicolon:   lea     edx,SemicolonMsg
	       call    WriteStr
	       call    WriteLineNum
	       jmp     Abort

	       CodeDef ';',3
Do_SemiColon:
	       call    CompileCheck     ; finish a definition
	       call    Do_CompileRet    ; update codespace
	       mov     CodeSpace,EDI
	       mov     eax,NewWord      ; update the dictionary
	       mov     edx,Current
	       mov     [edx+VocLinkOffset],eax ; update Current vocab ptr
	       mov     CompileMode,0    ; back out of compile mode
	       ret

Do_CompileRet:                         ; compiles a RET instruction
	       mov     al,0C3h
	       stosb
	       ret

	       CodeDef '<'             ; i.e. 0 0 <
	       pullforth               ; eax = stack top 0
LessThan:      cmp     eax,[ebx]       ; subtract 0 --> -1 (carry set)
	       mov     eax,0           ; eax = 0
	       jle     @f
	       dec     eax
@@:            mov     [ebx],eax
	       ret

	       CodeDef '='             ; returns true if A = B
	       pullforth
	       cmp     eax,[ebx]
	       mov     eax,0
	       jnz     @f
	       not     eax
@@:            mov     [ebx],eax
	       ret

	       CodeDef '>'             ; i.e. 9 4 >
	       pullforth               ; eax = stack top 4
GreaterThan:   cmp     eax,[ebx]       ; subtract 9 --> -5 (carry set)
	       mov     eax,0           ; eax = 0
	       jge     @f
	       dec     eax
@@:            mov     [ebx],eax
	       ret

	       CodeDef '>BODY'         ; ( xt -- a-addr )
	       PullForth               ; do an execute
	       cmp     byte ptr[eax],0E8h
	       jnz     @f
               add     eax,5
               PushForth
               ret

@@:            lea     edx,NotCreateWordMsg
	       call    WriteStr
	       jmp     Abort

	       CodeDef '>IN'           ; Address of offset into buffer
	       lea     eax,InputOffset
	       pushForth
	       ret

	       CodeDef '>R'       ; moves top of stack to return stack
	       pop     edx        ; our return address
	       PULLFORTH
	       push    eax        ; push number onto return stack
	       push    edx        ; restore return address and push on stack
	       ret

	       CodeDef '?DUP'      ; Duplicates if true
	       mov     eax,[ebx]
	       or      eax,eax
	       jz      @f
	       PushForth
@@:            ret

	       CodeDef '@'
Fetch:         mov     eax,[ebx  ]
	       mov     eax,[eax  ]
	       mov     [ebx  ],eax
	       ret

	       CodeDef 'ABS'          ; ( a -- |a| )
	       mov     eax,[ebx]
	       and     eax,eax
	       jns     @f
	       neg     eax
	       mov     [ebx],eax
@@:            ret

	       CodeDef 'ACCEPT'     ; ( c-addr n1 -- n2 ) Get a string from
				    ; standard input, using READ
_Accept:       mov     edx,[ebx+4]  ; Buffer address in EDX
	       mov     eax,[ebx]    ; Buffer size in eax
	       add     ebx,4        ; consume 1 param, replace second
	       pushad               ; save all the registers
	       push    ebx          ; Return parameter is bytes read
	       push    eax          ; Size of buffer
	       push    edx          ; Buffer area
	       pushd   STDIN
	       call    Dos32Read
	       add     esp,16
	       or      eax,eax
	       jnz     IOerror
	       popad
	       ret

	       CodeDef 'ALIGN'      ; ( -- )
	       sub     ebx,4
	       mov     [ebx],edi
	       call    Aligned
	       mov     edi,[ebx]
	       add     ebx,4
	       mov     CodeSpace,edi
	       ret

	       CodeDef 'ALIGNED'    ; ( addr -- a-addr )
Aligned:       mov     eax,[ebx]
	       and     eax,3
	       sub     eax,4
	       neg     eax
	       and     eax,3
	       add     [ebx],eax
	       ret

	       CodeDef 'ALLOT'          ; add N bytes to the latest entry
Allot:         PULLFORTH
	       add     EDI,EAX
	       mov     CodeSpace,EDI
	       ret

	       CodeDef 'AND'
	       PULLFORTH
	       AND     [ebx],eax
	       ret

	       CodeDef 'BASE'
	       lea     eax,Number_Base
	       PUSHFORTH
	       ret

	       CodeDef 'BL'
	       mov     eax,' '
	       PUSHFORTH
	       ret

	       CodeDef 'C!'
	       mov     edx,[ebx  ]      ; value addr .... poke
	       mov     eax,[ebx+4]
	       mov     [edx],al
	       add     ebx,8            ; pop both values
	       ret

	       CodeDef 'C,'
	       cld
	       PULLFORTH
	       stosb
	       mov     CodeSpace,EDI
	       ret

	       CodeDef 'C@'
	       mov     eax,[ebx  ]
	       mov     eax,[eax  ]
	       and     eax,00ffh
	       mov     [ebx  ],eax
	       ret

	       CodeDef 'CELL+'
	       mov     eax,[ebx]
	       add     eax,4
	       mov     [ebx],eax
	       ret

	       CodeDef 'CELLS'       ; multiplies by word size, 4
WTimes:        shl     DWORD PTR [ebx],2
	       ret

	       CodeDef 'CHAR'        ; ( "name" -- char )
DoChar:        mov     eax,' '
	       PushForth
	       call    _Word
               mov     edx,[ebx]
               xor     eax,eax
               mov     al,[edx+4]
               mov     [ebx],eax
	       ret

	       CodeDef 'CHAR+'
	       inc     dword ptr[ebx]
	       ret

	       CodeDef 'CHARS'
	       ret

	       CodeDef 'CONSTANT'       ; Declare a constant
Do_Constant:   mov     EDI,CodeSpace
	       mov     NewWord,EDI      ; Save start of word
	       cld
	       mov     eax,Current
	       mov     eax,[eax+VocLinkOffset]
	       stosd                    ; Store the pointer to previous
	       mov     eax,0            ; Flags to store
	       stosd                    ; Store the Words flags
	       mov     eax,0            ; Execution Address (0 for now)
	       push    edi              ; save this address for a while
	       stosd                    ; Store the code address
	       mov     edx,edi
	       mov     eax,' '
	       PushForth
	       Call    _Word            ; Get string, stored at EDI!
	       mov     edi,LastWordEnd  ; Get the end of the string
	       Call    ToUpper          ; (Uses address from forth stack)
	       pop     eax              ; Get the place to stuff code address
	       mov     [eax],edi        ; Update the code address

	       mov     al,0E8h          ; Call ABSOLUTE
	       stosb
	       lea     eax,DoesConstant ; Address of DoesConst routine
	       sub     eax,EDI          ; subtract current EIP
	       sub     eax,4            ; subtract 4 for upcoming offset
	       STOSD

	       PULLFORTH                ; Store the constant
	       STOSD

	       mov     eax,NewWord      ; update the dictionary
	       mov     edx,Current
	       mov     [edx+VocLinkOffset],eax
	       mov     CodeSpace,EDI
	       ret                      ; done for now

DoesConstant:  pop     eax
	       mov     eax,[eax]
	       PUSHFORTH
	       ret

	       CodeDef 'CR'
DoCr:          lea     edx,CrLfStr       ; Write a CR/LF pair
	       call    WriteStr
	       xor     eax,eax
	       mov     DWORD PTR OutPos,eax
               inc     DWORD PTR OutLine
	       ret

	       CodeDef 'CREATE'         ; Creates a 0 byte variable
Create:        mov     EDI,CodeSpace
	       mov     NewWord,EDI      ; Save start of word
	       cld
	       mov     eax,Current
	       mov     eax,[eax+VocLinkOffset]
	       stosd                    ; Store the pointer to previous
	       mov     eax,0            ; Flags to store
	       stosd                    ; Store the Words flags
	       mov     eax,0            ; Execution Address (0 for now)
	       push    edi              ; save this address for a while
	       stosd                    ; Store the code address
	       mov     edx,edi
	       mov     eax,' '
	       PushForth
	       Call    _Word            ; Get string, stored at EDI!
	       mov     edi,LastWordEnd  ; Get the end of the string
	       Call    ToUpper          ; (Uses address from forth stack)
	       pop     eax              ; Get the place to stuff code address
	       mov     [eax],edi        ; Update the code address

	       mov     al,0E8h          ; Call ABSOLUTE
	       stosb
	       lea     eax,DoesVariable ; Address of DoesConst routine
	       sub     eax,EDI          ; subtract current EIP
	       sub     eax,4            ; subtract 4 for upcoming offset
	       stosd

	       mov     CodeSpace,EDI
	       mov     eax,NewWord      ; update the dictionary
	       mov     edx,Current
	       mov     [edx+VocLinkOffset],eax
	       ret                      ; done for now



	       CodeDef 'COUNT'     ; ( addr -- addr+4 [addr] )
_Count:        mov     edx,[ebx]
	       xor     eax,eax
	       mov     eax,[edx]
	       add     DWORD PTR [ebx],4
	       PushForth
	       ret

	       CodeDef 'DECIMAL'
	       mov     eax,10
	       mov     Number_Base,eax
	       ret

	       CodeDef 'DEPTH'
	       mov     eax,StackBase
	       sub     eax,ebx         ; Forth Stack depth in EAX
	       clc
	       shr     eax,2           ; divide by entry size
	       PUSHFORTH
	       ret

	       CodeDef 'DROP'
Drop:          add     ebx,4           ; Drop Stack top
	       ret

	       CodeDef 'DUP'
	       mov     eax,[ebx]
	       PUSHFORTH
	       ret

	       CodeDef 'EMIT'           ; Quite large, isn't it?
Do_Emit:       push    ebp
	       push    edi
	       push    esi
	       push    edx
	       push    ecx
	       mov     eax,esp          ; save current ss, esp
	       push    ss               ; for return from 16-bit land
	       push    eax

	       mov     ecx,OutPos
	       inc     ecx
	       mov     OutPos,ecx

	       PULLFORTH

	       push    eax
	       mov     eax,esp          ; character stored at [EAX]
	       call    DosFlatToSel
	       push    eax              ; address of string
	       pushw   1                ; length of string
	       pushw   0                ; vio handle (0 = default)

	       mov     eax,esp          ; convert stack so 16-bit can use it
	       ror     eax,16
	       shl     eax,3
	       or      al,7             ; convert to ring-3 tiled segment
	       mov     ss,eax

	       jmp     far ptr Do_Emit16

Do_Emit2       label   far
	       movzx   eax,ax           ; convert return code to 32-bit

; Restore 32-bit SS:ESP - it is on top of stack.
	       movzx   esp,sp           ; make sure that esp is correct
	       lss     esp,[esp]
	       pop     ecx
	       pop     edx
	       pop     esi
	       pop     edi
	       pop     ebp
	       ret

	       CodeDef '<EXECUTE>'      ; The REAL execute
_DoExecute:    PullForth
	       jmp     eax

	       CodeDef "'EXECUTE"       ; Gives address of vector
	       lea     eax,TickExecute
	       PushForth
	       ret

	       CodeDef 'EXECUTE'        ; ( addr -- )
_Execute:      mov     eax,TickExecute
	       jmp     eax              ; Jump to address specified

	       CodeDef 'FIND'           ; ( c-addr -- c-addr 0 | xt 1 | xt -1 )
_Find:         mov     edx,[ebx]        ; copy out of the stack, don't destroy
	       call    LookFor
	       mov     eax,FoundAddr
	       or      eax,eax
	       jz      FindDone
               mov     ecx,eax
	       mov     edx,[ecx].CodePointer
               mov     [ebx],edx        ; overwrite with execution address
	       mov     edx,[ecx].Flags
	       and     edx,IMMEDIATE
	       jnz     FindImm
	       mov     eax,-1
	       jmp     FindDone
FindImm:       mov     eax,1
FindDone:      PushForth
	       ret


	       CodeDef 'FILL'    ; ( addr n b -- ) fills n bytes at addr with b
	       mov     eax,[ebx+4]
	       cmp     eax,1      ; not defined for n < 1
	       jl      @f
	       push    edi
	       mov     ecx,eax
	       mov     eax,[ebx]
	       mov     edi,[ebx+8]
	       rep stosb
	       pop     edi
@@:            add     ebx,12
	       ret

	       CodeDef 'HERE'
	       mov     eax,EDI
	       PushForth
	       ret

	       CodeDef 'I'         ; copies number from return stack to top of stack
	       mov     eax,[esp+4] ; Get the data
	       PUSHFORTH
	       ret

	       CodeDef 'IMMEDIATE'
	       mov     eax,Current
	       mov     eax,[eax+VocLinkOffset]
	       or      [EAX].Flags,Immediate
	       ret

	       CodeDef 'INVERT'       ; 1s complement
	       not     dword ptr[ebx]
	       ret

	       CodeDef 'J'         ; 1 loop up
	       mov     eax,[esp+12] ; return, index, limit, index
	       PushForth
	       ret

	       CodeDef 'KEY'
GetKey:	       mov     eax,0
	       PushForth
	       call    Do_Getkey
	       ret

	       CodeDef 'KEYNOWAIT'
	       mov     eax,1
	       PushForth
	       call    Do_Getkey
	       ret

;               CodeDef '(KEY)'           ; New version of KEY
Do_GetKey:     PUSHAD
	       mov     eax,esp          ; save current ss, esp
	       push    ss               ; for return from 16-bit land
	       push    eax

	       lea     eax,ascii
	       mov     word ptr [eax],0
	       call    DosFlatToSel
	       push    eax              ; 8 bytes of parameters
	       PullForth
	       and     eax,1
	       push    ax               ; Wait flag, etc.
	       mov     eax,0
	       push    ax               ; Handle 0

	       mov     eax,esp          ; convert stack so 16-bit can use it
	       ror     eax,16
	       shl     eax,3
	       or      al,7             ; convert to ring-3 tiled segment
	       mov     ss,eax
	       jmp     far ptr Do_GetKey16

Do_GetKey2     label   far              ; Restore 32-bit SS:ESP - it is on top of stack.
	       movzx   esp,sp           ; make sure that esp is correct
	       lss     esp,[esp]
	       POPAD
	       xor     eax,eax
	       mov     ax,word ptr[ascii]
	       mov     [ebx],eax        ; Replace stack contents
	       ret

	       CodeDef 'LITERAL',3
_Literal:      cld                      ; mov eax,literal
	       mov     al,0b8h
	       stosb
	       PULLFORTH
	       stosd

	       mov     al,083h          ; sub ebx,4
	       stosb
	       mov     al,0ebh
	       stosb
	       mov     al,004h
	       stosb

	       mov     al,089h          ; mov [ebx],eax
	       stosb
	       mov     al,003h
	       stosb
	       ret

	       CodeDef 'LSHIFT'     ; ( n1 n2 -- n3 ) Shift n1 left n2 times
	       mov     ecx,[ebx]
	       add     ebx,4
	       shl     DWORD PTR [ebx],cl
	       ret

	       CodeDef 'M*'        ; ( n1 n2 -- d )
	       mov     eax,[ebx+4]
	       imul    DWORD PTR[ebx]
	       mov     [ebx],edx
	       mov     [ebx+4],eax
	       ret

	       CodeDef 'MAX'          ; ( a b -- max )
	       PullForth
	       cmp     eax,[ebx]
	       jl      @f
	       mov     [ebx],eax
@@:            ret

	       CodeDef 'MIN'          ; ( a b -- min )
	       PullForth
	       cmp     eax,[ebx]
	       jg      @f
	       mov     [ebx],eax
@@:            ret

	       CodeDef 'MOD'
	       PULLFORTH
	       or      eax,eax
	       jz      DivByZero
	       xchg    eax,[ebx]
	       CDQ                     ; convert AX to DX:AX
	       idiv    DWORD PTR[ebx]
	       mov     [ebx],edx       ; put MODULUS on stack
	       ret

	       CodeDef 'MOVE'      ; ( addr1 addr2 u -- )
	       mov     eax,[ebx+8]
	       cmp     eax,[ebx+4]
	       ja      Cmove
	       add     eax,[ebx]
	       cmp     eax,[ebx+4] ; cmp  addr1+u,addr2
	       jg      CmoveBack
	       jmp     Cmove

	       CodeDef 'NEGATE'       ; ( a -- -a )
	       neg     DWORD PTR[ebx]
	       ret

	       CodeDef 'OR'
	       PULLFORTH
	       OR      [ebx],eax
	       ret

	       CodeDef 'OVER'
	       mov     eax,[ebx+4]     ; duplicate one entry down...
	       PUSHFORTH
	       ret

	       CodeDef 'QUIT'
Quit:          mov     esp,SavedESP
	       call    StackCheck
	       call    Prompt
	       Call    Query
	       call    Interpret
	       jmp     Quit

	       CodeDef 'R>'       ; moves number from return stack to top of stack
	       pop     edx        ; our return address
	       pop     eax        ; number we want
	       push    edx        ; restore return address and push on stack
	       PUSHFORTH
	       ret

	       CodeDef 'R@'       ; Copies contents of return stack
	       mov     eax,[esp+4]
	       PushForth
	       ret

	       CodeDef 'RECURSE',3      ; Call the NEW word
	       Call    CompileCheck
	       mov     eax,NewWord
	       mov     eax,[eax].codepointer
	       PushForth
	       Call    Do_CompileCall
	       ret

	       CodeDef 'ROT'
	       mov     eax,[ebx]       ; take top, move it down 2 levels
	       xchg    eax,[ebx+4]
	       xchg    eax,[ebx+8]
	       mov     [ebx],eax
	       ret

	       CodeDef 'RSHIFT'     ; ( n1 n2 -- n3 ) Shift n1 left n2 times
	       mov     ecx,[ebx]
	       add     ebx,4
	       shr     DWORD PTR[ebx],cl
	       ret


	       CodeDef 'S"',3           ; Generates an INLINE string
S_Quote:       Call    CompileCheck
	       lea     eax,Inline_String
	       PushForth
	       Call    Do_CompileCall

	       mov     eax,'"'          ; get string, stored HERE!
	       PushForth
	       Call    _Word            ; Get string, stored at EDI!
	       mov     edi,LastWordEnd  ; Get the end of the string
	       PullForth
	       ret

	       CodeDef 'S>D'       ; ( n -- d )
	       xor     eax,eax
	       mov     edx,[ebx]
	       or      edx,edx
	       js      S2D1
	       PUSHFORTH
	       ret
S2D1:          dec     eax
	       PUSHFORTH
	       ret

	       CodeDef 'SOURCE'     ; Returns input buffer address and count
	       mov     eax,InputBuffer
	       PushForth
	       mov     eax,InputCount
	       PushForth
	       ret

	       CodeDef 'STATE'
	       lea     eax,CompileMode
	       PUSHFORTH
	       ret

	       CodeDef 'SPACE'
	       mov     eax,' '
	       PushForth
	       Call    Do_Emit
	       ret

	       CodeDef 'SPACES'
	       PullForth
	       mov     ecx,eax
@@:            mov     eax,' '
	       PushForth
	       Call    Do_Emit
	       Loop    @b
	       ret

	       CodeDef 'SWAP'
	       mov     eax,[ebx  ]
	       mov     edx,[ebx+4]
	       mov     [ebx  ],edx
	       mov     [ebx+4],eax
	       ret

	       CodeDef 'TYPE'         ; ( addr +n -- )
_Type:         pushad
	       xor     eax,eax      ; used as "actual count" storage
	       push    eax
	       mov     eax,esp      ; push the address of the previous push
	       push    eax
	       mov     eax,[ebx]    ; push the string length
	       add     OutPos,eax   ; update output position
	       push    eax
	       mov     eax,[ebx+4]  ; push the string address
	       push    eax
	       pushd   stdout       ; push the handle to write to
	       call    Dos32Write   ; do the write.
	       add     esp,20       ; set the stack back to semi-normal
	       popad
	       add     ebx,8        ; Drop the 2 forth stack entries
	       ret

	       CodeDef 'U<'      ; unsigned comparison
	       PullForth
	       cmp     eax,[ebx]
	       mov     eax,0
	       jbe     @f
	       dec     eax
@@:            mov     [ebx],eax
	       ret

	       CodeDef 'UM*'       ; ( u1 u2 -- ud )
	       mov     eax,[ebx+4]
	       mul     DWORD PTR[ebx]
	       mov     [ebx],edx
	       mov     [ebx+4],eax
	       ret

	       CodeDef 'VARIABLE'       ; Declare a variable
	       call    Create
	       xor     eax,eax
	       mov     [edi],eax        ; initialize to 0
	       mov     eax,4
	       PUSHFORTH
	       call    Allot
	       ret

	       CodeDef 'WORD'          ; (char -- c-addr)
				       ; Pull a string from between delimiters
				       ; in InputBuffer

_Word:         cld                     ; Count UP
	       push    edi             ; Push destination, we'll need it
	       xor     eax,eax
	       stosd                   ; Put a 0 in the count

	       PullForth
	       Push    EBX
	       lea     EBX,WordScanTable
	       mov     edx,eax         ; Delimiter in dl
	       mov     esi,InputOffset
	       mov     ecx,InputCount
	       sub     ecx,esi         ; bump down count
	       jle     _WordDone

	       add     esi,InputBuffer
@@:            or      ecx,ecx         ; If we are out of characters, exit
	       jz      _WordDone
	       lodsb                   ; skip leading matches
	       xlat
	       dec     ecx
	       cmp     dl,al
	       jz      @b

@@:            stosb                   ; process non-matches
	       or      ecx,ecx
	       jz      _WordDone
	       lodsb
	       xlat
	       dec     ecx
	       cmp     dl,al
	       jnz     @b

_WordDone:     mov     eax,esi
	       mov     esi,InputBuffer
	       sub     eax,esi         ; eax now has the NEW offset
	       mov     InputOffset,eax ; update value

	       mov     ecx,edi         ; stuff a non-counted space after text
	       xor     eax,eax
	       stosd
	       mov     eax,ecx

	       mov     LastWordEnd,edi
	       pop     ebx
	       pop     edi             ; original value of EDI
	       sub     eax,edi         ; how many bytes did we use?
	       sub     eax,4           ; adjust for count bytes
	       mov     [edi],eax
	       mov     eax,edi         ; address of string now in eax
	       PushForth
	       ret


	       CodeDef 'XOR'
	       PULLFORTH
	       XOR     [ebx],eax
	       ret

	       CodeDef '[',Immediate   ; This must be an IMMEDIATE word
	       mov     CompileMode,0
	       ret

	       CodeDef "[']",Immediate
	       call    CompileCheck
	       call    Tick
	       call    _Literal
	       ret

	       CodeDef '[CHAR]',Immediate
	       call    CompileCheck
	       call    DoChar
	       call    _Literal
	       ret

	       CodeDef ']'
	       mov     CompileMode,1
	       ret


;*****************************************
;*                                       *
;*            CORE EXTENSIONS            *
;*                                       *
;*****************************************


	       CodeDef '#TIB'
	       lea     eax,InputCount
	       PushForth
	       ret

	       CodeDef 'SPAN'
	       lea     eax,InputCount
	       PushForth
	       ret

	       CodeDef 'TIB'
	       lea     eax,InputBuffer
	       PushForth
	       ret

	       CodeDef '\',IMMEDIATE   ; Single line comment
	       cld                     ; Count UP
	       mov     esi,InputOffset
	       mov     ecx,InputCount
	       sub     ecx,esi         ; bump down count
	       jle     _CommentDone

	       add     esi,InputBuffer
@@:            lodsb
	       cmp     al,CR
	       loopne  @b

_CommentDone:  mov     eax,esi
	       sub     eax,InputBuffer
	       mov     InputOffset,eax ; update value
	       ret

	       CodeDef 'QUERY'      ; ( -- ) Get a line of text
Query:         lea     eax,InputSpace
	       mov     InputBuffer,eax
	       PushForth
	       mov     eax,InputBufferSize
	       PushForth
	       call    _Accept
	       PullForth
	       mov     InputCount,eax
	       xor     eax,eax
	       mov     InputOffset,eax
	       ret


;*****************************************
;*                                       *
;*            UTILITY ROUTINES           *
;*                                       *
;*****************************************

	       CodeDef '="'        ; ( addr1 addr2 -- f )
EqualStr:      push    esi
	       push    edx
	       push    ecx
	       mov     esi,[ebx]
	       add     ebx,4
	       mov     edx,[ebx]
	       push    ebx         ; Save STACK, we're using EBX
	       lea     ebx,UpperCaseTable
	       cld
	       lodsd               ; Length of string1 in eax
	       cmp     eax,[edx]   ; compare string lengths
	       jnz     NotEqual
	       add     edx,4       ; bump String2 pointer
	       mov     ecx,eax     ; put the counter in ECX, for LOOP

EqualStr1:     lodsb
	       xlat
	       xchg    ah,al
	       mov     al,[edx]
	       xlat
	       inc     edx
	       cmp     al,ah
	       jnz     NotEqual
	       loop    EqualStr1

	       mov     eax,0ffffffffh  ; strings match, return true
	       jmp     @f
NotEqual:      mov     eax,0
@@:            pop     ebx
	       mov     [ebx],eax
	       pop     ecx
	       pop     edx
	       pop     esi
	       ret

LookFor:       pushad
	       lea     ecx,Context           ; look for [EDX]
	       mov     FoundAddr,0

LookFor1:      mov     esi,[ecx]
	       or      esi,esi
	       jz      LookFor_Done
	       add     esi,VocLinkOffset

LookFor2:      mov     esi,[esi].Prev         ; go backwards in the chain
	       or      esi,esi
	       jz      LookFor3
	       mov     eax,[esi].NameSize
	       and     eax,eax
	       jz      LookFor3

	       push    esi                    ; save edx
	       lea     esi,[esi].NameSize

	       mov     eax,edx
	       PushForth
	       mov     eax,esi
	       PushForth
	       call    EqualStr
	       PullForth

	       pop     esi
	       and     eax,eax
	       jz      LookFor2
	       mov     FoundAddr,esi          ; put the address in the output
LookFor_Done:  popad
	       ret

LookFor3:      add     ecx,4
	       jmp     LookFor1

ToUpper:       PullForth               ; (c-addr -- )
	       pushad                  ; Converts to upper in place
	       cld
	       mov     esi,eax
	       lodsd
	       mov     ecx,eax
	       or      ecx,ecx
	       jz      ToUpper9
	       lea     ebx,uppercaseTable
	       mov     edi,esi

@@:            lodsb
	       xlat
	       stosb
	       loop    @b
ToUpper9:      popad
	       ret

DoesVariable:  pop     eax
	       PUSHFORTH
	       ret

	       CodeDef 'NUMBER?'        ; ( addr --
					;      value TRUE  (ok value)
					;      addr  FALSE ( bad value )
_NumberQ:      PullForth
	       pushad                   ; save ALL registers
	       xor      edx,edx
	       mov      Value,edx
	       mov      DPL,edx
	       inc      edx
	       mov      Negative,edx    ; NOT negative
	       lea      ebx,ValueTable
	       xor      edi,edi         ; edi will hold result
	       mov      esi,eax
	       lodsd
	       mov      ecx,eax         ; ecx is number of bytes left
	       or       ecx,ecx
	       jz       _NumberQ9
_NumberQ1:     xor      eax,eax
	       lodsb
	       xlat
	       cmp      al,0ffh         ; test for bogus number
	       jz       _NumberQ9
	       cmp      al,0feh         ; test for , and .
	       jnz      @f
	       mov      DPL,esi
	       jmp      _NumberQ2

@@:            cmp      al,0fdh         ; test for -
	       jnz      @f
	       cmp      edi,0
	       jnz      _NumberQ9       ;  '-' in the middle of a number!
	       mov      Negative,-1
	       jmp      _NumberQ2

@@:            cmp      eax,Number_Base ; test for TOO BIG digit
	       jae      _NumberQ9
	       xchg     eax,edi      ; swap value with eax
	       mul      Number_Base  ; multiply old value by Number Base
	       add      edi,eax      ; add to new in EDI
_NumberQ2:     loop     _NumberQ1    ; result in EDI, loop until out of chars

	       mov      Value,edi
	       cmp      DPL,0
	       jz       _NumberQOk
	       sub      esi,DPL
	       mov      DPL,esi      ; store the # of digits since in DPL!

_NumberQOk:    popad
	       mov      eax,Value
	       mul      Negative     ; Multiply by 1 or -1!
	       PushForth
	       mov      eax,-1
	       PushForth
	       ret

_NumberQ9:     popad                 ; Not a number
	       PushForth             ;  Restore the Address
	       xor      eax,eax
	       PushForth             ; and then a FALSE
	       ret

	       CodeDef '<S">'           ; Puts Address and Count on stack
Inline_String: pop     ecx              ; (Counted string stored in-line)
	       mov     eax,ecx
	       add     eax,4            ; Push the Address
	       PushForth
	       mov     eax,[ecx]
	       PushForth                ; Push the count
	       add     eax,ecx          ; Add Count+8 to Return address
	       add     eax,8
	       jmp     eax

	       CodeDef '0"',3
	       Call    S_Quote
	       lea     eax,DROP
	       PushForth
	       call    Do_CompileCall
	       ret

	       CodeDef 'SYScall'        ; ( addr --- APIreturnCode )
	       PullForth
	       push    ebx
	       push    ecx
	       push    edx
	       push    esi
	       push    edi
	       push    ebp
	       mov     ebp,esp
	       mov     esp,ebx
	       Call    EAX
	       mov     esp,ebp
	       pop     ebp
	       pop     edi
	       pop     esi
	       pop     edx
	       pop     ecx
	       pop     ebx
	       PushForth
	       ret












AutoLoad:      pushad                    ; put C:\FLAT32\FORTH.INI into fOpenName
	       mov     esi,Environment   ; on my machine
	       cld
@@:            lodsb
	       cmp     al,0
	       jnz     @b
	       lodsb
	       cmp     al,0
	       jnz     @b         ; look for a double 0

	       mov     FooBar,ESI

	       lea     edi,FOpenName     ; copy the path, up to the .
@@:            lodsb
	       stosb
	       cmp     al,'.'
	       jnz     @b

	       mov     al,'I'
	       stosb
	       mov     al,'N'
	       stosb
	       mov     al,'I'
	       stosb
	       xor     eax,eax
	       stosd
	       popad

;               CodeDef 'AUTOLOAD'
;AutoLoad:
	       call    FOpen
@@:            PULLFORTH
	       push    eax        ; push handle
	       push    ebx        ; push stack
	       cmp     eax,0
	       jle     Abort
	       PushForth
	       mov     eax,FileBufferSize
	       PushForth
	       call    FRead
	       PullForth
	       or      eax,eax
	       jz      @f
	       mov     InputCount,eax
	       lea     eax,FileBuffer
	       mov     InputBuffer,eax
	       xor     eax,eax
	       mov     InputOffset,eax
	       call    Interpret

@@:            pop     eax
	       cmp     eax,ebx     ; check if stack changed
	       jne     StackProblem
	       pop     eax
	       PUSHFORTH
	       call    FClose
	       ret

StackProblem:  lea     edx,StackLoadMsg
	       call    WriteStr
	       jmp     Abort










MAIN:          mov     SavedESP,ESP
	       mov     ebp,esp
	       mov     EAX,[EBP+12]
	       mov     Environment,EAX
	       mov     EAX,[EBP+16]
	       mov     CommandLine,EAX
	       pushd   012h            ; Write Un-committed
	       pushd   Reserve_Size
	       pushd   offset CodeSpace
	       call    Dos32AllocMem
	       and     eax,eax
	       jnz     Bye
	       mov     esp,SavedESP

	       call    ErrorHandler

               lea     eax,UserArea           ; Set up USER variables
               mov     UserVPtr,eax           ; Ptr to free USER var area
               mov     UserDefaultPtr,UREG    ; Default is itself

	       lea     edx,CopyRightMsg
	       call    WriteStr

	       lea     edx,WelcomeMsg
	       call    WriteStr

	       lea     edx,VersionMsg
	       call    WriteStr

	       lea     edx,GreetMsg
	       call    WriteStr

	       Call    AutoLoad
	       jmp     quit

VecAbort:      mov     esp,SavedESP
	       call    ErrorHandler
	       jmp     Quit

ErrorHandler:  mov     UREG,offset U_UserVPtr
               xor     eax,eax
               mov     CompileMode,eax
               mov     SysTo,eax
               mov     ebx,StackBase
               mov     EDI,CodeSpace        ; CS:EDI = compile pointer
               cld                          ; count UP
               call    ForthVoc
               ret

IOerror:       mov     edx,offset IOerrorMsg
	       call    WriteStr
	       mov     edx,offset StrBuffer
	       call    Int_Str
	       call    WriteStr
	       call    DoCr
	       jmp     Abort

	       CodeDef 'DumpRegisters'
DumpRegisters:
               pushad
	       push    Number_Base
	       mov     Number_Base,10h
	       pushad
	       lea     edx,RegisterMsg
	       call    WriteStr
	       popad

	       pushad
	       mov     ecx,8
@@:            lea     edx,Numbuffer
	       mov     ebx,8
	       pop     eax
	       call    Int_StrLen
	       call    WriteStr
	       lea     edx,SpStr
	       call    WriteStr
	       loop    @b
	       call    DoCr
	       pop     Number_Base
	       popad
	       ret

WriteEAX:
	       pushad
	       lea     edx,NumBuffer
	       call    Int_Str
	       call    WriteStr
	       call    DoCr
	       popad
	       ret


WriteStr:                           ; writes string at [EDX]
	       pushad
	       xor     eax,eax      ; used as "actual count" storage
	       push    eax
	       mov     eax,esp      ; push the address of the previous push
	       push    eax
	       mov     eax,[edx]    ; push the string length

	       add     OutPos,eax   ; update output position

	       push    eax
	       add     edx,4        ; push the string address
	       push    edx
	       pushd   stdout       ; push the handle to write to
	       call    Dos32Write   ; do the write.
	       add     esp,20       ; set the stack back to semi-normal
	       popad
	       ret


Int_Str:       pushad               ; No length required...
	       mov     ebx,0
	       jmp     Int_Str0

Int_StrLen:    pushad
Int_Str0:                           ; eax-value to print
				    ; ebx-number of digits..
				    ; edx-address of buffer to put it in.....
	       pushd   0            ;
	       mov     edi,ebx      ; edi now has count
	       mov     ebx,edx      ; buffer address now in ebx
	       mov     ecx,number_base
	       lea     esi,table
Int_Str1:
	       mov     edx,0
	       div     ecx
	       mov     edx,[edx+esi]
	       push    edx
	       dec     edi          ; bump counter
	       and     eax,eax
	       jnz     Int_Str1
	       mov     edx,ebx      ; ebx --> count
	       add     edx,4        ; edx --> string data
	       mov     ecx,0        ; ecx = counter
Int_Str1a:
	       or      edi,edi
	       jle     Int_Str2
	       xor     eax,eax
	       mov     al,Number_Fill
	       push    eax
	       dec     edi
	       jmp     Int_Str1a
Int_Str2:
	       pop     eax
	       or      al,al
	       jz      Int_Str3
	       mov     [edx],al
	       inc     edx
	       inc     ecx
	       jmp     Int_Str2
Int_Str3:
	       mov     [ebx],ecx
	       popad
	       ret

Do_Breakpoint: push    edx
	       lea     edx,BreakMsg
	       call    WriteStr
	       pop     edx
	       ret

;
; Preliminary routines to build a foundation word list from
;

	       CodeDef '?STACK'
StackCheck:    mov     eax,StackBase
	       cmp     ebx,eax
	       ja      StackUnderflow
	       sub     eax,STACK_SIZE*4
	       cmp     ebx,eax
	       jbe     StackOverflow
	       ret

StackOverFlow: lea     edx,StackOverMsg
	       call    WriteStr
	       jmp     Abort           ; RESET everything

StackUnderFlow:
	       lea     edx,StackUnderMsg
	       call    WriteStr
	       jmp     Abort           ; RESET everything

DivByZero:     call    DumpRegisters
               lea     EDX,DivByZeroMsg
	       call    WriteStr
	       xor     eax,eax
	       mov     [ebx],eax
	       ret

	       CodeDef 'COMPILE,'
Do_CompileCall:                         ; Compiles a call to address given
	       mov     al,0E8h
	       stosb
	       PULLFORTH

	       sub     eax,EDI          ; subtract current EIP
	       sub     eax,4            ; subtract 4 for upcoming offset
	       stosd
	       ret

WriteLineNum:  mov     eax,LineNumber
	       or      eax,eax
	       jz      WriteLineNum9
	       lea     edx,LineNumMsg
	       call    WriteStr
	       mov     eax,10
	       mov     number_base,eax
	       mov     eax,LineNumber
	       call    WriteEAX
	       call    DoCr
	       xor     eax,eax
	       mov     LineNumber,eax
WriteLineNum9: ret

	       CodeDef 'WORDS'
Do_Words:      pushad
               xor     eax,eax               ; Mod 11/14/93 MAW
               mov     OutLine,eax

	       mov     ecx,offset Context

Do_Words1:     mov     edx,[ecx]
	       or      edx,edx
	       jz      Do_Words_Done         ; if last CURRENT vocabulary
	       add     edx,VocLinkOffset
Do_Words2:     mov     edx,[edx].Prev        ; go backwards in the chain
	       or      edx,edx
	       jz      Do_Words3
	       mov     eax,[edx].NameSize
	       or      eax,eax
	       jz      Do_Words3

	       mov     eax,[edx].Flags
	       test    eax,HIDDEN
	       jnz     Do_Words2             ; Skip if marked HIDDEN
	       push    edx
	       lea     edx,[edx].NameSize
	       call    WriteStr
	       lea     edx,SpStr
	       call    WriteStr
	       call    WriteStr
;               call    QueryCR
	       call    QueryMore             ; Modified 11/14/93 MAW
	       pop     edx
	       jmp     Do_Words2

Do_Words3:     add     ecx,4                 ; Finished 1 vocabulary
	       call    DoCr
	       call    DoCr
	       jmp     Do_Words1

Do_Words_Done: popad
	       ret

	       CodeDef '?CR'
QueryCr:       mov     edx,OutPos
	       add     edx,16
	       cmp     edx,CharPerLine
	       jg      DoCr
	       ret

               CodeDef '?CR-MORE'
QueryMore:     Call    QueryCR
               mov     edx,OutLine
               cmp     edx,MoreLength
               jng     @f
               mov     edx,MoreVector
               call    edx
@@:            ret

               CodeDef 'PAUSE'
Pause:         lea     edx,PauseMsg
               call    WriteStr
               call    GetKey
               PullForth               ; drop it
               lea     edx,PauseClearMsg
               call    WriteStr
               xor     eax,eax
               mov     OutLine,eax
               mov     OutPos,eax
               ret

	       CodeDef 'U*'
	       PULLFORTH
	       mul     DWORD PTR [ebx]
	       mov     [ebx],eax
	       ret

	       CodeDef 'U/'
	       PULLFORTH
	       or      eax,eax
	       jz      DivByZero
	       xchg    eax,[ebx]
	       xor     edx,edx
	       div     DWORD PTR[ebx]
	       mov     [ebx],eax
	       ret

	       CodeDef 'W@'
	       mov     eax,[ebx  ]
	       mov     eax,[eax  ]
	       and     eax,00ffffh
	       mov     [ebx  ],eax
	       ret

	       CodeDef 'W!'
	       mov     edx,[ebx  ]      ; value addr .... poke
	       mov     eax,[ebx+4]
	       mov     [edx],ax
	       add     ebx,8            ; pop both values
	       ret

	       CodeDef 'DEBUG'
	       lea     eax,Debug
	       PUSHFORTH
	       ret

	       CodeDef 'ABORT'          ; Vectored ABORT
Abort:         mov     eax,TickAbort
	       jmp     eax

	       CodeDef "'ABORT"         ; Address of ABORT
	       lea     eax,TickAbort
	       PUSHFORTH
	       ret

	       CodeDef 'EXITCODE'       ; Result code in BYE
	       lea     eax,ExitCode
	       PUSHFORTH
	       ret

	       CodeDef 'HEX'
	       mov     eax,10h
	       mov     Number_Base,eax
	       ret

	       CodeDef '.'             ; Prints number in the current BASE
Do_Dot:        PullForth
	       cmp     eax,0
	       jge     @f
	       push    eax
	       mov     al,'-'
	       PushForth
	       Call    Do_Emit
	       pop     eax
	       neg     eax
	       jmp     @f

	       CodeDef 'U.'            ; Unsigned PRINT
	       PullForth

@@:            Push    ESI
	       Push    ECX
	       Push    EDX
	       push    0
	       mov     ecx,Number_Base
	       lea     ESI,Table
@@:            xor     edx,edx
	       div     ecx             ; AX = Quotient DX = Remainder
	       mov     edx,[edx+esi]
	       push    edx             ; Put the char on the stack
	       or      eax,eax
	       jnz     @b

@@:            pop     eax
	       or      eax,eax
	       jz      @f
	       PushForth
	       Call    Do_emit
	       jmp     @b

@@:            pop     EDX
	       pop     ECX
	       pop     ESI
	       ret

	       CodeDef '.S'            ; Non-Destructive stack print
	       mov     ecx,StackBase
@@:            sub     ecx,4
	       cmp     ecx,ebx
	       jb      @f
	       mov     eax,[ecx]
	       PushForth
	       call    Do_Dot
	       lea     edx,SpStr
	       call    WriteStr
	       jmp     @b

@@:            call    DoCr
	       ret

	       CodeDef 'SP0'
	       mov     eax,StackBase  ; Base of stack
	       PUSHFORTH
	       ret

	       CodeDef 'SP!'           ; Resets user stack pointer
	       mov     ebx,[ebx]
	       ret

	       CodeDef 'SP@'
	       mov     eax,ebx         ; Forth Stack pointer in EAX
	       PUSHFORTH
	       ret

	       CodeDef 'RP0'           ; Get initial return pointer
	       mov     eax,SavedESP
	       PushForth
	       ret

	       CodeDef 'RP@'           ; Get the current return pointer
	       mov     eax,ESP
	       add     eax,4
	       PushForth
	       ret

	       CodeDef 'RP!'           ; Get our return address....
	       pop     edx
	       PullForth
	       mov     esp,eax
	       push    edx
	       ret

	       CodeDef 'CELL'
	       mov     eax,4           ; Word Size in bytes
	       PUSHFORTH
	       ret

	       CodeDef 'COMPILE',CompileOnly
				       ; a REALLY SNEAKY forth word
	       pop     eax             ; get return address
	       mov     edx,eax
	       add     eax,5           ; Modify return address, to skip
	       push    eax             ; the next call instruction
	       inc     edx             ; [edx] is call offset
	       add     eax,[edx]       ; eax now has absolute address of call

	       mov     edx,eax
	       mov     al,0E8h         ; put the CALL instruction
	       stosb
	       mov     eax,edx

	       sub     eax,EDI         ; subtract current EIP
	       sub     eax,4           ; subtract 4 for upcoming offset
	       stosd
	       ret                     ; return with the address changed

; Some useful words let you temporarily store things on the return stack
; Always use >R and R> in pairs

;
;  CREATE       makes a 0 byte variable
;  ALLOT        adds N bytes to the length of the last word created
;  ,            takes N, and adds in into the last word compiled
;  C,           adds C to the last word compiled
;  VARIABLE     makes a 4 byte variable
;  DoesVariable Puts the Return address on the stack
;  DoesConstant Puts the CONTENTS of the Return address on the stack
;



;
; Conditional Branching Logic
;
; IF   - Marks code to be executed ONLY on a TRUE
; ELSE - Marks code to be executed ONLY of false
; THEN - Marks the end of the conditional
;
	       CodeDef 'IF',3           ; ONLY in compile mode
	       Call    CompileCheck
	       cld
	       COMPILES 08Bh,003h,083h,0C3h,004h
	       COMPILES 023h,0C0h,00fh,084h
	       xor     eax,eax
	       stosd                   ; set to 0, for safety
	       mov     eax,edi         ; calc offset of DWORD
	       sub     eax,4
	       PUSHFORTH
	       ret

; Code generated....
; 8B 03            mov      eax,[ebx]
; 83 C3 04         add      ebx,4
; 23 C0            and      eax,eax
; 0F 84 00000000   jz       Next Instruction + Offset....
;

	       CodeDef  'THEN',3       ; ONLY in compile mode
	       Call     CompileCheck
	       push     edi
	       PULLFORTH
	       xchg     EDI,EAX        ; Fixup in EDI, current in EAX
	       sub      eax,edi        ; determine offset of this instruction
	       sub      eax,4          ;   from the patches NEXT instruction
	       stosd                   ; Do the patch
	       pop      edi
	       ret

; for an ELSE
; 1256  E9 00000000      jmp      Next Instruction + Offset....

	       CodeDef  'ELSE',3       ; ONLY in compile mode
	       Call    CompileCheck
	       mov      eax,0E9h
	       stosb                   ; Jump relative 32
	       xor      eax,eax
	       stosd
	       mov      eax,[ebx]      ; get address from IF  (ebx goes back up later)
	       push     edi
	       xchg     edi,eax
	       sub      eax,edi
	       sub      eax,4
	       stosd                   ; Patch IF address
	       pop      edi
	       mov      eax,edi
	       sub      eax,4
	       mov      [ebx],eax      ; replace address with ELSE patch
	       ret
;
; DO ... LOOP logic
;
;
; DO - Takes 2 values from Forth Stack, puts them on the return stack
;      COMPILE: Puts LABEL on stack
;
; LOOP - Increments loop counter, tests for end of loop, if ok, jums to LABEL
;

	       CodeDef 'DO',3          ; COMPILED ONLY, IMMEDIATE

	       Call    CompileCheck
	     COMPILES  08Bh,043h,004h  ; mov   eax,[ebx+4]
	     COMPILES  050h            ; push  eax
	     COMPILES  08Bh,003h       ; mov   eax,[ebx]
	     COMPILES  050h            ; push  eax
	     COMPILES  083h,0C3h,008h  ; add   ebx,8

	       mov     eax,EDI         ; LABEL1:
	       PUSHFORTH
	       ret


	       CodeDef 'LOOP',3             ; CompileOnly, Immediate
	       Call    CompileCheck

	     COMPILES 08bh,004h,024h        ; mov  eax,[esp]
	     COMPILES 040h                  ; inc  eax
	     COMPILES 089h,004h,024h        ; mov  [esp],eax
	     COMPILES 03bh,044h,024h,004h   ; cmp  eax,[esp+4]
	     COMPILES 00fh,08ch             ; jl   RELATIVE32
	       PULLFORTH
	       sub     eax,EDI
	       sub     eax,4                ; calculate from next instruction
	       STOSD
	     COMPILES 083h,0c4h,008h        ; add  esp,8
	       ret



	       CodeDef '<+LOOP>',HIDDEN  ; Smart +LOOP can count down or up
PlusLoop1:     pop     edx
	       PULLFORTH
	       add     [esp],eax
	       mov     ecx,[esp]
	       or      eax,eax
	       jge     PlusLoop2
	       cmp     4 [esp],ecx
	       jmp     PlusLoop3
PlusLoop2:     cmp     ecx,4 [esp]
PlusLoop3:     jge     PlusLoop9
	       add     edx,[edx]
	       add     edx,4
	       jmp     edx         ; loop back
PlusLoop9:     add     edx,4       ; skip loop-back offset
	       add     esp,8       ; drop loop variables
	       jmp     edx

	       CodeDef '+LOOP',3            ; CompileOnly, Immediate
	       Call    CompileCheck
	       lea     eax,PlusLoop1
	       PUSHFORTH
	       call    Do_CompileCall
	       PULLFORTH
	       sub     eax,EDI
	       sub     eax,4                ; calculate from next instruction
	       STOSD
	       ret


; A word which goes along with these will copy the value pushed onto
;  the return stack with R> onto the parameter stack.

	       CodeDef 'K'         ; 1 loop up
	       mov     eax,[esp+20] ; return, index, limit, index, limit, index
	       PushForth
	       ret

	       CodeDef 'LEAVE'     ; leave a DO...LOOP
	       mov     eax,[esp+8]
	       mov     [esp+4],eax
	       ret

	       CodeDef 'UNLOOP'    ; remove loop variables from stack
	       mov     eax,[esp]
	       add     esp,8
	       mov     [esp],eax
	       ret

;
; FOR ... NEXT logic
;
;
; FOR - Takes 2 values from Forth Stack, puts them on the return stack
;      MARKER - Take values from stack, if past bound PATCHUP, skip body
;
; NEXT- Does Patchup, Compiles Jump to MARKER
;
; DESIRED RESULT:
;
; 1302  8B 43 04                               mov     eax,[ebx+4]     ; MOVE values to return stack
; 1305  50                                     push    eax
; 1306  8B 03                                  mov     eax,[ebx]
; 1308  50                                     push    eax
; 1309  83 C3 08                               add     ebx,8           ; bump counter appropriately
; 130C  58                      LABEL1:        pop     eax
; 130D  5A                                     pop     edx
; 130E  3B C2                                  cmp     eax,edx
; 1310  73 11                                  jae     LABEL2
; 1312  52                                     push    edx
; 1313  50                                     push    eax
;
; 1314  BA 000000B0 R                          lea     edx,GreetMsg
; 1319  E8 FFFFEF91                            call    WriteStr
;
; 131E  58                                     pop     eax
; 131F  40                                     inc     eax
; 1320  50                                     push    eax
; 1321  EB E9                                  jmp     LABEL1
;
; 1323                          LABEL2:
; 1323  C3                                     ret
	       CodeDef 'FOR',3         ; COMPILED ONLY, IMMEDIATE
	       Call    CompileCheck

	       COMPILES 08Bh,043h,004h ; mov   eax,[ebx+4]
	       COMPILES 050h           ; push  eax
	       COMPILES 08Bh,003h      ; mov   eax,[ebx]
	       COMPILES 050h           ; push  eax
	       COMPILES 083h,0C3h,008h ; add   eax,8

	       mov     eax,EDI         ; LABEL1: Jump back point
	       PUSHFORTH

	       COMPILES 058h           ; pop   eax
	       COMPILES 05Ah           ; pop   edx
	       COMPILES 03Bh,0C2h      ; cmp   eax,edx
	       COMPILES 00fh,083h      ; jea   relative 32

	       mov     eax,EDI         ;       patch point to LABEL2
	       PUSHFORTH
	       xor     eax,eax
	       stosd

	       COMPILES 052h           ; push  edx
	       COMPILES 050h           ; push  eax
	       ret


; 131E  58                                     pop     eax
; 131F  40                                     inc     eax
; 1320  50                                     push    eax
; 1321  EB E9                                  jmp     LABEL1
;
; 1323                          LABEL2:

	       CodeDef 'NEXT',3        ; Compile ONLY, Immediate
	       Call    CompileCheck

	       mov     al,058h         ; pop   eax
	       stosb
	       mov     al,040h         ; inc   eax
	       stosb
	       mov     al,050h         ; push  eax
	       stosb
	       mov     al,0E9h         ; jmp   Relative 32
	       stosb
	       mov     eax,[ebx+4]     ; EAX = LABEL1
	       sub     eax,edi         ; DELTA = LABEL1 - NEXT INSTRUCTION
	       sub     eax,4
	       stosd                   ; Do the backward jump....

	       mov     eax,edi         ;
	       sub     eax,[ebx]       ; Offset = Current - (Patch+4)
	       sub     eax,4
	       push    edi
	       mov     edi,[ebx]
	       STOSD
	       pop     edi
	       add     ebx,8           ; drop 2 stack entries
	       ret

	       CodeDef '>='            ; i.e. 5 5 >=
	       pullforth               ; eax = stack top 5
	       cmp     eax,[ebx]
	       mov     eax,0
	       jg      @f
	       dec     eax
@@:            mov     [ebx],eax
	       ret

	       CodeDef '<='
	       pullforth
	       cmp      eax,[ebx]
	       mov      eax,0
	       jl       @f
	       dec      eax
@@:            mov     [ebx],eax
	       ret

	       CodeDef '<>'            ; True if A <> B
	       pullforth
	       cmp     eax,[ebx]
	       mov     eax,0
	       jz      @f
	       not     eax
@@:            mov     [ebx],eax
	       ret

	       CodeDef 'NOT'          ; 1s complement
	       not     dword ptr[ebx]
	       ret

	       CodeDef 'U*/MOD'       ; ( a b c -- remainder quotient )
	       mov     eax,[ebx+8]
	       mul     DWORD PTR[ebx+4]
	       cmp     edx,[ebx]
	       jg      DivByZero
	       div     DWORD PTR[ebx]
	       add     ebx,4
	       mov     [ebx],eax      ; Store Quotient
	       mov     [ebx+4],edx    ; Store Remainder
	       ret

	       CodeDef 'FOPEN'      ; ( -- handle )
Fopen:         mov     eax,0ffffffffh
	       mov     FopenHandle,eax
	       pushad
	       pushd   0            ; PEAOP2 (not used, must be 0 )
	       mov     eax,esp
	       push    eax
	       pushd   020h         ; Readonly, deny write
	       pushd   001h         ; Open, fail if non-existant
	       pushd   000h         ; Normal attributes
	       pushd   0            ; Don't change file size
	       lea     eax,FopenAction
	       push    eax
	       lea     eax,FopenHandle
	       push    eax
	       lea     eax,FopenName
	       push    eax
	       call    Dos32Open
	       add     esp,36       ; Drop all of the stuff from the stack
	       popad
	       mov     eax,FopenHandle
	       PushForth            ; put the handle on the stack
	       ret

	       CodeDef 'CLOSE'     ; ( handle -- )
FClose:        PullForth
	       pushad
	       push    eax
	       call    Dos32Close
	       add     esp,4
	       popad
	       ret

	       CodeDef 'FREAD'      ; ( handle size -- bytes_read )
FRead:         PullForth            ; eax is size
	       mov     edx,eax
	       pushad
	       push    ebx          ; point at parameter on stack
	       push    edx          ; number of bytes to read
	       lea     eax,FileBuffer
	       push    eax
	       mov     eax,[ebx]    ; handle
	       push    eax
	       call    Dos32Read
	       add     esp,16
	       popad
	       ret

	       CodeDef 'FBUFFER'
	       lea     eax,FileBuffer
	       pushforth
	       ret

	       CodeDef 'LINE#'
	       lea     eax,LineNumber
	       PUSHFORTH
	       ret


	       CodeDef 'BYE'           ; Exit Forth Environment
BYE:           pushd   1
	       mov     eax,ExitCode
	       push    eax
	       call    Dos32Exit


	       CodeDef 'INTERPRET'
Interpret:
	       mov     eax,' '
	       PushForth
	       call    _Word
	       mov     eax,[ebx]       ; address of string
	       mov     eax,[eax]       ; count
	       jz      Interpret8      ; (Null string, bail out)

	       call    _Find           ; 0 = Not found
	       PullForth               ; 1 = Immediate
	       or      eax,eax         ;-1 = Normal
	       jz      InterpretNumber
;
; We have an address, decide if it should be compiled or called.
;
	       test    CompileMode,1
	       jz      @f
;
; This is the "compile mode" branch of things
;
	       cmp     eax,1                   ; is it immediate?
	       jz      @f
	       call    Do_CompileCall          ; No, compile it
	       jmp     Interpret
;
; This is the interpretive branch
;
@@:            call    _Execute                ; Execute a function
	       jmp     Interpret

Interpret8:    pullforth
Interpret9:
	       ret

;
; Handle a possible number, counted string on stack
;
InterpretNumber:
	       call    _NumberQ
	       pullForth
	       or      eax,eax
	       jz      Interpret_NonNumber

	       test    CompileMode,1
	       jz      @f
	       call    _Literal
@@:            jmp     Interpret

Interpret_NonNumber:
	       mov     eax,[ebx]                 ; Peek at stack top
	       mov     eax,[eax]                 ; get string length
	       or      eax,eax                   ; Don't warn if it's 0 chars
	       jz      Interpret8

	       lea     edx,What1Msg
	       call    WriteStr

	       Call    _Count
	       Call    _Type
	       lea     edx,What2Msg
	       call    WriteStr
	       call    WriteLineNum
	       jmp     Abort

	       CodeDef 'PROMPT'
Prompt:        call    DoCr
	       lea     edx,PromptMsg
	       call    WriteStr
	       ret

	       CodeDef 'DP!'
	       PullForth
	       mov     edi,eax
	       mov     CodeSpace,EDI
	       ret

	       CodeDef '?COMPILE'       ; Only works if we're compiling
CompileCheck:  test    CompileMode,1
	       jz      @f
	       ret
@@:            lea     edx,CompileOnlyMsg
	       call    WriteStr
	       call    WriteLineNum
	       jmp     Abort            ; RESET everything


	       CodeDef '[COMPILE]',3    ; Compiles the next word, regardless
	       Call    CompileCheck
	       call    Tick
	       PullForth
	       mov     eax,[eax].CodePointer
	       PushForth
	       call    Do_CompileCall
	       ret

	       CodeDef 'POSTPONE',IMMEDIATE ; Compiles the next word
	       CLD
	       Call    CompileCheck
	       call    Tick
	       lea     edx,PostponeImmediate
	       cmp     eax,1               ;  1 = Immediate
	       jz      @f
	       lea     edx,PostponeNormal  ; -1 = Normal
@@:            mov     eax,edx
               PushForth                   ; compile call to postpone routine
               call    Do_CompileCall      ; eats param
               PullForth                   ; eats other param
	       stosd
	       mov     CodeSpace,edi
	       ret


PostponeImmediate:
	       pop     edx
	       mov     eax,[edx]
	       add     edx,4
	       push    edx
	       jmp     eax

PostPoneNormal:
	       pop     edx
	       mov     eax,[edx]
	       add     edx,4
	       push    edx
	       pushforth
	       call    Do_CompileCall
	       ret

;
; New version 11/14/93 MAW
; old version relied on a fixed header size.
;
DoDoes:        mov     edx,NewWord      ; Address of the latest word...
	       mov     edx,[edx].CodePointer  ; get address of code
               inc     edx              ; skip CALL opcode
	       Pop     EAX              ; Address to jump to....
					; Note: We never return to it!
	       sub     eax,EDX          ; subtract current EIP
	       sub     eax,4            ; subtract 4 for upcoming offset
	       mov     [edx],eax

	       mov     CodeSpace,EDI
	       ret


	       CodeDef 'DOES>',3        ; Compile Only, Immediate
Does:          Call    CompileCheck
	       lea     eax,DoDoes
	       PushForth
	       Call    Do_CompileCall   ; Put the call to DoDoes in the
					; def that uses DOES>
	       Compiles 058h            ; pop     eax
	       Compiles 083h,0ebh,004h  ; sub     ebx,4
	       Compiles 089h,003h       ; mov     [ebx],eax
	       ret

	       CodeDef 'LAST'           ; The LAST word defined
	       mov     eax,Current
	       mov     eax,[eax+VocLinkOffset]
	       PushForth
	       ret

	       CodeDef '%TO'
	       lea     eax,SysTo
	       PUSHFORTH
	       ret

	       CodeDef 'TO'
	       mov     eax,1
	       mov     SysTo,eax
	       ret

	       CodeDef '+TO'
	       mov     eax,-1
	       mov     SysTo,eax
	       ret

	       CodeDef '<TODOES>'    ; For TO variables
	       mov     eax,SysTo
	       or      eax,eax
	       jz      Fetch
	       xor     ecx,ecx
	       mov     SysTo,ecx     ; reset TO state
	       or      eax,eax
	       jg      Store
	       ja      PlusStore

	       CodeDef 'DROPS'         ; DROPS n items off the stack
Drops:         inc     DWORD PTR [ebx]
	       shl     DWORD PTR [ebx],1
	       shl     DWORD PTR [ebx],1
	       add     ebx,[ebx]
	       ret

	       CodeDef 'DPL'  ; variable holding decimal point position
	       lea     eax,DPL
	       PUSHFORTH
	       ret

	       CodeDef 'ROLL'     ; ( n -- ) moves n'th word on stack to top
	       PullForth
	       cmp     eax,1      ; not defined for n <= 1
	       jle     @f
	       push    edi
	       push    esi
	       dec     eax
	       mov     ecx,eax
	       dec     eax
	       shl     eax,1
	       shl     eax,1
	       mov     esi,ebx
	       add     esi,eax    ; start from n'th element
	       mov     edi,ebx
	       add     edi,eax
	       add     edi,4
	       add     eax,ebx
	       mov     eax,[eax+4] ; copy ROLL'd value
	       std                 ; move words up
	       rep movsd           ; move stack up
	       cld
	       mov     [ebx],eax  ; store ROLL'd value
	       pop     esi
	       pop     edi
@@:            ret

	       CodeDef 'CMOVE>'   ; ( src dest n -- ) moves n bytes up
CmoveBack:     PullForth
	       cmp     eax,1      ; not defined for n < 1
	       jl      @f
	       push    edi
	       push    esi
	       mov     ecx,eax
	       dec     eax
	       mov     esi,[ebx+4]
	       add     esi,eax    ; start from n'th byte
	       mov     edi,[ebx]
	       add     edi,eax
	       std
	       rep movsb          ; move bytes up
	       cld
	       pop     esi
	       pop     edi
@@:            add     ebx,8
	       ret

	       CodeDef 'CMOVE'    ; ( src dest n -- ) moves n bytes
Cmove:         PullForth
	       cmp     eax,1      ; not defined for n < 1
	       jl      @f
	       push    edi
	       push    esi
	       mov     ecx,eax
	       mov     esi,[ebx+4]
	       mov     edi,[ebx]
	       rep movsb
	       pop     esi
	       pop     edi
@@:            add     ebx,8
	       ret

	       CodeDef  "=STRING"  ; ( addr len "string" -- f )
EqualString:   push    esi
	       push    edx
	       push    ecx
	       mov     esi,[ebx]   ; esi=string
	       mov     ecx,[ebx+4] ; ecx=len    for LOOP
	       add     ebx,8
	       mov     edx,[ebx]
	       push    ebx         ; Save STACK, we're using EBX
	       lea     ebx,UpperCaseTable
	       cld
	       lodsd               ; Length of string1 in eax
	       cmp     eax,ecx     ; compare string lengths
	       jnz     NotEqual
	       jmp     EqualStr1

	       CodeDef '@+'        ; ( addr -- addr+4 [addr] )
	       mov     edx,[ebx]
	       mov     eax,[edx]
	       add     edx,4
	       mov     [ebx],edx
	       PushForth
	       ret

	       CodeDef 'NIP'       ; ( n1 n2 -- n2 )
	       PullForth
	       mov     [ebx],eax
	       ret

	       CodeDef 'PICK'      ; Copies n'th item to top
	       mov     eax,[ebx]
	       cmp     eax,1      ; not defined for n <= 1
	       jl      @f
	       shl     eax,1
	       shl     eax,1
	       add     eax,ebx
	       mov     eax,[eax]
	       mov     [ebx],eax
@@:            ret

	       CodeDef '#OUT'       ; Output position
	       lea     eax,DWORD PTR OutPos
	       PushForth
	       ret

	       CodeDef 'WITHIN'     ; ( n1 n2 n3 -- f ) True if n1<=n2<=n3
	       xor     edx,edx
	       mov     eax,[ebx+8]
	       cmp     eax,[ebx]    ; cmp n1,n3
	       jg      @f
	       cmp     eax,[ebx+4]  ; cmp n1,n2
	       jl      @f
	       dec     edx
@@:            add     ebx,8
	       mov     [ebx],edx
	       ret

	       CodeDef 'CURRENT'    ; Vocabulary where definitions are added
	       lea     eax,WORD PTR Current
	       PushForth
	       ret

	       CodeDef 'CONTEXT'    ; Vocabulary where words are searched for
	       lea     eax,WORD PTR Context
	       PushForth
	       ret

	       CodeDef 'CONTEXTSIZE'  ; Size in words of CONTEXT
	       mov     eax,ContextSize
	       PushForth
	       ret

	       CodeDef 'VOC-LINK'   ; Location of most recent vocabulary
	       lea     eax,WORD PTR Voc_link
	       PushForth
	       ret

	       CodeDef '<VOCABULARY>' ; ( vocabulary -- ) Adds voc to CONTEXT
DoVocabulary:  push    esi
	       push    edi
	       mov     edi,offset Context  ; list of search vocabularies
	       mov     eax,[ebx]           ; check if vocab already listed
	       mov     ecx,ContextSize-1   ; max # of vocabularies
	       cld
	       repne scasd                 ; Look for the vocabulary
	       or      ecx,ecx
	       jnz     RollVocab           ; If already listed, roll to top

	       mov     edx,[ebx]
	       jmp     ShiftVocab

;              mov     edi,offset Context
;              xor     eax,eax
;              mov     ecx,ContextSize-1
;              repne scasd                 ; Look for the first 0
;              mov     eax,[ebx]
;              mov     [edi-4],eax         ; Vocabulary to add to Context

RollVocab:     mov     eax,edi
	       cmp     eax,offset Context+4
	       je      DoVocab9            ; If vocab is already first
	       mov     edx,[edi-4]         ; vocab to roll to top

ShiftVocab:    sub     edi,4
	       mov     esi,edi
	       sub     esi,4
	       neg     ecx
	       add     ecx,ContextSize-2
	       std
	       rep movsd                   ; move vocabs down
	       cld
	       mov     Context,edx         ; store vocabulary at top

DoVocab9:      pop     edi
	       pop     esi
	       add     ebx,4
	       ret

SetVocabulary: pop     eax           ; Expects a vocab record after it
	       PUSHFORTH
	       call    DoVocabulary
	       ret

		 CodeDef 'FORTH',IMMEDIATE
ForthVoc:        lea     eax,ForthLink
		 PUSHFORTH
		 call    DoVocabulary
		 ret
; ForthVoc:      call    SetVocabulary
; ForthLink      dd      0,LastForthWord,0       ; FORTH vocabulary pointer


		 CodeDef 'SYSTEM',1       ; SYSTEM vocabulary
SysVoc:          lea     eax,SysLink
		 PUSHFORTH
		 call    DoVocabulary
		 ret
; SysVoc:        call    SetVocabulary
; SysLink        dd      0,LastHeader,ForthLink  ; SYSTEM vocabulary pointer


	       CodeDef 'FALSE'                 ; Core extension
	       xor     eax,eax
	       PUSHFORTH
	       ret

	       CodeDef 'TRUE'                  ; Core extension
	       xor     eax,eax
	       dec     eax
	       PUSHFORTH
	       ret

LastForthWord  =       LastHeader
LastHeader     =       0

	       CodeDef 'MS'
	       PullForth
	       Push    EAX
	       Call    Dos32Sleep
	       Add     ESP,4
	       ret

	       CodeDef 'SYS$BEEP'
	       lea     eax,Dos32Beep
	       PushForth
	       ret

	       CodeDef 'SYS$CALLNPIPE'
	       lea     eax,Dos32CallNPipe
	       PushForth
	       ret

	       CodeDef 'SYS$CLOSE'
	       lea     eax,Dos32Close
	       PushForth
	       ret

	       CodeDef 'SYS$CONNECTNPIPE'
	       lea     eax,Dos32ConnectNPipe
	       PushForth
	       ret

	       CodeDef 'SYS$CREATENPIPE'
	       lea     eax,Dos32CreateNPipe
	       PushForth
	       ret

	       CodeDef 'SYS$CREATETHREAD'
	       lea     eax,Dos32CreateThread
	       PushForth
	       ret

	       CodeDef 'SYS$DEVIOCTL'
	       lea     eax,Dos32DevIOCtl
	       PushForth
	       ret

	       CodeDef 'SYS$DISCONNECTNPIPE'
	       lea     eax,Dos32ExecPgm
	       PushForth
	       ret

	       CodeDef 'SYS$EXECPGM'
	       lea     eax,Dos32ExecPgm
	       PushForth
	       ret

	       CodeDef 'SYS$EXIT'
	       lea     eax,Dos32Exit
	       PushForth
	       ret

	       CodeDef 'SYS$FREEMODULE'
	       lea     eax,Dos32FreeModule
	       PushForth
	       ret

               CodeDef 'Sys$GetDateTime'
               lea     eax,Dos32GetDateTime
               PushForth
               ret

               CodeDef 'Sys$GetInfoBlocks'
               lea     eax,Dos32GetInfoBlocks
               PushForth
               ret

	       CodeDef 'SYS$KILLPROCESS'
	       lea     eax,Dos32KillProcess
	       PushForth
	       ret

	       CodeDef 'SYS$KILLTHREAD'
	       lea     eax,Dos32KillThread
	       PushForth
	       ret

	       CodeDef 'SYS$LOADMODULE'
	       lea     eax,Dos32LoadModule
	       PushForth
	       ret

	       CodeDef 'SYS$OPEN'
	       lea     eax,Dos32Open
	       PushForth
	       ret

	       CodeDef 'SYS$PEEKNPIPE'
	       lea     eax,Dos32PeekNPipe
	       PushForth
	       ret

	       CodeDef 'SYS$QUERYMODULEHANDLE'
	       lea     eax,Dos32QueryModuleHandle
	       PushForth
	       ret

	       CodeDef 'SYS$QUERYMODULENAME'
	       lea     eax,Dos32QueryModuleName
	       PushForth
	       ret

	       CodeDef 'SYS$QUERYNPHSTATE'
	       lea     eax,Dos32QueryNPHState
	       PushForth
	       ret

	       CodeDef 'SYS$QUERYNPIPEINFO'
	       lea     eax,Dos32QueryNPipeInfo
	       PushForth
	       ret

	       CodeDef 'SYS$QUERYPROCADDR'
	       lea     eax,Dos32QueryProcAddr
	       PushForth
	       ret

	       CodeDef 'SYS$QUERYPROCTYPE'
	       lea     eax,Dos32QueryProcType
	       PushForth
	       ret

	       CodeDef 'SYS$READ'
	       lea     eax,Dos32Read
	       PushForth
	       ret

	       CodeDef 'SYS$RESUMETHREAD'
	       lea     eax,Dos32ResumeThread
	       PushForth
	       ret

	       CodeDef 'SYS$SEEK'
	       lea     eax,Dos32SetFilePtr
	       PushForth
	       ret

	       CodeDef 'SYS$SETNPHSTATE'
	       lea     eax,Dos32SetNPHState
	       PushForth
	       ret

	       CodeDef 'SYS$SLEEP'
	       lea     eax,Dos32Sleep
	       PushForth
	       ret

	       CodeDef 'SYS$STARTSESSION'
	       lea     eax,Dos32StartSession
	       PushForth
	       ret

	       CodeDef 'SYS$SUSPENDTHREAD'
	       lea     eax,Dos32SuspendThread
	       PushForth
	       ret

	       CodeDef 'SYS$TRANSACTNPIPE'
	       lea     eax,Dos32TransactNPipe
	       PushForth
	       ret

	       CodeDef 'SYS$WAITCHILD'
	       lea     eax,Dos32WaitChild
	       PushForth
	       ret

	       CodeDef 'SYS$WAITNPIPE'
	       lea     eax,Dos32WaitNPipe
	       PushForth
	       ret

	       CodeDef 'SYS$WAITTHREAD'
	       lea     eax,Dos32WaitThread
	       PushForth
	       ret

	       CodeDef 'SYS$WRITE'
	       lea     eax,Dos32Write
	       PushForth
	       ret


	       CodeDef 'SYS$SHUTDOWN'
	       lea     eax,Dos32ShutDown
	       PushForth
	       ret

	       CodeDef 'ENVIRONMENT'
	       mov     EAX,Environment
	       PUSHFORTH
	       ret

	       CodeDef 'COMMANDLINE'
	       mov     EAX,CommandLine
	       PUSHFORTH
	       ret

               CodeDef 'THREADPROC'    ; Sets up thread then jumps to it
               pushd   0
               mov     edx,esp         ; Where base addr is to be stored

               pushd   012h            ; Write Un-committed
               pushd   UserAreaSize
               push    edx
               call    Dos32AllocMem   ; Allocate USER variable area
               and     eax,eax
               jnz     Bye
               add     esp,12

               mov     ebx,esp
               sub     ebx,RSTACK_SIZE ; Set user stack below return stack
               add     ebx,12          ; Correct for ThreadArg, EIP, USER0

               mov     edx,[esp+8]     ; get address of thread parameters
               mov     esi,[edx]       ;   which is stored at ThreadArg
               mov     esi,[esi]       ; Address of default user area

               mov     edi,[esp]       ; edi gets new USER area base address

               mov     UREG,esi
               mov     ecx,UserVPtr    ; Length of default USER area
               lea     eax,UserVPtr
               sub     ecx,eax      ; ecx=size of user area to copy
               shr     ecx,1        ; divide by 4
               shr     ecx,1
               rep     movsd        ; Copy user area to new user area

               pop     UREG         ; User variable base address
               mov     edi,CodeSpace

               mov     StackBase,ebx  ; Update StackBase for this thread

               mov     edx,[esp+4]  ; Address of ThreadArg
               mov     edx,[edx]
               mov     eax,[edx+4]  ; Address of thread code
               jmp     eax
               ret

               CodeDef 'USER0'       ; Start of USER variable area
               sub     ebx,4
               mov     [ebx],UREG
               ret

               CodeDef 'UDP'         ; USER variable pointer
               lea     eax,UserVPtr
               PUSHFORTH
               ret

               CodeDef "'USER"       ; Address of default USER area
               lea     eax,UserDefaultPtr
               PUSHFORTH
               ret

               CodeDef "<USER>"      ; Pushes address of USER variable
Do_User:       pop     eax
               mov     eax,[eax]
               add     eax,UREG
               PUSHFORTH
               ret

               CodeDef 'USER'        ; create USER variable
               call    Do_Colon
               mov     eax,UserVPtr
               add     eax,4         ; Add check to see if past limit
               mov     UserVPtr,eax
               sub     eax,4
               sub     eax,UREG
               PUSHFORTH
               lea     eax,Do_User
               PUSHFORTH
               call    Do_CompileCall
               call    Comma
               xor     eax,eax
               mov     CompileMode,eax
               mov     eax,NewWord      ; update the dictionary
               mov     edx,Current
               mov     [edx+VocLinkOffset],eax ; update Current vocab ptr
               ret

               CodeDef 'VERSION'
               lea     edx,WelcomeMsg
	       call    WriteStr
               Call    DoCR
               ret


;
;*********** FLOATING POINT WORDS
;
	       CodeDef 'FCLEAR'  ; Initializes everything
	       FINIT
	       PUSHD   037fh
	       FLDCW   [ESP]     ; Double Precision, round towards nearest
	       ADD     ESP,4
	       ret

	       CodeDef 'D>F'     ; Convert an Integer to the real stack
	       FILD    Dword Ptr[EBX]
	       add     EBX,4
	       ret

	       CodeDef 'F>D'     ; Truncate to forth stack
	       sub     EBX,4

	       PUSHD   0f7fh     ; Modify control value
	       FLDCW   [ESP]
	       ADD     ESP,4

	       FISTP   DWord Ptr[EBX]

	       PUSHD   037fh     ; Set it back
	       FLDCW   [ESP]
	       ADD     ESP,4
	       ret


	       CodeDef 'F@'
	       PullForth
	       FLD     QWORD PTR [EAX]
	       ret

	       CodeDef 'F!'
	       PullForth
	       FSTP    QWORD PTR [EAX]
	       ret

	       CodeDef 'F+'
	       FADDP   ST(1),ST
	       ret

	       CodeDef 'F-'
	       FSUBP   ST(1),ST
	       ret

	       CodeDef 'F*'
	       FMULP   ST(1),ST
	       ret

	       CodeDef 'F/'
	       FDIV
	       ret

	       CodeDef 'F0<'
	       FTST
	       FSTSW   AX
	       SAHF
	       MOV     EAX,0
	       SBB     EAX,0
	       PushForth
	       ret

	       CodeDef 'F0='
	       FTST
	       FSTSW   AX
	       SAHF
	       MOV     EAX,0
	       JNZ     @F
	       MOV     EAX,-1
@@:            RET

	       CodeDef 'F<'
	       FCOMPP
	       FSTSW   AX
	       SAHF
	       MOV     EAX,0
	       SBB     EAX,0
	       PushForth
	       ret

	       CodeDef 'FDROP'
	       FFREE   ST         ; free the register
	       FINCSTP            ; bump the stack counter
	       ret

	       CodeDef 'FDUP'
	       FLD     ST
	       ret


	       CodeDef 'FSWAP'
	       FXCH    ST(1)
	       ret

	       CodeDef 'FVARIABLE'
	       call    Create
	       mov     eax,8
	       PUSHFORTH
	       call    Allot
	       ret

	       CodeDef 'FLOOR'
	       PUSHD   0f7fh      ; Modify control value
	       FLDCW   [ESP]
	       ADD     ESP,4

	       FRNDINT

	       PUSHD   037fh      ; Set it back
	       FLDCW   [ESP]
	       ADD     ESP,4
	       RET

	       CodeDef 'FROUND'   ; Round to nearest
	       FRNDINT
	       RET

	       CodeDef 'FDEPTH'   ; Depth of Stack...
	       FSTSW   AX
	       AND     EAX,00003c00h
	       SHR     EAX,11
	       XOR     EAX,7
	       INC     EAX
	       AND     EAX,7
	       PUSHForth
	       Ret

	       CodeDef 'FALIGN'
	       ret

	       CodeDef 'FALIGNED'
	       ret

DoesFConstant: pop     eax
	       FLD     Qword Ptr[eax]
	       ret


;
;***** Floating Point EXTENSION words *****
;
	       CodeDef 'FABS'
	       FABS
	       ret

	       CodeDef 'FCOS'
	       FCOS
	       ret

	       CodeDef 'FSIN'
	       FSIN
	       ret

	       CodeDef 'FSINCOS'
	       FSINCOS
	       ret

	       CodeDef 'FSQRT'
	       FSQRT
	       ret

;
; Code FOR F. - What a pig!
;
CvtDigit:      cmp     eax,Number_Base
	       jae     BadDigit

	       cmp     eax,0
	       jb      BadDigit

	       lea     ESI,Table
	       mov     al,[esi+eax]
	       ret

BadDigit:      mov     eax,'?'
	       ret


	       CodeDef 'F.'

	       PUSHAD

	       XOR     EAX,EAX    ; Push a 0 to the stack
	       Push    EAX
	       MOV     EDI,0      ; EDI is EXPONENT in this app!

	       FTST
	       FSTSW   AX
	       SAHF
	       JAE     @f
	       MOV     EAX,'-'
	       PushForth
	       Call    Do_Emit

@@:            FABS               ; FStack top >= 0
	       Push    07fffffffh
	       FICOM   Dword Ptr[ESP]
	       ADD     ESP,4      ; Compare to maxint
	       FSTSW   AX
	       SAHF
	       JB      ShowFloat

@@:            FIDIV   Number_Base
	       INC     EDI
	       FICOM   Number_Base
	       FSTSW   AX
	       SAHF
	       JAE     @b

ShowFloat:     PUSHD   0f7fh      ; Modify control value
	       FLDCW   [ESP]      ; FLOOR mode
	       ADD     ESP,4

	       PUSH    EAX
	       FLD     ST         ; Dup Stack Top -- X,X
	       FRNDINT            ;                  Trunc(X),X
	       FIST    Dword Ptr[ESP] ;              Trunc(X),X
	       FSUBP   ST(1),ST   ;                  Frac(X)
	       POP     EAX        ; Whole in EAX

	       mov     ecx,Number_Base
	       lea     ESI,Table
@@:            xor     edx,edx
	       div     ecx             ; AX = Quotient DX = Remainder

	       xchg    edx,eax
	       call    CvtDigit
	       xchg    edx,eax

	       push    edx             ; Put the char on the stack
	       or      eax,eax
	       jnz     @b

@@:            pop     eax
	       or      eax,eax
	       jz      FPrintFrac
	       PushForth
	       Call    Do_emit
	       jmp     @b

;
; Print The Fraction in ST
;
FprintFrac:    mov     eax,'.'         ; Put the decimal point
	       PushForth
	       Call    Do_Emit         ; FRAC(X)

@@:            FIMUL   Number_Base     ; FRAC(X)*10?
	       Push    EAX
	       FIST    Dword Ptr[ESP]
	       Pop     EAX
	       Call    CvtDigit
	       PushForth
	       call    Do_Emit

	       FTST
	       FSTSW   AX
	       SAHF
	       JZ      @f
	       FLD     ST         ; Dup Stack Top -- X,X
	       FRNDINT
	       FSUBP   ST(1),ST
	       JMP     @b

@@:            FFREE   ST         ; free the register
	       FINCSTP            ; bump the stack counter

	       CMP     EDI,0
	       JZ      FPrintDone
	       MOV     EAX,'E'
	       PushForth
	       Call    Do_Emit

	       MOV     EAX,'+'
	       CMP     EDI,0
	       JA      @F
	       MOV     EAX,'-'
;               NEG     EBP
               NEG     EDI             ; MOD 11/20/93 MAW
@@:            PushForth
	       Call    Do_Emit
	       MOV     EAX,EDI

	       push    0
	       mov     ecx,Number_Base
	       lea     ESI,Table
@@:            xor     edx,edx
	       div     ecx             ; AX = Quotient DX = Remainder

	       xchg    edx,eax
	       call    CvtDigit
	       xchg    edx,eax

	       push    edx             ; Put the char on the stack
	       or      eax,eax
	       jnz     @b

@@:            pop     eax
	       or      eax,eax
	       jz      FPrintDone
	       PushForth
	       Call    Do_emit
	       jmp     @b

FprintDone:    PUSHD   037fh      ; Set round mode
	       FLDCW   [ESP]
	       ADD     ESP,4

	       POPAD
	       RET


	       CodeDef 'NOP'
	       ret

	       CodeDef 'PI'
	       FLDPI
	       ret

	       CodeDef 'CIN'            ; ( addr -- data )
	       mov     eax,esp          ; save current ss, esp
	       push    ss               ; for return from 16-bit land
	       push    eax
	       mov     eax,esp          ; convert stack so 16-bit can use it
	       ror     eax,16
	       shl     eax,3
	       or      al,7             ; convert to ring-3 tiled segment
	       mov     ss,eax

	       mov     edx,[ebx]
	       xor     eax,eax
	       jmp     far ptr Do_inp16

Do_inp2        label   far
	       movzx   esp,sp           ; make sure that esp is correct
	       lss     esp,[esp]
	       mov     [ebx],eax
	       ret

	       CodeDef 'COUT'           ; ( data addr -- )
	       mov     eax,esp          ; save current ss, esp
	       push    ss               ; for return from 16-bit land
	       push    eax
	       mov     eax,esp          ; convert stack so 16-bit can use it
	       ror     eax,16
	       shl     eax,3
	       or      al,7             ; convert to ring-3 tiled segment
	       mov     ss,eax

	       PullForth
	       mov     edx,eax
	       PullForth
	       jmp     far ptr Do_out16

Do_out2        label   far
	       movzx   esp,sp           ; make sure that esp is correct
	       lss     esp,[esp]
	       ret

MYCODE         SEGMENT PARA USE16 PUBLIC 'CODE'
Do_Emit16      LABEL   FAR16
	       call    VIOwrtTTY
	       add     sp,4             ; toss the parameters for the DOS16 call
	       jmp     FLAT:Do_Emit2

Do_GetKey16    LABEL   FAR16
	       call    KbdCharIn
	       jmp     FLAT:Do_GetKey2

Do_inp16       LABEL   FAR16
	       call    @inp
	       jmp     FLAT:DO_inp2

Do_Out16       LABEL   FAR16
	       call    @outp
	       jmp     FLAT:DO_out2

MYCODE         ends

	       .code

	       end     main

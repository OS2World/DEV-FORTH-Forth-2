; ******************************************************************
;   <portio.asm> code file
;
;   Function definitions for port access routines
;        inp(port)   - read single byte from I/O port
;        inpw(port)  - read single word from I/O port pair
;        outp(port)  - write single byte to I/O port
;        outpw(port) - write single word to I/O port pair
;
;   For IBM C Set/2  Version 1.0
;
;  DISCLAIMER:
;  -------------------------
;  This code and the accompanying documentation is hereby placed in
;  the public domain.  It is not part of any standard product and
;  is provided solely as an example for your private and/or
;  commercial use.  You may freely use or distribute this code in
;  derived works as long as you do not attempt to prevent others
;  from doing likewise.  Neither the author, nor his employer,
;  shall be liable for any damages arising from your use of this
;  code; it is provided solely ASIS with no warranty whatsoever.
;
;  Author contact:   Michael Thompson
;                    tommy@msc.cornell.edu
; ******************************************************************
;
; Register use modified 7/16/93 by Mike Warot (ka9dgx@chinet.com)
;

P@IOCODE        segment 'CODE'
                assume  cs:P@IOCODE

;=============================================================================
; These routines must be declared as
;
;       unsigned short _Far16 _Fastcall inp(unsigned short port);
;       unsigned short _Far16 _Fastcall inpw(unsigned short port);
;       unsigned short _Far16 _Fastcall outp(unsigned short, unsigned short);
;       unsigned short _Far16 _Fastcall outpw(unsigned short, unsigned short);
;
; in the CSET/2 declarations.  The fastcall convention passes the values on
; the registers AX, DX as assumed below.  The short return allows use of AX
; only on exit.  This should be nearly at the limit of the 32->16 call 
; convention.
;
; Compiling and linkage requires these routines to be stored in a DLL so are
; 16 bit.  I could make them 32 bit IF I could get a true protected mode 32
; bit assembler.  Microsoft maybe there, but I refuse to buy their toys
; anymore.
;
; General make process:
;    masm /Mx portio;
;    link /map /noi /nod portio,portio.dll,,,portio.def
;    implib portio.lib portio.def
;
; portio.def must contain
;       LIBRARY PORTIO
;       DESCRIPTION 'Dynamically-linked Run-Time Library for Port Access'
;       PROTMODE
;       CODE PRELOAD EXECUTEONLY IOPL
;
;       EXPORTS
;       @inp
;       @outp
;       @inpw
;       @outpw
;
; The CODE IOPL is required - all CODE segments are give IOPL priveleges.
; For some reason, can't figure out how to override one MASM segment.
; @ indicates a fastcall routine apparently, /Mx preserves case.
;=============================================================================



;=============================================================================
; Subroutine to output byte to specified port
;
; Usage:  unsigned short = outp (unsigned short port, unsigned short byte)
;         unsigned short = outpw(unsigned short port, unsigned short word)
;
; Inputs: DX - port
;         AX - contains value to be sent (low byte only for outp)
;
; Output: AX - byte value sent
;=============================================================================
@outp           proc    far
                public  @outp
                assume  ds:nothing,es:nothing
;
                out     dx,al                           ; And send one byte
                xor     ah,ah                           ; Say didn't send hi
                ret
;
@outp           endp

@outpw          proc    far
                public  @outpw
                assume  ds:nothing,es:nothing
;
                out     dx,ax                           ; And send one byte
                ret
;
@outpw          endp


;=============================================================================
; Subroutine to read input from a specified port
;
; Usage:  unsigned short = inp (unsigned short port)
;         unsigned short = inpw(unsigned short port)
;
; Inputs: DX - port
;
; Output: AX - byte (word) value received
;=============================================================================
@inp            proc    far
                public  @inp
                assume  ds:nothing,es:nothing
;
                in      al,dx                           ; Read the byte
                xor     ah,ah                           ; Clear AH
                ret
;
@inp            endp

@inpw           proc    far
                public  @inpw
                assume  ds:nothing,es:nothing
;
                in      ax,dx                           ; Read the word
                ret
;
@inpw           endp

P@IOCODE                ends
;
                end

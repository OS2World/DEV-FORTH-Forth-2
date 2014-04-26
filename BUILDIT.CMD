REM Buildit.Cmd - procedure to re-build FORTH
\masm\ml /I. /Zm /c /Ta forth.asm
\masm\ml /I. /Zm /c /Ta portio.asm
link386 forth,forth,nul,\os2\doscalls portio,forth
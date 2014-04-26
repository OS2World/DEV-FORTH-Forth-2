\ Miscellaneous routines from the libarary of Mike Warot

: Sound ( duration_in_MSec Frequency -- ) sys$beep SysCall 3 drops ;

Variable  Octave

2 Octave !

: Half    Octave @ * 2 / 400 swap Sound ;

: Quarter Octave @ * 2 / 200 swap Sound ;

: Eighth  Octave @ * 2 / 100 swap Sound ;

: Rest   100 MS ;

262 Constant C3
277 Constant C3#
294 Constant D3
311 Constant D3#
330 Constant E3
349 Constant F3
370 Constant F3#
392 Constant G3
415 Constant G3#
440 Constant A4
466 Constant A4#
494 Constant B4
523 Constant C4

: Tocatta

  4 Octave !

           A4 Eighth   G3 Eighth  A4 Half  Rest Rest Rest Rest

           A4 Eighth   G3 Eighth  F3 Eighth   E3 Eighth

           C3# Half    D3 Half    Rest Rest Rest Rest

  2 Octave !

           A4 Eighth   G3 Eighth  A4 Half  Rest Rest Rest Rest

           E3 Half     F3 Half    C3# Half    D3 Half

           Rest Rest Rest Rest

  1 Octave !

           A4 Eighth   G3 Eighth  A4 Half  Rest Rest Rest Rest

           A4 Eighth   G3 Eighth   F3 Eighth   E3 Eighth

           C3# Half    D3 Half    Rest Rest Rest Rest
;


\ This is a post semicolon comment


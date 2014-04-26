\   This set of includes is here, in a separate file, becuase of the strange
\ way include" interacts with the forth.ini loading...
\

( include" struct.4th"   )
  include" threads.4th"
( include" locals.4th"   )
( include" startup.4th"  )
  include" mike.4th"
  include" help.4th"

greet

{ The palettes of the menus as strings of indexes (Borland TV names; the values are those of tv/). }
const
  CMenuView = #2#3#4#5#6#7;
  CStatusLine = #2#3#4#5#6#7;

var
  { DN: set while a menu is open (declared in DN's own menus.pas); read by the command line and DNUtil }
  MenuActive: Boolean = False;

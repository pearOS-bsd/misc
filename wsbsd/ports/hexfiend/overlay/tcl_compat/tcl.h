/* <tcl.h> in front of the system's: Hex Fiend carries its own copy of Tcl_ParseArgsObjv and Tcl_ArgvInfo (written for the Tcl 8.5 of macOS, which lacked them); Tcl 8.6.x
 * of FreeBSD declares them too. The system's declarations are renamed while its header is read, so the application's own do not clash. */
#define Tcl_ArgvInfo WsbsdSystem_Tcl_ArgvInfo
#define Tcl_ParseArgsObjv WsbsdSystem_Tcl_ParseArgsObjv
#include_next <tcl.h>
#undef Tcl_ArgvInfo
#undef Tcl_ParseArgsObjv

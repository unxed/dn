# drivers.pas: FPC wants @ for the value of a typed constant of a procedural type
s/^\(  SysErrorFunc: TSysErrorFunc = \)SystemError;/\1@SystemError;/

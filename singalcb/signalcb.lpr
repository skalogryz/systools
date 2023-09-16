program signalcb;

{$mode delphi}{$H+}

uses
  Windows,
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Classes, SysUtils
  { you can add units after this };

var
  pid : integer = 0;

procedure ParseCommandLine;
var
  i : integer;
  err : integer;
begin
  for i:=1 to ParamCount do begin
    Val(ParamStr(i),pid, err);
    if err<>0 then pid := 0;
  end;
end;

begin
  ParseCommandLine;
  if pid = 0 then begin
    writeln('please specify PID to send ctrl+break to');
    ExitCode := 1;
    Exit;
  end;
  writeln('pid: ', pid);
  if not FreeConsole then
    writeln('error freeing console: ', GetLastError);

  if not AttachConsole(pid) then begin
    ExitCode := 1;
    exit;
  end;

  if not GenerateConsoleCtrlEvent(CTRL_C_EVENT, 0) then
    ExitCode := 1;
end.



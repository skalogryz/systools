program signalcb;

{$mode delphi}{$H+}

uses
  Windows;

var
  pid : integer = 0;
  waitProc : boolean = false;
  waitTimeout : integer = -1;

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

procedure PrintHelp;
begin
end;

var
  h : Windows.THANDLE;
begin
  ParseCommandLine;
  if pid = 0 then begin
    writeln('please specify PID to send ctrl+c to');
    PrintHelp;
    ExitCode := 1;
    Exit;
  end;
  writeln('pid: ', pid);
  h := OpenProcess(SYNCHRONIZE, false, pid);
  if h = INVALID_HANDLE_VALUE then begin
    writeln('unable to open handle of the process. Process doesn''t exist?');
  end;

  if not FreeConsole then
    writeln('error freeing console: ', GetLastError);


  if not AttachConsole(pid) then begin
    ExitCode := 1;
    exit;
  end;

  if not GenerateConsoleCtrlEvent(CTRL_C_EVENT, 0) then
    ExitCode := 1;

  if h<>INVALID_HANDLE_VALUE then begin
    if (waitProc) then begin
      WaitForSingleObject(h, waitTimeout);
    end;
    CloseHandle(h);
  end;

end.


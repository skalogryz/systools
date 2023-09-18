program signalcb;

{$mode delphi}{$H+}

uses
  Windows, Classes, SysUtils;

var
  pid : integer = 0;
  verbose : boolean = false;
  verboseFile : string;
  verboseTxt : Text;
  verboseTxtInit: Boolean = false;
  waitProc : boolean = true;
  waitTimeout : integer = -1;

procedure ParseCommandLine;
var
  i : integer;
  err : integer;
  s   : string;
  ts  : string;
  tm  : integer;
begin
  i := 1;
  while i <= ParamCount do begin
    s := ParamStr(i);
    inc(i);
    if (s = '-v') then begin
      verbose := true;
    end else if (s = '-vf') then begin
      verbose := true;
      if i <= ParamCount then begin
        verboseFile := ParamStr(i);
        inc(i);
      end;
    end else if (s = '-w') then begin
      if i <= ParamCount then begin
        ts := ParamStr(i);
        inc(i);
        Val(ts, tm, err);
        if err<>0 then begin
          if tm = 0 then begin
            waitProc := false;
          end else begin
            if tm < 0 then waitTimeout := -1;
            waitTimeOut := tm;
            waitProc := true;
          end;
        end;
      end;
    end else begin
      Val(s,pid, err);
      if err<>0 then pid := 0;
    end;
  end;
end;

procedure PrintHelp;
begin
  writeln('signalcb [optiosn] %pid%');
  writeln;
  writeln('  -v       - verbose output');
  writeln('  -vf %fn% - verbose output to the file specified');
  writeln('  -w  %ms% - number of miliseconds to wait until the process terminates');
  writeln('             -1 - wait indefinetly (default)');
  writeln('              0 - don''t wait at all');
end;

procedure vrb(const s: string); overload;
begin
  if not verbose then Exit;
  if verboseFile = '' then begin
    writeln(s);
    exit;
  end;

  if not verboseTxtInit  then begin
    verboseTxtInit := true;
  end;
  AssignFile(verboseTxt, verboseFile);
  if not FileExists(verboseFile)
    then Rewrite(verboseTxt)
    else Append(verboseTxt);
  writeln(verboseTxt, s);
  CloseFile(verboseTxt);
end;

procedure vrb(const s: string; const data: array of const); overload;
begin
  vrb(format(s, data));
end;

var
  h : Windows.THANDLE;
begin
    try
      ParseCommandLine;
      if pid = 0 then begin
        writeln('please specify PID to send ctrl+c to');
        PrintHelp;
        ExitCode := 1;
        Exit;
      end;
      vrb('----- started -----');
      vrb('pid: %d', [pid]);
      vrb('verboseFile %s', [verboseFile]);
      writeln('pid: ', pid);
      h := OpenProcess(SYNCHRONIZE, false, pid);
      vrb('process handle = %d', [h]);
      if (h = 0) or (h = INVALID_HANDLE_VALUE) then begin
        writeln('unable to open handle of the process. Process doesn''t exist?');
        vrb('unable to open process: %d',[GetLasterror]);
      end;

      if not FreeConsole then begin
        writeln('error freeing console: ', GetLastError);
        vrb('unable to free console: %d',[GetLasterror]);
      end else
        vrb('console freed!');

      if not AttachConsole(pid) then begin
        vrb('unable to attach to console: %d. Exiting',[GetLasterror]);
        ExitCode := 1;
        exit;
      end;

      vrb('generating ctrl+c event');
      if not GenerateConsoleCtrlEvent(CTRL_C_EVENT, 0) then begin
        vrb('failed to generate the event. %d. Exiting',[GetLasterror]);
        ExitCode := 1;
      end;

      if h<>INVALID_HANDLE_VALUE then begin
        vrb('finishing');
        if (waitProc) then begin
          vrb('waiting for the process to finsih: %d', [waitTimeout]);
          WaitForSingleObject(h, waitTimeout);
        end;
        vrb('closing handle');
        CloseHandle(h);
      end;
      vrb('leaving the app');
    except
      on e: exception do
        vrb(e.Message);
    end;
end.


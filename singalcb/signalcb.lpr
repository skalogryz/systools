program signalcb;

{$mode delphi}{$H+}

uses
  Windows, WinAPIAdd, Classes, SysUtils;

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
var
  i: integer;
  fs: TFileStream;
  le : string;
begin
  if not verbose then Exit;
  if verboseFile = '' then begin
    writeln(s);
    exit;
  end;

  if not verboseTxtInit  then begin
    verboseTxtInit := true;
  end;
  for i:=0 to 4 do begin
    try

      AssignFile(verboseTxt, verboseFile);
      if not FileExists(verboseFile) then begin
        fs := TFileStream.Create(verboseFile, fmCreate);
        fs.Free;
      end;
      fs := TFileStream.Create(verboseFile, fmOpenReadWrite or fmShareDenyNone);
      fs.Position := fs.Size;
      if s<>'' then fs.Write(s[1], length(s));
      fs.WriteByte(13);
      fs.WriteByte(10);
      fs.Free;
      break;
    except
    end;
  end;
end;

procedure vrb(const s: string; const data: array of const); overload;
begin
  vrb(format(s, data));
end;

var
  inWaiting : Boolean = false;

function CtrlCHandler(dwCtrlType :DWORD):WINBOOL; stdcall;
begin
  // processed and we don't want to close THIS process
  //if (inWaiting) then vrb('signal is blocked. ignoring termination. It''s us!');
  Result := inWaiting;
end;


procedure SpawingSelf(currentToken: Windows.THANDLE; sessId: LongWord);
var
  newTkn : Windows.THAndle;
  res    : Boolean;
  tpk    : TTOKENPRIVILEGES;
  prc    : TPROCESSINFORMATION;
  s      : string;
  i      : integer;
  wd     : string;
  startup : TSTARTUPINFO;
begin
  vrb('attempt to spawn process');

  FillChar(tpk, sizeof(tpk), 0);
  tpk.PrivilegeCount := 1;

  vrb('looking up privilege name');
  res := LookupPrivilegeValue(nil, SE_TCB_NAME, tpk.Privileges[0].Luid);
  if res then vrb('success')
  else vrb('failure: %d', [GetLastError]);

  tpk.Privileges[0].Attributes := SE_PRIVILEGE_ENABLED;

  res := AdjustTokenPrivileges(currentToken, false, @tpk, 0, nil, nil);
  if not res then
    vrb('failed to adjust the new token: %d', [GetLastError])
  else
    vrb('adjusted token privilege!');

  CloseHandle(currentToken);
   (*
  res := SetTokenInformation(newTkn, TokenSessionId, @sessid, sizeof(sessid));
  if not res then begin
    // 1314 - ERROR_PRIVILEGE_NOT_HELD
    vrb('unable to change session id (%d) for the new token %d',[sessid, GetLastError]);
    Exit;
  end;
  *)
  res := WTSQueryUserToken(sessid, @newTkn);
  if not res then begin
    vrb('failed to get token of the session id: %d',[GetLastError]);
    exit;
  end else
    vrb('success, we have the user token');

  s := '';
  for i:=0 to ParamCount do begin
    if s <> '' then s := s +' ';
    s := s + '"'+ParamStr(i)+'"';
  end;
  wd := GetCurrentDir;

  FillChar(startup, sizeof(startup),0);
  startup.cb := sizeof(startup);
  FillChar(prc, sizeof(prc),0 );

  vrb('spwating self: %s', [s]);
  res := CreateProcessAsUser(
    newTkn,
    nil, // appliction name
    PAnsiChar(s), // command lne
    nil, // process security attributates
    nil, // thread security attributes
    false, // inherit handles
    NORMAL_PRIORITY_CLASS or CREATE_NEW_CONSOLE or CREATE_NEW_PROCESS_GROUP, // flags
    nil, // environment
    PAnsiChar(wd), // current directory
    @startup, // startup info
    @prc);
  if res then begin
    vrb('spawned! waiting to finish!');
    WaitForSingleObject(prc.hProcess, DWORD(-1));
    CloseHandle(prc.hThread);
    CloseHandle(prc.hProcess);
  end else
    vrb('spawing process failed with %d:',[GetLastError]);
end;

var
  h : Windows.THANDLE;
  res : boolean;
  ms : Int64;
  err : longword;
  sessid : longword;
  mysessid : longword;
  tkn : Windows.THANDLE;
  ph  : Windows.THANDLE;
  tpk : TTOKENPRIVILEGES;
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
      vrb('verboseFile: %s', [verboseFile]);

      writeln('pid: ', pid);
      h := OpenProcess(SYNCHRONIZE, false, pid);
      vrb('process handle = %d', [h]);
      if (h = 0) or (h = INVALID_HANDLE_VALUE) then begin
        writeln('unable to open handle of the process. Process doesn''t exist?');
        vrb('unable to open process: %d',[GetLasterror]);
      end;

      res := FreeConsole;
      if not res then begin
        err := GetLastError;
        writeln('error freeing console: ', err);
        vrb('unable to free console: %d',[err]);
      end else
        vrb('console freed!');

      res := ProcessIdToSessionId(pid, sessid);
      if not res then begin
        err := GetLastError;
        vrb('unable to get the session id of the process');
      end;
      vrb('session id %d for pid %d',[sessid, pid]);
      res := ProcessIdToSessionId(GetCurrentProcessId, mysessid);
      vrb('session id %d is current process',[mysessid]);

      if (mysessid <> sessid) then begin
        vrb('changing the session info');
        ph := GetCurrentProcess;

        // https://stackoverflow.com/questions/3128017/launching-a-process-in-user-s-session-from-a-service
        //
        // TOKEN_ADJUST_SESSIONID
        res := OpenProcessToken(ph, TOKEN_ADJUST_PRIVILEGES or TOKEN_QUERY, tkn);
        if not res then begin
          vrb('unable to open token for session id change: %d',[GetLastError]);
        end else begin
          // If TokenSessionId is set with SetTokenInformation, the application
          // must have the Act As Part Of the Operating System privilege,
          // and the application must be enabled to set the session ID in a token.
          SpawingSelf(tkn, sessId);
          CloseHandle(tkn);
        end;
      end;


      res := AttachConsole(pid);
      if not res then begin
        err := GetLastError;
        vrb('unable to attach to console: %d. Exiting',[GetLasterror]);
        ExitCode := 1;
        exit;
      end else
        vrb('attached to target pid console');

      if (waitProc) then begin
        res := SetConsoleCtrlHandler(@CtrlCHandler, true);
        //res := SetConsoleCtrlHandler(nil, false);
        if not res then
          vrb('installing ctrl handler failed')
        else
          vrb('installed ctrl handler to prevent termination');
      end;

      vrb('generating ctrl+c event');
      inWaiting := true;
      if not GenerateConsoleCtrlEvent(CTRL_C_EVENT, 0) then begin
        vrb('failed to generate the event. %d. Exiting',[GetLasterror]);
        ExitCode := 1;
      end else begin
        vrb('event passed through');
        if (waitProc) then begin
          vrb('freeing console...');
          res := FreeConsole;
          if not res then
            vrb('failed to release the console that was signaled for Ctrl+c. Need to release it to wait for the process')
          else
            vrb('console is freed. we can wait for the process now');
        end;
      end;

      if h<>INVALID_HANDLE_VALUE then begin
        vrb('finishing');
        if (waitProc) then begin
          vrb('waiting for the process to finish: %d', [waitTimeout]);
          inWaiting := false;
          ms := int64(GetTickCount64);
          WaitForSingleObject(h, waitTimeout);
          ms := int64(GetTickCount64) - ms;
          vrb('closed in %d miliseconds', [ms]);
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


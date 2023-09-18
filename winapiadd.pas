unit WinAPIAdd;

{$mode delphi}

interface

uses Windows;

const
  TOKEN_ADJUST_SESSIONID = $0100;

function ProcessIdToSessionId(dwProcessId:DWORD; out sessionId:DWORD):BOOL;stdcall;external 'kernel32' name 'ProcessIdToSessionId';

function DuplicateTokenEx(
   ExistingTokenHandle  : HANDLE;
   dwDesiredAccess      : DWORD;
   lpTokenAttributes    : LPSECURITY_ATTRIBUTES;
   ImpersonationLevel   : SECURITY_IMPERSONATION_LEVEL;
   TokenType            : TOKEN_TYPE;
   DuplicateTokenHandle : PHANDLE):WINBOOL; stdcall; external 'advapi32' name 'DuplicateTokenEx';

function WTSQueryUserToken(
  SessionID: Windows.ULONG;
  phToken : Windows.PHANDLE): WINBOOL; stdcall; external 'wtsapi32' name 'WTSQueryUserToken';

implementation

end.


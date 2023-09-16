# systools
just some system tools

## signalcb
For Windows.
the utility tries to attach to a process identified as by pid and send Ctrl+C signal.
Ctrl+C is a more graceful way to terminate a console process (as most of console apps handles Ctrl+C as a termination)
Killtask doesn't provide such option

Example:

    signalcb 12345


## POSIX pseudoterminal capture for live display lifecycle tests.

import std/[os, posix]

when defined(macosx):
  const ptyHeader = "<util.h>"
else:
  const ptyHeader = "<pty.h>"
  {.passL: "-lutil".}

proc openPty(master, slave: ptr cint; name, settings, size: pointer): cint {.
  importc: "openpty", header: ptyHeader.}

type TtyOutput* = object
  output*: File
  master: cint

proc close*(tty: var TtyOutput) =
  if tty.output != nil:
    tty.output.close()
    tty.output = nil
  if tty.master >= 0:
    discard posix.close(tty.master)
    tty.master = -1

proc initTtyOutput*(): TtyOutput =
  var slave: cint
  result.master = -1
  if openPty(addr result.master, addr slave, nil, nil, nil) != 0:
    raiseOSError(osLastError())
  if not open(result.output, FileHandle(slave), fmWrite):
    discard posix.close(slave)
    result.close()
    raise newException(IOError, "cannot open test pseudoterminal")

proc capture*(tty: var TtyOutput): string =
  ## Closes the writer and drains the terminal's output, including VT controls.
  tty.output.close()
  tty.output = nil
  var buffer: array[4096, char]
  while true:
    let count = posix.read(tty.master, addr buffer[0], buffer.len)
    if count > 0:
      for index in 0 ..< count:
        result.add buffer[index]
    elif count == 0 or osLastError() == OSErrorCode(EIO):
      break
    elif osLastError() != OSErrorCode(EINTR):
      raiseOSError(osLastError())

import lldb, re
def resolve(debugger, command, result, internal_dict):
    inp, out = command.split()
    target = debugger.GetSelectedTarget(); proc = target.GetProcess(); err = lldb.SBError()
    lines = []
    for line in open(inp):
        a = int(line.strip(), 16)
        insts = target.ReadInstructions(lldb.SBAddress(a, target), 3)
        o0 = insts.GetInstructionAtIndex(0).GetOperands(target); o1 = insts.GetInstructionAtIndex(1).GetOperands(target)
        m0 = insts.GetInstructionAtIndex(0).GetMnemonic(target)
        name = '?'
        if m0 == 'adrp':
            m = re.match(r'x\d+, (-?\d+)', o0); n = re.match(r'x\d+, x\d+, #(0x[0-9a-f]+|\d+)', o1)
            if m and n:
                addr = (a & ~0xfff) + int(m.group(1)) * 0x1000 + int(n.group(1), 0)
                buf = proc.ReadMemory(addr, 96, err)
                name = buf.split(b'\0')[0].decode('latin1') if err.Success() and buf else '?'
        lines.append('%x %s' % (a, name))
    open(out, 'w').write('\n'.join(lines) + '\n')
def __lldb_init_module(debugger, d):
    debugger.HandleCommand('command script add -f resolve.resolve resolve')

// headless: decompile the functions listed in a file (one per line: "0xADDRESS name"); address = the static address from symtab (0x18....)
import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.*;
import ghidra.program.model.address.*;
import ghidra.program.model.listing.*;
import ghidra.app.cmd.disassemble.DisassembleCommand;
import ghidra.app.cmd.function.CreateFunctionCmd;
import java.io.*;
import java.util.*;

public class Dec extends GhidraScript {
	public void run() throws Exception {
		String[] args = getScriptArgs();
		List<String> lines = java.nio.file.Files.readAllLines(new File(args[0]).toPath());
		PrintWriter out = new PrintWriter(new FileWriter(args[1]));
		DecompInterface di = new DecompInterface(); di.openProgram(currentProgram);
		for (String l : lines) {
			l = l.trim(); if (l.isEmpty()) continue;
			String[] p = l.split("\\s+", 2);
			Address a = currentProgram.getAddressFactory().getDefaultAddressSpace().getAddress(Long.parseUnsignedLong(p[0].substring(2), 16));
			Function f = getFunctionAt(a);
			if (f == null) {
				new DisassembleCommand(a, null, true).applyTo(currentProgram, monitor);
				new CreateFunctionCmd(a).applyTo(currentProgram, monitor);
				f = getFunctionAt(a);
			}
			out.println("//// " + l);
			if (f == null) { out.println("// no function"); continue; }
			DecompileResults r = di.decompileFunction(f, 120, monitor);
			if (r.decompileCompleted()) out.println(r.getDecompiledFunction().getC()); else out.println("// failed: " + r.getErrorMessage());
			out.flush();
		}
		out.close();
	}
}

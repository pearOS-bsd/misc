#!/bin/sh
# Guest tools for the hypervisors the image is tried in: open-vm-tools (VMware) and the VirtualBox guest additions, with their dependencies, copied from the build machine's packages
# into the image root (the program and its kernel modules; the libraries come from the library scan of build.sh).  sh guesttools.sh ROOT
# Not every package exists for every architecture (the VirtualBox additions are amd64 / i386 only): a missing one is reported, not an error. The rc script of the image starts them only
# when the machine says it is that hypervisor (kenv smbios.system.product).
ROOT="${1:?image root}"
for top in open-vm-tools-nox11 virtualbox-ose-additions-nox11; do
	pkg info -e "$top" 2>/dev/null || pkg install -y "$top" >/dev/null 2>&1 || true
	pkg info -e "$top" 2>/dev/null || { echo "NOTE: $top is not available for $(uname -p), skipped"; continue; }
	all="$top $(pkg query '%dn' "$top" 2>/dev/null | grep -E 'kmod')"					# the program and its kernel modules; the shared libraries it needs are found by the library scan of build.sh (glib's own dependencies, python among them, stay out)
	for p in $all; do
		pkg info -l "$p" 2>/dev/null | sed -n 's/^[[:space:]]*\(\/.*\)$/\1/p' | grep -vE '^/usr/local/(share/(doc|man|info|examples|gtk-doc|locale|bash-completion)|include|man|info|lib/pkgconfig|libdata)/' | cut -c2- | tar -C / -cf - -T - 2>/dev/null | tar -C "$ROOT" -xpf - 2>/dev/null
	done
	echo "guest tools: $top and $(echo $all | wc -w) packages in all"
done

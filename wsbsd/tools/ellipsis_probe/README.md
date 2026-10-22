Mac as oracle for the middle ellipsis of names (Finder icon view, list, columns).
`clang -fobjc-arc -framework Foundation -framework CoreText probe.m -o probe && ./probe > data.txt && python3 check.py`
Result on macOS 27: head and tail share the room left by the ellipsis in two equal halves (head: most characters whose width is within half, tail likewise), a space at a cut is dropped -> 523 of 529 cases identical.
Line wrapping of icon labels: break after a space, after a hyphen that is not before a digit, after a slash; a longer word breaks where it fills the line; the label is about 105 pt wide.

# CoreUI: the asset catalogue reader (car.c) with the LZFSE decoder it needs; `make -C coreui check` runs from the repository's top directory
SRC = car.c bvg.c lzfse/lzfse_decode.c lzfse/lzfse_decode_base.c lzfse/lzfse_fse.c lzfse/lzvn_decode_base.c
CFLAGS ?= -O2 -g -std=c99 -D_DEFAULT_SOURCE -Wall

libcoreui.a: $(SRC)
	for f in $(SRC); do $(CC) $(CFLAGS) -I. -Ilzfse -c $$f -o $$(basename $$f .c).o || exit 1; done; rm -f $@; ar rcs $@ $(notdir $(SRC:.c=.o))
cardump: tools_cardump.c libcoreui.a
	$(CC) $(CFLAGS) -I. -o $@ tools_cardump.c libcoreui.a -lm
test_car: test_car.c libcoreui.a
	$(CC) $(CFLAGS) -I. -o $@ test_car.c libcoreui.a -lm
check: test_car
	cd .. && ./coreui/test_car
clean:
	rm -f *.o libcoreui.a cardump test_car

PRGNAME=imgrd

all:    sanity $(PRGNAME) d64

sanity:
	printf "Checking requirements... "
	# Check all requiremens before doing anything
	rm -f error.log
#	if ! command -v petcat >/dev/null ; then \
#		printf "\\npetcat (part of VICE emulator) not found." \
#		| tee -a error.log; \
#	fi ;
	if ! command -v c1541 >/dev/null ; then \
		printf "\\nc1541 (part of VICE emulator) not found." \
		| tee -a error.log; \
	fi ;
	if ! command -v ca65 >/dev/null ; then \
		printf "\\nca65 (part of cc65) not found." \
		| tee -a error.log; \
	fi ;
	if ! command -v cl65 >/dev/null ; then \
		printf "\\ncl65 (part of cc65) not found." \
		| tee -a error.log; \
	fi ;
	if ! command -v zip >/dev/null ; then \
		printf "\\nzip not found." \
		| tee -a error.log; \
	fi ;
	if [ -f error.log ] ; then \
		printf "\\nSome requirements were not met, aborting.\\n" ; \
		exit 1 ; \
	else \
		printf "OK\\n" ; \
	fi

.SILENT:	sanity x

SRC:=$(wildcard *.asm)
OBJ:=$(SRC:.asm=.o)
LST:=$(SRC:.asm=.lst)
INC:=$(wildcard *.inc)

debug: AFLAGS+=-DDEBUG
debug: $(PRGNAME)

%.o: %.asm
	ca65 -g $(AFLAGS) $< -l $(subst .asm,.lst,$<) -o $@

$(PRGNAME): $(OBJ)
	ld65 -Ln $@.lbl -m $@.map -o $@ -C cbmpet_imgrd.cfg $(OBJ)
	cp $@ i # shortcut

d64:	$(PRGNAME)
	# Create empty disk image
	c1541 -format "$(PRGNAME),ne" d64 $(PRGNAME).d64 8 
	# Copy prg to disk image
	c1541 -attach $(PRGNAME).d64 -write $(PRGNAME)

zip:	$(PRGNAME) d64
	zip $(PRGNAME).zip Makefile $(PRGNAME) *.d64 *.inc *.asm

clean:
	rm -f $(OBJ) $(LST) $(PRGNAME).map $(PRGNAME).lbl

veryclean:	clean
	rm -f $(PRGNAME) i $(PRGNAME).zip $(PRGNAME).d64 $(PRGNAME).lbl $(PRGNAME).map

.PHONY:	sanity clean veryclean $(PRGNAME)

x:
	printf SRC: $(SRC)
	printf OBJ: $(OBJ)
   

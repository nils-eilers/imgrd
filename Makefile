PRGNAME:=imgrd
IMGTYPE?=d64

INCDIR=inc/
OBJDIR=obj/
BINDIR:=bin/

SRC:=$(wildcard *.asm)
OBJ:=$(addprefix $(OBJDIR),$(SRC:.asm=.o))
LST:=$(addprefix $(OBJDIR),$(SRC:.asm=.lst))
INC:=$(wildcard $(INCDIR)*.inc)

all:    sanity $(BINDIR)$(PRGNAME) $(BINDIR)$(PRGNAME).$(IMGTYPE)

debug: AFLAGS+=-DDEBUG
debug: $(PRGNAME)

$(OBJDIR)%.o: %.asm $(INC)
	ca65 -g $(AFLAGS) $< -I $(INCDIR) -l $(addprefix $(OBJDIR),$(subst .asm,.lst,$<)) -o $@

$(BINDIR)$(PRGNAME): $(OBJ)
	ld65 -Ln $(OBJDIR)$(PRGNAME).lbl -m $(OBJDIR)$(PRGNAME).map -o $@ -C cbmpet_imgrd.cfg $(OBJ)
	cp $@ i # shortcut

$(BINDIR)$(PRGNAME).$(IMGTYPE): $(BINDIR)$(PRGNAME)
	# Create empty disk image
	c1541 -format "$(PRGNAME),ne" $(IMGTYPE) $@ 8 
	# Copy prg to disk image
	c1541 -attach $@ -write $<

zip:	$(BINDIR)$(PRGNAME).$(IMGTYPE)
	zip $(PRGNAME).zip Makefile cbmpet_imgrd.cfg $(BINDIR)$(PRGNAME) $(BINDIR)$(PRGNAME).$(IMGTYPE) $(SRC) $(INC)

clean:
	rm -f $(OBJ) $(LST) $(OBJDIR)$(PRGNAME).map $(OBJDIR)$(PRGNAME).lbl

veryclean:	clean
	rm -f $(BINDIR)$(PRGNAME) i $(PRGNAME).zip
	rm -f $(BINDIR)$(PRGNAME).d64 $(BINDIR)$(PRGNAME).d80 $(BINDIR)$(PRGNAME).d82

sanity:
	mkdir -p $(OBJDIR)
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


.PHONY: sanity clean veryclean $(PRGNAME)
.SILENT: sanity

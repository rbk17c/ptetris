PI=pi64
DEVICE=PIC18f2320
GPASM=gpasm
ASFLAGS=--include inc
SUFFIXES := $(SUFFIXES) .asm
%.asm:
%.hex: %.asm
	$(GPASM) $(ASFLAGS) $< -o $@
PROJ=ts
SRC=$(PROJ).asm Hardware.inc Appl.inc asmdef18.inc Monitor_18f2320.asm Serial.asm i2c_slave.asm abc.asm

all: tags $(PROJ).hex

Appl.inc: Appl.hdl hdl.pl
	@if [ -e $@ ] ; then chmod -f +w $@ ; fi
	perl hdl.pl $< > $@
	@chmod -w $@

$(PROJ).hex: $(PROJ).asm $(SRC) Makefile
	$(GPASM) $(ASFLAGS) $< -o $@

tags: $(PROJ).asm $(SRC) /usr/local/share/gputils/header/p18f2320.inc
	@ctags --language-force=asm $^

clean:
	rm -f *.hex *.cod *.lst ctags tags Appl.inc


piwrite: $(PROJ).hex
	scp $< Makefile ${PI}:work
	@ssh ${PI} "cd work; make write"
	@#picwrite --type=x --file=$<


erase:
	piprg --type=${DEVICE} --erase

write:  $(PROJ).hex
	-pkill pirun
	piprg --type=${DEVICE} --Erase  --write=$<

vrf:
	piprg --type=${DEVICE} --verify=$(PROJ).hex

read:
	ssh ${PI} "cd work; piprg --type=${DEVICE} --read=-"


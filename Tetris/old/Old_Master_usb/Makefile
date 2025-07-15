GPASM=gpasm
ASFLAGS=--include inc
SUFFIXES := $(SUFFIXES) .asm
%.asm:
%.hex: %.asm
	$(GPASM) $(ASFLAGS) $< -o $@
PROJ=ts
SRC=$(PROJ).asm boot_gps.hw asmdef18.inc abc.asm

all: tags $(PROJ).hex

tags: $(PROJ).asm $(SRC) boot_gps.hw /usr/local/share/gputils/header/p18f45k50.inc
	ctags --language-force=asm $^

$(PROJ).hex: $(PROJ).asm $(SRC) Makefile
	$(GPASM) $(ASFLAGS) $< -o $@

clean:
	rm -f *.hex *.cod *.lst ctags tags

write:	$(PROJ).hex
	picwrite --type=x --file=$<

writepi: $(PROJ).hex
	ssh rpi2 "cd $$PWD; make write"
	@#picwrite --type=x --file=$<

read:
	@echo no reading in class

update:
	mkdir -p old
	-mv -b boot_gps.kinc boot_gps.hw old
	cp -a ../usb_boot/boot_gps.kinc boot_gps.kinc	
	cp -a ../usb_boot/boot_gps.hw boot_gps.hw



#ssh rpi2 "cd /home/hmx/link/elek/src/gps_clock; make write"

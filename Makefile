all: build

build:
	ca65 -g --target nes main.s
	ld65 --dbgfile main.dbg --target nes -o main.nes main.o

clean:
	rm -f *.nes *.dep *.o *.dbg
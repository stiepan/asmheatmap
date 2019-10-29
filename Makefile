all: sim

sim: simsse.o
	gcc -o sim sim.c simsse.o -std=c99 -Wall -Wextra -Wpedantic

simsse.o:
	nasm -f elf64 simsse.asm

clean:
	rm -f *.o
	rm -f sim



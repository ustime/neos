AS=$(TARGET)-as
CC=$(TARGET)-gcc
CFLAGS=-std=gnu99 -ffreestanding -O2 -Wall -Wextra

all: yos.bin

yos.bin: boot.o kernel.o
	$(CC) -T linker.ld -o $@ -ffreestanding -z max-page-size=0x1000 -O2 -nostdlib $^ -lgcc

clean:
	rm -f *.o yos.bin


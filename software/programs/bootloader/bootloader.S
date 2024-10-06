#define SPI_BASE 0xD000
#define SPI_REG_STATUS 0
#define SPI_REG_CONTROL 4
#define SPI_REG_DATA 8
#define SPI_REG_DATA_OUT 8
#define SPI_REG_DATA_IN 9

#define FLASH_WREN 0x06
#define FLASH_WRDI 0x04
#define FLASH_RDSR 0x05
#define FLASH_RDSR2 0x35
#define FLASH_RDSR3 0x15
#define FLASH_WRSR 0x01
#define FLASH_WRSR2 0x31
#define FLASH_WRSR3 0x11
#define FLASH_READ 0x03
#define FLASH_WRITE 0x02
#define FLASH_SECTOR_ERASE 0x20
#define FLASH_CHIP_ERASE 0xC7
#define FLASH_JEDECIDR 0x9F

#define MEMORY_BASE_ADDRESS 0xf0000000
#define CS_GPIO 0
#define SECTOR_SIZE 256

#define STACK_START 2048
#define PUSH(reg) sw reg, 0(sp); addi sp,sp, -4;
#define POP(reg) addi sp,sp, 4; lw reg, 0(sp);
	//       Use hardware CS built into SPI peripheral
#define SET_CS li t1, SPI_BASE; lw t0, SPI_REG_CONTROL(t1); ori t0, t0, 2; sw t0, SPI_REG_CONTROL(t1);
#define UNSET_CS li t1, SPI_BASE; lw t0, SPI_REG_CONTROL(t1); andi t0, t0, -2; sw t0, SPI_REG_CONTROL(t1);

	.section .text.start;
	.global  _start;
_start:
	//       Load SPI base addr
	li       sp, STACK_START

	UNSET_CS

	//       Read metadata (amount of sectors) from the first sector of the SPI flash
	SET_CS
	call     start_sector_read

	//       First word - number of sectors -> s0
	call     spi_transact
	slli     a0, a0, 24
	mv       s0, a0
	call     spi_transact
	slli     a0, a0, 16
	or       s0, s0, a0
	call     spi_transact
	slli     a0, a0, 8
	or       s0, s0, a0
	call     spi_transact
	or       s0, s0, a0
	//       Second word - number of bytes -> s1
	call     spi_transact
	slli     a0, a0, 24
	mv       s1, a0
	call     spi_transact
	slli     a0, a0, 16
	or       s1, s1, a0
	call     spi_transact
	slli     a0, a0, 8
	or       s1, s1, a0
	call     spi_transact
	or       s1, s1, a0

	li       s2, (SECTOR_SIZE-8)
metadata_busyread:
	call     spi_transact
	addi     s2, s2, -1
	bgtz     s2, metadata_busyread

	UNSET_CS


	//       TODO - Keep reading sectors until the sector counter is exhausted
	//       Write bytes until the byte write counter is exhausted

	li       s2, 1 // Current sector
	li       s3, MEMORY_BASE_ADDRESS // Current writing addr

	ebreak

sector_read:
	mv       a0, s2
	SET_CS
	call     start_sector_read

	li       s4, SECTOR_SIZE
byte_read:
	call     spi_transact

	//       Skip writing if out of bytes yesh
	blez     s1, skip_write
	addi     s1, s1, -1

	sb       a0, 0(s3)
	addi     s3, s3, 1
skip_write:

	addi     s4, s4, -1
	bgtz     s4, byte_read

	UNSET_CS
	//       Give a little leeeeway
	nop
	nop
	nop

	//       Next sector
	addi     s2, s2, 1
	blt      s2, s0, sector_read

	//       DONE!!!!
	ebreak

	//       Reset all GPIO
	UNSET_CS
	mv       t0, zero
	li       a0, MEMORY_BASE_ADDRESS
	jr       a0 // Jump to the freshly loaded coded!!!

	//       Takes sector address as a0
start_sector_read:
	PUSH(ra)
	mv       a1, a0

	li       a0, FLASH_READ
	call     spi_transact // Command
	srli     a0, a1, 8
	andi     a0, a0, 0xFF
	call     spi_transact // Addr MSB
	andi     a0, a1, 0xFF
	call     spi_transact // Addr LSB
	mv       a0, x0
	call     spi_transact

	POP(ra)
	ret

	//       Takes data as a0, outputs received on a0
spi_transact:
	la       t0, SPI_BASE

	sb       a0, SPI_REG_DATA_OUT(t0)

	lw       a1, SPI_REG_CONTROL(t0) // a1 = control_base
	ori      a2, a1, 1 // Set send flag
	sw       a2, SPI_REG_CONTROL(t0)

spi_txrx_wait:
	lw       a2, SPI_REG_STATUS(t0) // a1 = control_base
	andi     s2, a2, 1
	bnez     a2, spi_txrx_wait

	//       Unset send flag
	sw       a1, SPI_REG_CONTROL(t0)

	lbu      a0, SPI_REG_DATA_IN(t0)

	ret

/////////////////////////////////////////////////////////////////////////////////////
//
//       "STABLE RASTER"
//	   REALIZZATA PER RETROMAGAZINE, SETTEMBRE 2019 	
//
//       VERSIONE PER C64 PAL, SINTASSI KICKASSEMBLER
//
//       RIFERIMENTI: 
//		https://stackoverflow.com/questions/24375150/stable-raster-on-c64
//		https://codebase64.org/doku.php?id=base:stable_raster_routine 
//
/////////////////////////////////////////////////////////////////////////////////////

/*
    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/


.pc = $0801 "Basic upstart"
:BasicUpstart(main)
	
	//
	// .byte $0b,$08,$0a,$00,$9e,$34,$30,$39,$36,$00
	//
	// Codice corrispondente alla linea BASIC: 10 SYS4096 
	// per i compilatori che non creano automaticamente la linea per il lancio
	// del programma da BASIC.
	//

.const nr_col=143

.pc=$1000 "main"

main:
{
  jsr $ff81		// SCINIT standard KERNAL function
  			// Initialize VIC; restore default input/output to keyboard/screen; clear screen; set PAL/NTSC switch and interrupt timer.
  
  sei			// disabilita le interruzioni			

  lda #$00        // inizializzazione routine suono
  tax             // 
  tay             //       
  jsr $4000       // address of inizialization subroutine

  lda #$35		// disabilita interprete BASIC e KERNAL
  sta $01		// 
  
  lda #<int1	// prima interruzione, che farà eseguire
  ldy #>int1	// la routine int1
  sta $fffe		//
  sty $ffff		//
 
  lda #%0111111   // 
  sta $dc0d       // Interrupt control and status register
                  // Bit #0: 1 = Enable interrupts generated by timer A underflow.
                  // Bit #1: 1 = Enable interrupts generated by timer B underflow.
                  // Bit #2: 1 = Enable TOD alarm interrupt.
                  // Bit #3: 1 = Enable interrupts generated by a byte having been received/sent via serial shift register.
                  // Bit #4: 1 = Enable interrupts generated by positive edge on FLAG pin.

  sta $dd0d       // Interrupt control and status register
                  // Bit #0: 1 = Enable non-maskable interrupts generated by timer A underflow.
                  // Bit #1: 1 = Enable non-maskable interrupts generated by timer B underflow.
                  // Bit #2: 1 = Enable TOD alarm non-maskable interrupt.
                  // Bit #3: 1 = Enable non-maskable interrupts generated by a byte having been received/sent via serial shift register.
                  // Bit #4: 1 = Enable non-maskable interrupts generated by positive edge on FLAG pin.

  lda #$01        //
  sta $d01a       // Interrupt control register
                  // Bit #0: 1 = Raster interrupt enabled.

  lda $dc0d       // reset per eventuali interrupts rilevati
  lda $dd0d       // reset per eventuali interrupts rilevati

  lda #$1b		// bit più significativo (#8) per la linea raster 
  sta $d011		// dove generare l'interruzione azzerato
  
  lda #$01		//
  sta $d019		// ACK RASTER INTERRUPT

  lda start		// imposto la riga raster iniziale
  sta $d012		// per visualizzare le rasterbars (bits #0-#7)

  cli			// riabilita le interruzioni

  jmp *
}

.pc=$1100 "routine_stabilize"

int1:
{
  pha 
  txa 
  pha 
  tya 
  pha

  :STABILIZE()

	ldx #nr_col
	
	// a delay to get to some cycle at the end of the raster-line, so we have time to execute both inc's on 
	// each successive raster-line - in particular on the badlines before the VIC takes over the bus.
	.for (var i=0; i<28-2; i++) nop
	
	// just for illustrative purposes - not cool code :)
	.for (var i=0; i<nr_col; i++) 
        {

	  //inc $d020   // 6 cycles
	  //inc $d021   // 6 cycles

	  lda colors,x	// 4 cicli
	  sta $d020   	// 4 cicli
	  sta $d021   	// 4 cicli
	
        dex 		// 2 (tolto 1 nop sia da // badline che in // non-badline) 
          
	  .if ([i & %111] == 0) 
	  {
	      // badline
	     
	      //nop 
	      nop 
	      nop 
	      nop // 4*2=8 cycles

	  } 
		else 
	  {
	      // non-badline

	      //nop 
	      nop 
	      nop 
	      nop 
	      nop 
	      nop 
	      nop 
	      nop 
	      nop 
	      nop 
	      nop 
	      nop 
	      nop 
	      nop 
	      nop 
	      nop
	      nop
	      nop
	      nop
	      nop
	      nop
	      nop
	      nop
	      nop // 24*2=48 cycles
	     
	      bit $ea     // 3 cycles
		          // = 63 cycles
	  }
	}

  lda #$00
  sta $d020
  sta $d021

  lda #$f0		// riga raster per
  sta $d012		// la riproduzione del brano, verifica tasto spazio premuto etc.
  
  lda #<play 	// la prossima interruzione manderà
  ldy #>play 	// in esecuzione la routine
  sta $fffe		// play.
  sty $ffff		//

  lda #$01		//
  sta $d019		// ACK RASTER INTERRUPT

  jsr colora_barre
 
  pla 
  tay 
  pla 
  tax 
  pla

  rti
}

.pc=$2400 "macro STABILIZE"

.macro STABILIZE() {

  lda #<nextRasterLineIRQ
  sta $fffe
  lda #>nextRasterLineIRQ
  sta $ffff   

  inc $d012

  lda #$01
  sta $d019

  tsx

  cli

  nop 
  nop 
  nop 
  nop 
  nop 
  nop 
  nop 
  nop

nextRasterLineIRQ:
  txs

  ldx #$08
  dex
  bne *-1
  bit $00

  lda $d012
  cmp $d012

  beq *+2      
}

.pc=$2500 "routine_colora_barre"
colora_barre:
{
	lda colors+nr_col		// memorizza colore più in alto del
	pha				// vettore -colors- nello stack

	ldx #nr_col			// copia i colori all'interno del
loop:					// vettore -colors- spostandoli via 	
	lda colors,x		// via di 1 verso l'alto del 
	sta colors+1,x		// vettore
	dex				//
	cpx #$ff			//
	bne loop			//
	
	pla				// riprende il colore memorizzato nello
	sta colors			// stack e lo copia nell'elemento più
					// in basso del vettore -colors-
	rts
}


.pc=$2600 "routine play"
play:
{
  pha 
  txa 
  pha 
  tya 
  pha

  jsr $4003       // address of play-sound subroutine

  lda $DC01		// verifica se viene premuto
  cmp #$ff	      // il tasto SPAZIO.
  beq no_spazio	//

  lda #55		// ripristina BASIC ROM, KERNAL ROM
  sta $01		// ed I/O area 
  
  jmp $FCE2		// warm reset 

no_spazio: 

  lda start		// imposto la riga raster iniziale
  sta $d012		// per visualizzare le rasterbars (bits #0-#7)

  lda #<int1	// prossima interruzione
  ldy #>int1	// eseguirà nuovamente la routine
  sta $fffe		// int1
  sty $ffff

  lda #$01		//
  sta $d019		// ACK RASTER INTERRUPT

  pla 
  tay 
  pla 
  tax 
  pla

  rti
}

.pc=$2800 "bars"
colors:
.byte $00,$09,$09,$08,$0a,$0a,$07,$0d,$0d,$07,$0a,$0a,$08,$09,$09,$00
.byte $00,$09,$09,$08,$0a,$0a,$07,$0d,$0d,$07,$0a,$0a,$08,$09,$09,$00
.byte $00,$09,$09,$08,$0a,$0a,$07,$0d,$0d,$07,$0a,$0a,$08,$09,$09,$00
.byte $00,$09,$09,$08,$0a,$0a,$07,$0d,$0d,$07,$0a,$0a,$08,$09,$09,$00
.byte $00,$09,$09,$08,$0a,$0a,$07,$0d,$0d,$07,$0a,$0a,$08,$09,$09,$00
.byte $00,$09,$09,$08,$0a,$0a,$07,$0d,$0d,$07,$0a,$0a,$08,$09,$09,$00
.byte $00,$09,$09,$08,$0a,$0a,$07,$0d,$0d,$07,$0a,$0a,$08,$09,$09,$00
.byte $00,$09,$09,$08,$0a,$0a,$07,$0d,$0d,$07,$0a,$0a,$08,$09,$09,$00
.byte $00,$09,$09,$08,$0a,$0a,$07,$0d,$0d,$07,$0a,$0a,$08,$09,$09,$00
.byte $00,$09,$09,$08,$0a,$0a,$07,$0d,$0d,$07,$0a,$0a,$08,$09,$09,$00
.byte $00,$09,$09,$08,$0a,$0a,$07,$0d,$0d,$07,$0a,$0a,$08,$09,$09,$00
.byte $00,$09,$09,$08,$0a,$0a,$07,$0d,$0d,$07,$0a,$0a,$08,$09,$09,$00
.byte $00,$09,$09,$08,$0a,$0a,$07,$0d,$0d,$07,$0a,$0a,$08,$09,$09,$00

start:
  .byte 80

*=$4000 "music"
.import binary "retromagfin.sid",126  //// rimuove headers non necessari

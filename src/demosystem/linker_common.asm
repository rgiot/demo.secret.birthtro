;;;
;;; Krusty/Benediction
;;;
;;; August 2025 - initial version
;;; December 2025 - added ZX0 backward support (of course latest basm is required)
;;; August 2026 - allow to use several cruncher as soon as SELECTEd_CRUNCHER is modified before each macro call
;;;
;;; Provide some utility macros that help to link demos when using a single cruncher. These marcos setup properly the arguments of the uncruncher
;;; and when possible write the appropriate safety checks to avoid overlapping crunched and uncrunched data by using assertions.
;;; Should be reusable in other projects as soon as they are simple enough to use a single cruncher to avoid name clashes.
;;;
;;; This has been written for `basm` but should be easily portable to other assemblers with minor modifications (at least it is almost transparetn for `rasm`, I think only the `next` directive is missing).
;;;
;;; by using this system it is almost free to change the cruncher used for the entire demo. Just modify SELECTED_CRUNCHER variable after including this file.
;;;
;;; USAGE:
;;; ```z80
;;;    org 0x800
;;;    include "linker_common.asm"
;;;    SELECTED_CRUNCHER = CRUNCHER_ZX0_BACKWARD
;;;
;;;    run $
;;;     di : ld hl, 0xc9fb : ld (0x38), hl : ld sp, $ : ei
;;;
;;;    ; Generate the uncrunching calling code with proper memory checks
;;;    UNCRUNCH(C0_1000, 1000);
;;;    ld bc, 0x7fc4 : out (c), c
;;;    UNCRUNCH(C4_4000, 0x4000);
;;;    ld bc, 0x7fc0 : out (c), c
;;;
;;;    jp 0x1000
;;;
;;;    ; Inject the uncrunch code
;;;    INSTALL_UNCRUNCHER()
;;;    assert $ < 0x1000, "the cruncher overlaps with the code to run"
;;;
;;;    ; Crunch the various files and create the appropriate labels/sublabels
;;;    LOAD_N_CRUNCH(C0_1000, "path/to/uncrunched_data.bin")
;;;    LOAD_N_CRUNCH(C4_4000, "path/to/other_uncrunched_data.bin") 
;;;```
;;; It is possible to use several crunchers by repeting the process with several values of SELECTED_CRUNCHER. Just define properly when using macros

;;; TODO: 
;;;
;;;  - allow the user to specify the buffer addresses to still earn some bytes
;;;       current version CANNOT fit a 4k production because of this aspect
;;;  - some uncruncher are able to handle some parameters. Handle that cleanly
;;; - Allow the user to decide of the name of the uncrunch routine
;;; - improve assertion test (there are false positive for non backwards assertions)

;;; - Add breakpoint to check at execution things that cannot be checked at assembly time

	ifdef SELECTED_CRUNCHER
		fail "You need to specify SELECTED_CRUNCHER after including this file as it provides the cruncher names."
	endif

	enum CRUNCHER

;; APLIB cruncher
APLIB
;; EXOMIZER cruncher. Performant but quite slow to uncrunch
EXOMIZER
;; LZ4 cruncher
LZ4
;; LZ48 cruncher
LZ48
;; LZ49 cruncher
LZ49
;; LZSA1 cruncher
LZSA1
;; LZSA2 cruncher
LZSA2
;; SHRINKLER cruncher
SHRINKLER
;; CRUNCHER_UPKR cruncher. The best for a 4k demo
UPKR
;; ZX0 cruncher. The best for a standard dem
ZX0
;; ZX0 backward cruncher. Able to uncrunch from the end to the beginning of the data
ZX0_BACKWARD
;; ZX7 cruncher
ZX7
	endenum


	;; Sometimes there are conflicts between the crunched data areas and the uncrunched data areas. Mainly because of banks overlap or lack of free memory.
	;; To avoid this, we first move the crunched data to a safe area, then uncrunch from there.
	macro MOVE_CRUNCHED_DATA from, to
		ld hl, {from}.start
		ld de, {to}
		ld bc, {from}.length
		ldir
	endm

	;; Check if {cruncher} is backward capable.
	;; In this case it needs to be uncrunched from the end of the file up to the beginning. This allows to overlap crunched and uncrunched code
	function CRUNCHER_IS_BACKWARD cruncher
		switch {cruncher}
			case CRUNCHER_ZX0_BACKWARD:
				return true
			default
				return false
		endswitch
	endfunction
	
	;; Load {fname} and crunch it with the selected cruncher.
	;; The crunched data is stored at label {label}.
	;; Additional sublabels are created:
	;;  .start : address of the first byte of crunched data
	;;  .next  : address of the byte after the last byte of crunched data
	;;  .length: length in bytes of the crunched data
	;;  .uncrunched_length: length in bytes of the uncrunched data
	;;
	;; Depends on SELECTED_CRUNCHER
	;;
	;; TODO :
	;;  remove dependecy to SELECTED_CRUNCHER by passing it as parameter
	macro LOAD_N_CRUNCH_WITH cruncher_directive, label, fname
		ifndef SELECTED_CRUNCHER
			fail "You need to specify the variable SELECTED_CRUNCHER before using this macro"
		endif

		@content = load({fname})
		{label}_{SELECTED_CRUNCHER}
		.start
			{cruncher_directive}
				db @content
			LZCLOSE
		.next
		.last = $-1
		.length = $-.start
		.uncrunched_length = list_len(@content)


		assert BASM_LATEST_CRUNCH_INPUT_DATA_SIZE == .uncrunched_length
		assert BASM_LATEST_CRUNCH_OUTPUT_DATA_SIZE == .length

		if CRUNCHER_IS_BACKWARD(SELECTED_CRUNCHER)
			assert SELECTED_CRUNCHER == CRUNCHER_ZX0_BACKWARD, "This case has never been tested, please doublecheck the delta size calculation in basm"
			.delta = BASM_LATEST_CRUNCH_DELTA_SIZE
			assert .delta != -1
		else
			; TODO add delta information for crunchers providing it
			; (for example zx0)
			.delta = -1
		endif

		print "CRUNCHED ", {fname}, " FROM ", .uncrunched_length, " BYTES TO ", .length, " BYTES IN [", {hex}.start,"-",{hex}($-1),"]"
	endm


	;; Add some tests to check that the selected data is valid for non backward crunchers
	;;
	;; Parameters:
	;;
	;;  from: start address of the crunched data (the very first byte)
	;;  to:   address where the uncrunched data will be stored (the very first byte)
	macro UNCRUNCH_PRELUDE_NOT_BACKWARD, from, to
		ifdef {from}.start
			assert {from} == {from}.start
			assert {to} >= {from}.next | {to} < {from}.start ; BUG does not take into account overlapping areas; use delta for that
		endif
		print "Uncrunch from ", {hex}{from}, " to ", {hex}{to}
	endm

	;; Add some tests to check that the selected data is valid for backward crunchers
	;;
	;; Parameters:
	;;
	;;  from: start address of the crunched data (the very first byte AND NOT the very last byte)
	;;  to:   address where the uncrunched data will be stored (the very first byte AND NOT the very last byte)
	macro UNCRUNCH_PRELUDE_BACKWARD, from, to
		ifdef {from}.start
			assert {from} == {from}.start
			if {from}.start >= {to}
				assert {to} + {from}.length < {from}.start
			else
				assert {from}.delta != -1, "Delta size must be known for backward crunchers safety"
				assert {to} >= {from.last} + {from}.delta
			endif
		endif
		print "Uncrunch from ", {hex}{from}, " to ", {hex}{to}
	endm


	macro INDIRECT_UNCRUNCH_PRELUDE_BACKWARD, moved_from, from, to
		ifdef {from}.start
			assert {from} == {from}.start
			if {moved_from} >= {to}
				assert {to} + {from}.length < {from}.start
			else
				assert {from}.delta != -1, "Delta size must be known for backward crunchers safety"
				assert {to} >= {moved_from} + {from}.length + {from}.delta
			endif
		endif
		print "Uncrunch from ", {hex}{from}, " to ", {hex}{to}
	endm

	;; Add some tests to check that the selected data is valid for non backward crunchers (indirect version)
	;;
	;; Parameters:
	;;
	;;  moved_from: address where the crunched data has been moved
	;;  from: start address of the crunched data (the very first byte) BEFORE it has been moved
	;;  to:   address where the uncrunched data will be stored (the very first byte)
	;; XXX This is copilot generated, i have not read the code, it is surely wrong
	; XXX need to check after a sleep
	macro INDIRECT_UNCRUNCH_PRELUDE_NOT_BACKWARD, moved_from, from, to
		ifdef {from}.start
			assert {from} == {from}.start
			assert {to} >= {moved_from} + {from}.length | {to} < {moved_from} ; BUG does not take into account overlapping areas; use delta for that
		endif
		print "Uncrunch from ", {hex}{moved_from}, " (originally ", {hex}{from}, ") to ", {hex}{to}
	endm



	;; Request to uncrunch data from {from} to {to} with the selected cruncher.
	;; Add some tests to check that the selected data is valid.
	;; Parameters:
	;;
	;; - {from}: start address of the crunched data (the very first byte)
	;; - {to}:   address where the uncrunched data will be stored (the very first byte)
	;;
	macro UNCRUNCH_STANDARD_BACKWARD, from, to
		UNCRUNCH_PRELUDE_BACKWARD({from}, {to})

		ld hl, {from}.last
		ld de, {to} + {from}.uncrunched_length - 1
		call uncrunch_method{SELECTED_CRUNCHER}
	endm


	;; Indirect uncrunch is used when the crunched data has been move elsewhere.
	;; As such the from labels are not correct anymore.
	;;
	;; Parameters:
	;; - {moved_from}: address where the crunched data has been moved
	;; - {from}: start address of the crunched data (the very first byte) BEFORE it has been moved
	;; - {to}:   address where the uncrunched data will be stored (the very first byte)
	;;
	macro INDIRECT_UNCRUNCH_STANDARD_BACKWARD, moved_from, from, to
		INDIRECT_UNCRUNCH_PRELUDE_BACKWARD({moved_from}, {from}, {to})

		ld hl, {moved_from} +  {from}.length - 1
		ld de, {to} + {from}.uncrunched_length - 1
		call uncrunch_method{SELECTED_CRUNCHER}
	endm

	;; Request to uncrunch data from {from} to {to} with the selected cruncher.
	;; Add some tests to check that the selected data is valid.
	;; Parameters:
	;;
	;; - {from}: start address of the crunched data (the very first byte)
	;; - {to}:   address where the uncrunched data will be stored (the very first byte)
	;;
	macro UNCRUNCH_STANDARD_NOT_BACKWARD, from, to
		UNCRUNCH_PRELUDE_NOT_BACKWARD({from}, {to})

		ld hl, {from}
		ld de, {to}
		call uncrunch_method{SELECTED_CRUNCHER}
	endm
	
	;; Indirect uncrunch is used when the crunched data has been moved elsewhere.
	;; As such the from labels are not correct anymore.
	;;
	;; Parameters:
	;; - {moved_from}: address where the crunched data has been moved
	;; - {from}: start address of the crunched data (the very first byte) BEFORE it has been moved
	;; - {to}:   address where the uncrunched data will be stored (the very first byte)
	;;
	macro INDIRECT_UNCRUNCH_STANDARD_NOT_BACKWARD, moved_from, from, to
		INDIRECT_UNCRUNCH_PRELUDE_NOT_BACKWARD({moved_from}, {from}, {to})

		ld hl, {moved_from}
		ld de, {to}
		call uncrunch_method{SELECTED_CRUNCHER}
	endm

	;; Request to uncrunch data from {from} to {to} with LZ4 cruncher.
	;; Add some tests to check that the selected data is valid.
	;; Parameters:
	;;
	;; - {from}: start address of the crunched data (the very first byte)
	;; - {to}:   address where the uncrunched data will be stored (The very first byte)v	
	macro UNCRUNCH_LZ4, from, to
		UNCRUNCH_PRELUDE_NOT_BACKWARD({from}, {to})


		ld hl, {from}.start
		ld bc, {from}.length
		ld de, {to}
		call uncrunch_method{CRUNCHER_LZ4}
	endm


	;; Request to uncrunch data from {from} to {to} with UPKR cruncher.
	;; Add some tests to check that the selected data is valid.
	;; Parameters:
	;;
	;; - {from}: start address of the crunched data (the very first byte)
	;; - {to}:   address where the uncrunched data will be stored (The very first byte)	
	macro UNCRUNCH_UPKR, from, to
		UNCRUNCH_PRELUDE_NOT_BACKWARD({from}, {to})

		ld ix, {from}
		ld de, {to} : exx
		call uncrunch_method{CRUNCHER_UPKR}
	endm


	;; Request to uncrunch data from {from} to {to} with SHRINKLER cruncher.
	;; Add some tests to check that the selected data is valid.
	;; Parameters:
	;;
	;; - {from}: start address of the crunched data (the very first byte)
	;; - {to}:   address where the uncrunched data will be stored (The very first byte)	
	macro UNCRUNCH_SHRINKLER, from, to
		UNCRUNCH_PRELUDE_NOT_BACKWARD({from}, {to})

		ld ix, {from}.start
		ld de, {to}
		call uncrunch_method{CRUNCHER_SHRINKLER}
	endm

	;; Install the uncruncher for exomizer
	macro INSTALL_EXOMIZER
		include once "inner://deexo.asm"
	uncrunch_method{CRUNCHER_EXOMIZER}
		Mizoumizeur()
		ret
	endm

	;; Install the uncruncher for aplib
	macro INSTALL_APLIB
			include once "inner://unaplib_fast.asm"
	uncrunch_method{CRUNCHER_APLIB}
		ApUnpack()
		ret
	endm

	;; Install the uncruncher for upkr
	macro INSTALL_UPKR
		uncrunch_method{CRUNCHER_UPKR}
		include once "inner://uncrunch/upkr.asm"
		org upkr.probs_e ; we need to skip some space for the upkr probe
	endm

	;; Install the uncruncher for lz4
	macro INSTALL_LZ4
		uncrunch_method{CRUNCHER_LZ4}
		include once "inner://lz4_docent.asm"
	endm

	;; Install the uncruncher for LZ48
	macro INSTALL_LZ48
		uncrunch_method{CRUNCHER_LZ48}
		include once "inner://lz48decrunch.asm"
	endm

	;; Install the uncruncher for LZ49
	macro INSTALL_LZ49
		uncrunch_method{CRUNCHER_LZ49}
		include once "inner://lz49decrunch.asm"
	endm

	;; Install the uncruncher for LZSA1
	macro INSTALL_LZSA1
		uncrunch_method{CRUNCHER_LZSA1}
		include once "inner://unlzsa1_fast.asm"
		DecompressLZSA1(void)
	endm

	;; Install the uncruncher for LZSA2
	macro INSTALL_LZSA2
		uncrunch_method{CRUNCHER_LZSA2}
		include once "inner://unlzsa2_fast.asm"
		DecompressLZSA2(void)
	endm

	;; Install the uncruncher for shrinkler
	macro INSTALL_SHRINKLER
		include once "inner://deshrink.asm"
		uncrunch_method{CRUNCHER_SHRINKLER} equ shrinkler_decrunch
		org probs + &800
	endm

	;; Install the uncruncher for zx0
	macro INSTALL_ZX0
		uncrunch_method{CRUNCHER_ZX0}	
		include once "inner://dzx0_fast.asm"
		DecompressZX0()
	endm


	;; Install the uncruncher for zx0 backward
	macro INSTALL_ZX0_BACKWARD
		uncrunch_method{CRUNCHER_ZX0_BACKWARD}
		include once "inner://uncrunch/dzx0_turbo_back.asm"
		DecompressZX0TurboBackward()
	endm

	;; Install the uncruncher for zx7
	macro INSTALL_ZX7
		uncrunch_method{CRUNCHER_ZX7}
		include once "inner://uncrunch/dzx7_turbo.asm"
	endm

	;;
	;; Load a data file and crunch it with the selected cruncher.
	;; The file is crunched with the selected cruncher at the label `label`
	;; Sub labels .start is synonyme, .next is the byte after last crunched byte, .length is the crunched size
	macro LOAD_N_CRUNCH label, fname
		switch SELECTED_CRUNCHER
			case CRUNCHER_EXOMIZER:
				LOAD_N_CRUNCH_WITH(LZEXO, {label}, {fname})
				break
			case CRUNCHER_APLIB
				LOAD_N_CRUNCH_WITH(LZAPU, {label}, {fname})
				break
			case CRUNCHER_UPKR
				LOAD_N_CRUNCH_WITH(LZUPKR, {label}, {fname})
				break
			case CRUNCHER_LZ4
				LOAD_N_CRUNCH_WITH(LZ4, {label}, {fname})
				break
			case CRUNCHER_LZ48
				LOAD_N_CRUNCH_WITH(LZ48, {label}, {fname})
				break
			case CRUNCHER_LZ49
				LOAD_N_CRUNCH_WITH(LZ49, {label}, {fname})
				break
			case CRUNCHER_LZSA1
				LOAD_N_CRUNCH_WITH(LZSA1, {label}, {fname})
				break
			case CRUNCHER_LZSA2
				LOAD_N_CRUNCH_WITH(LZSA2, {label}, {fname})
				break
			case CRUNCHER_SHRINKLER
				LOAD_N_CRUNCH_WITH(LZSHRINKLER, {label}, {fname})
				break
			case CRUNCHER_ZX0
				LOAD_N_CRUNCH_WITH(LZX0, {label}, {fname})
				break
			case CRUNCHER_ZX0_BACKWARD
				LOAD_N_CRUNCH_WITH(LZX0_BACKWARD, {label}, {fname})
				break
			case CRUNCHER_ZX7
				LOAD_N_CRUNCH_WITH(LZX7, {label}, {fname})
				break
			default:
				fail "Unhandled case: ", SELECTED_CRUNCHER
		ends
	endm

	;; Uncrunch data from {from} to {to} with the selected cruncher
	;; Parameters:
	;; - from: start address of the crunched data (the very first byte). It is better to use a label (with its sublabels) than an address
	;; - to: start address where the uncrunched data will be stored (the very first byte)
	macro UNCRUNCH from, to
		switch SELECTED_CRUNCHER
			case CRUNCHER_EXOMIZER:
			case CRUNCHER_APLIB:
			case CRUNCHER_LZ48:
			case CRUNCHER_LZ49:
			case CRUNCHER_LZSA1:
			case CRUNCHER_LZSA2:
			case CRUNCHER_ZX0:
			case CRUNCHER_ZX7:
				UNCRUNCH_STANDARD_NOT_BACKWARD({from}_{SELECTED_CRUNCHER}, {to})
				break
			case CRUNCHER_ZX0_BACKWARD:
				UNCRUNCH_STANDARD_BACKWARD({from}_{SELECTED_CRUNCHER}, {to})
				break
			case CRUNCHER_UPKR:
				UNCRUNCH_UPKR({from}_{SELECTED_CRUNCHER}, {to})
				break
			case CRUNCHER_LZ4:
				UNCRUNCH_LZ4({from}_{SELECTED_CRUNCHER}, {to})
				break
			case CRUNCHER_SHRINKLER
				UNCRUNCH_SHRINKLER({from}_{SELECTED_CRUNCHER}, {to})
				break
			default:
				fail "Unhandled uncrunch case: ", SELECTED_CRUNCHER
		ends
	endm



	;; Indirect uncrunch data from {from} to {to} with the selected cruncher
	;; Parameters:
	;; - moved_from: address where the crunched data has been moved
	;; - from: start address of the crunched data (the very first byte) was initially before being moved. It is better to use a label (with its sublabels) than an address
	;; - to: start address where the uncrunched data will be stored (the very first byte)
	;;
	;; TODO: implement all the case. ATM I have only implemented what I used
	macro INDIRECT_UNCRUNCH moved_from, from, to
		switch SELECTED_CRUNCHER
			case CRUNCHER_EXOMIZER:
			case CRUNCHER_APLIB:
			case CRUNCHER_LZ48:
			case CRUNCHER_LZ49:
			case CRUNCHER_LZSA1:
			case CRUNCHER_LZSA2:
			case CRUNCHER_ZX0:
			case CRUNCHER_ZX7:
				INDIRECT_UNCRUNCH_STANDARD_NOT_BACKWARD({moved_from}, {from}, {to})
				break
			case CRUNCHER_ZX0_BACKWARD:
				INDIRECT_UNCRUNCH_STANDARD_BACKWARD({moved_from}, {from}, {to})
				break
			case CRUNCHER_UPKR:
				INDIRECT_UNCRUNCH_UPKR({moved_from}, {from}, {to})
				break
			case CRUNCHER_LZ4:
				INDIRECT_UNCRUNCH_LZ4({moved_from}, {from}, {to})
				break
			case CRUNCHER_SHRINKLER
				INDIRECT_UNCRUNCH_SHRINKLER({moved_from}, {from}, {to})
				break
			default:
				fail "Unhandled case: ", SELECTED_CRUNCHER
		ends
	endm

	;; Install the uncruncher for the selected cruncher
	macro INSTALL_UNCRUNCHER
		switch SELECTED_CRUNCHER
			case CRUNCHER_EXOMIZER:
				INSTALL_EXOMIZER()
				break
			case CRUNCHER_APLIB:
				INSTALL_APLIB()
				break
			case CRUNCHER_UPKR:
				INSTALL_UPKR()
				break
			case CRUNCHER_LZ4
				INSTALL_LZ4()
				break
			case CRUNCHER_LZ48
				INSTALL_LZ48()
				break
			case CRUNCHER_LZ49
				INSTALL_LZ49()
				break
			case CRUNCHER_LZSA1
				INSTALL_LZSA1()
				break
			case CRUNCHER_LZSA2
				INSTALL_LZSA2()
				break
			case CRUNCHER_SHRINKLER
				INSTALL_SHRINKLER()
				break
			case CRUNCHER_ZX0
				INSTALL_ZX0()
				break
			case CRUNCHER_ZX0_BACKWARD
				INSTALL_ZX0_BACKWARD()
				break
			case CRUNCHER_ZX7
				INSTALL_ZX7()
				break
			default:
				fail "Unhandled case: ", SELECTED_CRUNCHER
			ends
	endm


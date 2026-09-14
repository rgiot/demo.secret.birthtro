enum EVENT
	START_MUSIC
	CHANGE_PALETTE ; Agument: palette label
	CHANGE_SCROLLER_PALETTE ; Agument: palette label
	DRAW_BACKGROUND
	SHOW_SPECTRAL
	DISABLE_EVENTS
	ACTIVATE_SELECT_NEXT_LOGO
endenum



;;
; Register an event in the event queue
; {timeout} is the number of frames to wait before the event is triggered
; {kind} is the kind of event (see EVENT enum)
; .... the parameters of the event (depends on the kind)
macro REGISTER_EVENT timeout, kind, ...
	dw {timeout}
	dw event_routine_{{kind}}
	switch {kind}
		; events with a palette argument
		case EVENT_CHANGE_PALETTE
		case EVENT_CHANGE_SCROLLER_PALETTE
			assert {#} == 3
			dw {2:=0} ; XXX we need a default value when there are less than 3 parameters
			break

		; events without arguments
		case EVENT_START_MUSIC
		case EVENT_DRAW_BACKGROUND
		case EVENT_DISABLE_EVENTS
		case EVENT_SHOW_SPECTRAL
		case EVENT_ACTIVATE_SELECT_NEXT_LOGO
			assert {#} == 2
			break
		default
			fail "Unknown event kind: {kind}"
	endswitch
endm


;;
; When the timeout of an event is reached, the corresponding routine is called. The routine is responsible for handling the event and for removing it from the queue.

event_handler
	ld bc, EVENTS_FIRST_TIMEOUT : .current_counter equ $-2

	dec bc
	ld a, b : or c
	jr nz, .no_event_to_handle

	; there is one event to handle, call the corresponding routine
.one_event_to_handle
	ld ix, events_list + 2 : .event_table_position equ $-2; we skip the duration of course
	ld l, (ix+0) : inc ix
	ld h, (ix+0) : inc ix
	call call_hl  ; handle the current event

	; read the next event timeout and update the current counter
	ld c, (ix+0) : inc ix
	ld b, (ix+0) : inc ix

	; TODO handle the end of the event table
	ld (.event_table_position), ix

	; there is no event to handle, just save the current counter and return
.no_event_to_handle
	ld (.current_counter), bc
	ret


; The list of routines that managed the events registered
; extra parameters can be read and consumed from ix 


event_routine_{EVENT_CHANGE_PALETTE}
	ld l, (ix+0) : inc ix
	ld h, (ix+0) : inc ix
	ld (demo_frame_init.selected_palette), hl
	ret

event_routine_{EVENT_CHANGE_SCROLLER_PALETTE}
	ld l, (ix+0) : inc ix
	ld h, (ix+0) : inc ix
	ld (scroller_show.selected_scroller_palette), hl
	ret

event_routine_{EVENT_SHOW_SPECTRAL}
	ld hl, palette_sprites_monochrome_and_background
	ld (demo_frame_init.selected_palette), hl
	ret


event_routine_{EVENT_START_MUSIC}
	ld a, 1
	ld (demo_play_music.activated), a
	ret

event_routine_{EVENT_DRAW_BACKGROUND}
	;fail "We need to write a table that draws the complete backgrund and not the writter area and use it there"
	; To draw the background is the same that displaying an empty writter page
	; so we just have to activate writter drawing
	ld hl, palette_background_only
	ld (demo_frame_init.selected_palette), hl
	ld a, 1 : ld (demo_frame_run.writter_enable), a
	ld a, WRITTER_STATE_COPY : ld (writter_state), a
	ret

event_routine_{EVENT_DISABLE_EVENTS}
	; to stop to handle events, just leave the list
	ld a, opcode(ret)
	ld (event_handler), a
	ret

event_routine_{EVENT_ACTIVATE_SELECT_NEXT_LOGO}
	SELECT_BANK(0xc4)
	ld a, 1
	ld (spectral_sprite_move_along_curve.activate_select_next_logo), a
	RESTORE_BANK()
	ret

SECONDS equ 50

;; The list of events to handle in the demo
events_list
	REGISTER_EVENT(3*SECONDS, EVENT_START_MUSIC)
	REGISTER_EVENT(2*SECONDS, EVENT_DRAW_BACKGROUND)
	REGISTER_EVENT(15*SECONDS, EVENT_SHOW_SPECTRAL)
	REGISTER_EVENT(3*SECONDS, EVENT_CHANGE_PALETTE, palette_all_visible) ; XXX need to be sure the background is completely drawn

	; TODO remove
	; Temporarily test all palettes
	repeat NB_SCROLLER_PALETTE, i, 0
		REGISTER_EVENT(8*SECONDS, EVENT_CHANGE_SCROLLER_PALETTE, SCROLLER_COLORED_RASTERS_DATA_{{i}})
	endrepeat



	REGISTER_EVENT(42*SECONDS, EVENT_CHANGE_SCROLLER_PALETTE, SCROLLER_COLORED_RASTERS_DATA_0)
	REGISTER_EVENT(15*SECONDS, EVENT_ACTIVATE_SELECT_NEXT_LOGO)



	REGISTER_EVENT(1*SECONDS, EVENT_DISABLE_EVENTS) ; TODO replace by a restart event ?


EVENTS_FIRST_TIMEOUT equ read_word(events_list+0) ; XXX keep it AFTER the list of events, otherwise it will be a wrong value



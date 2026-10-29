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
	BREAKPOINT
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
	SELECT_BANK(SPECTRAL_BANK)
	ld a, 1
	ld (spectral_sprite_move_along_curve.activate_select_next_logo), a
	RESTORE_BANK()
	ret


event_routine_restart

	; the music is played under interrupt while the reset code is running
	call demo_install_interrupt_handler
	; NB: called from scroller_select_new_char (not from the event handler), so
	; there is no ix to preserve and the event handler state can be freely reset

	; reset the event handler to the first event (and re-enable it if events were disabled)
	ld a, 0x01 : ld (event_handler), a ; opcode of "ld bc, nn" (DISABLE_EVENTS replaced it by a ret)
	ld bc, EVENTS_FIRST_TIMEOUT : ld hl, 50*2 + 25 + 10 + 2 + 2 + 2 + 2 : add hl, bc : ld (event_handler.current_counter), hl
	ld hl, events_list + 2 : ld (event_handler.event_table_position), hl

	; reset the initial palette
	ld hl, PALETTE_INITIAL : ld (demo_frame_init.selected_palette), hl
	ld hl, SCROLLER_INITIAL_RASTERS_DATA : ld (scroller_show.selected_scroller_palette), hl

	; fade out the music (handled by demo_play_music, that stops and rewinds it at the end)
	; if the music has not started yet, there is nothing to fade
	ld a, (demo_play_music.activated) : ld (demo_play_music.fading), a

	; reset the writter: it restarts from the first page, with the full background copy
	xor a
	ld (demo_frame_run.writter_enable), a
	ld (demo_frame_run.animated_background_activated), a
	ld a, 1 : ld (demo_frame_run.reset_animation), a
	ld a, ANIMATION_STATE_FINISHED : ld (animation_state), a
	ld hl, WRITTER_PAGES+2 : ld (writter_next_page_ptr), hl
	ld hl, transition_tables : ld (writter_advance_to_next_row.transtion_ptr), hl
	ld a, WRITTER_TRANSITION_NB_CALLS_FULL : ld (writter_advance_to_next_row.nb_calls), a
	ld hl, WRITTER_PAGE0 : call writter_draw_page_start

	; reset the spectral sprites
	SELECT_BANK(SPECTRAL_BANK)
		; use the regular (progressive) erasing routine to remove the displayed logo ;
		; it switches by itself to DISPLAYING_START once finished
		ld hl, 0xc000 : ld (spectral_sprite_handle.erasing_start_address), hl
		xor a : ld (spectral_sprite_handle.erase_counter), a
		ld a, SPECTRAL_SPRITE_STATE_ERASING_CONTINUE : ld (spectral_sprite_handle.state), a
		ld a, -1 : ld (spectral_sprite_handle.selected_logo), a
		xor a : ld (spectral_sprite_move_along_curve.activate_select_next_logo), a
		ld hl, 1 : ld (spectral_sprite_move_along_curve.change_counter), hl
		ld a, 1 : ld (show_static_sprite_continue_1.color_wait), a
		ld hl, joint_palette_spectral_writter_set : ld (show_static_sprite_continue_1.change_color_ptr), hl
	RESTORE_BANK()
	SELECT_BANK(ANIMATE_BANK)
		call reset_background_sprite_0
	RESTORE_BANK()

	call demo_remove_interrupt_handler

	ret

SECONDS equ 50

;; The list of events to handle in the demo
events_list
	REGISTER_EVENT(3*SECONDS, EVENT_START_MUSIC)
	REGISTER_EVENT(2*SECONDS, EVENT_DRAW_BACKGROUND)
	REGISTER_EVENT(15*SECONDS, EVENT_SHOW_SPECTRAL)
	REGISTER_EVENT(3*SECONDS, EVENT_CHANGE_PALETTE, palette_all_visible) ; XXX need to be sure the background is completely drawn

	REGISTER_EVENT(30*SECONDS, EVENT_CHANGE_SCROLLER_PALETTE, SCROLLER_MONOCHROME_RASTERS_DATA2)

/*
	; TODO remove
	; Temporarily test all palettes
	repeat NB_SCROLLER_PALETTE, i, 0
		REGISTER_EVENT(8*SECONDS, EVENT_CHANGE_SCROLLER_PALETTE, SCROLLER_COLORED_RASTERS_DATA_{{i}})
	endrepeat
*/


	REGISTER_EVENT((42-23+3+7-2)*SECONDS, EVENT_CHANGE_SCROLLER_PALETTE, SCROLLER_COLORED_RASTERS_DATA_0)
	REGISTER_EVENT((13+12)*SECONDS, EVENT_ACTIVATE_SELECT_NEXT_LOGO)
	REGISTER_EVENT(5*SECONDS, EVENT_CHANGE_SCROLLER_PALETTE, SCROLLER_COLORED_RASTERS_DATA_1)
	REGISTER_EVENT((44+2)*SECONDS, EVENT_CHANGE_SCROLLER_PALETTE, SCROLLER_COLORED_RASTERS_DATA_2) ; question mark
	
	REGISTER_EVENT(72*SECONDS, EVENT_CHANGE_SCROLLER_PALETTE, SCROLLER_COLORED_RASTERS_DATA_3) ; questions marks
	REGISTER_EVENT(13*SECONDS, EVENT_CHANGE_SCROLLER_PALETTE, SCROLLER_COLORED_RASTERS_DATA_4) ; after same hardware ..
	REGISTER_EVENT(33*SECONDS, EVENT_CHANGE_SCROLLER_PALETTE, SCROLLER_COLORED_RASTERS_DATA_5) ; after music by
	REGISTER_EVENT((58+2)*SECONDS, EVENT_CHANGE_SCROLLER_PALETTE, SCROLLER_COLORED_RASTERS_DATA_6) ; after EVEN CLAUDE, 4 0
	REGISTER_EVENT(38*SECONDS, EVENT_CHANGE_SCROLLER_PALETTE, SCROLLER_COLORED_RASTERS_DATA_7) ; after of course ...
	
	REGISTER_EVENT(15*SECONDS, EVENT_CHANGE_SCROLLER_PALETTE, SCROLLER_COLORED_RASTERS_DATA_8) ; After That's all

	REGISTER_EVENT(16*SECONDS, EVENT_CHANGE_SCROLLER_PALETTE, SCROLLER_RANDOM_RASTERS_DATA_0) ; The scroller loops
	
	repeat 5
		REGISTER_EVENT(SECONDS//15, EVENT_CHANGE_SCROLLER_PALETTE, SCROLLER_RANDOM_RASTERS_DATA_1) 
		REGISTER_EVENT(SECONDS//15, EVENT_CHANGE_SCROLLER_PALETTE, SCROLLER_RANDOM_RASTERS_DATA_2) 
		REGISTER_EVENT(SECONDS//15, EVENT_CHANGE_SCROLLER_PALETTE, SCROLLER_RANDOM_RASTERS_DATA_3) 
		REGISTER_EVENT(SECONDS//15, EVENT_CHANGE_SCROLLER_PALETTE, SCROLLER_RANDOM_RASTERS_DATA_4) 
		REGISTER_EVENT(SECONDS//15, EVENT_CHANGE_SCROLLER_PALETTE, SCROLLER_RANDOM_RASTERS_DATA_5) 
		REGISTER_EVENT(SECONDS//15, EVENT_CHANGE_SCROLLER_PALETTE, SCROLLER_RANDOM_RASTERS_DATA_6) 
		REGISTER_EVENT(SECONDS//15, EVENT_CHANGE_SCROLLER_PALETTE, SCROLLER_RANDOM_RASTERS_DATA_7) 
		REGISTER_EVENT(SECONDS//15, EVENT_CHANGE_SCROLLER_PALETTE, SCROLLER_RANDOM_RASTERS_DATA_8) 
		REGISTER_EVENT(SECONDS//15, EVENT_CHANGE_SCROLLER_PALETTE, SCROLLER_RANDOM_RASTERS_DATA_9) 
		REGISTER_EVENT(SECONDS//15, EVENT_CHANGE_SCROLLER_PALETTE, SCROLLER_RANDOM_RASTERS_DATA_0) 

		REGISTER_EVENT(SECONDS//15, EVENT_CHANGE_SCROLLER_PALETTE, SCROLLER_RANDOM_RASTERS_DATA_6)
		REGISTER_EVENT(SECONDS//15, EVENT_CHANGE_SCROLLER_PALETTE, SCROLLER_RANDOM_RASTERS_DATA_2)
		REGISTER_EVENT(SECONDS//15, EVENT_CHANGE_SCROLLER_PALETTE, SCROLLER_RANDOM_RASTERS_DATA_9)
		REGISTER_EVENT(SECONDS//15, EVENT_CHANGE_SCROLLER_PALETTE, SCROLLER_RANDOM_RASTERS_DATA_0)
		REGISTER_EVENT(SECONDS//15, EVENT_CHANGE_SCROLLER_PALETTE, SCROLLER_RANDOM_RASTERS_DATA_4)
		REGISTER_EVENT(SECONDS//15, EVENT_CHANGE_SCROLLER_PALETTE, SCROLLER_RANDOM_RASTERS_DATA_7)
		REGISTER_EVENT(SECONDS//15, EVENT_CHANGE_SCROLLER_PALETTE, SCROLLER_RANDOM_RASTERS_DATA_1)
		REGISTER_EVENT(SECONDS//15, EVENT_CHANGE_SCROLLER_PALETTE, SCROLLER_RANDOM_RASTERS_DATA_8)
		REGISTER_EVENT(SECONDS//15, EVENT_CHANGE_SCROLLER_PALETTE, SCROLLER_RANDOM_RASTERS_DATA_3)
		REGISTER_EVENT(SECONDS//15, EVENT_CHANGE_SCROLLER_PALETTE, SCROLLER_RANDOM_RASTERS_DATA_5)
	endr

	REGISTER_EVENT(SECONDS//15, EVENT_CHANGE_SCROLLER_PALETTE, SCROLLER_MONOCHROME_RASTERS_DATA) 
	REGISTER_EVENT(1*SECONDS, EVENT_DISABLE_EVENTS) ; TODO replace by a restart event ?


EVENTS_FIRST_TIMEOUT equ read_word(events_list+0) ; XXX keep it AFTER the list of events, otherwise it will be a wrong value



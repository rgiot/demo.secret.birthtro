function read_word address
	low = peek({address})
	high = peek({address}+1)
	return low + (high<<8)
endfunction
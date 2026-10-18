
    org LOADER_LINKER_ADDRESS

    include "../demosystem/linker_common.asm"

    run $


    SELECTED_CRUNCHER equ CRUNCHER_ZX0_BACKWARD

    di
      UNCRUNCH(C0_C000, 0xC000)
      UNCRUNCH(C0_2000, LOADER_CODE_ADDRESS)
      jp LOADER_CODE_ADDRESS
    ei
    


    INSTALL_UNCRUNCHER()

    LOAD_N_CRUNCH(C0_2000, "C0.2000")
    LOAD_N_CRUNCH(C0_C000, "C0.C000")
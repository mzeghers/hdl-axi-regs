# hdl-axi-regs
A simple AXI4-Lite register space in VHDL without using Block-RAM.

See the content of file `axi_regs.vhd`.

The number of registers in the register space can be set by the generic `ADDR_WIDTH`, which sets the addressable range. Each register is maximum 32-bit wide and thus occupies 4 bytes of the address space, and the register AXI address is the register's index times 4.

The code shows example usage of a Read-Write register, and Read-Only registers with Read-To-Clear or Write-To-Clear capabilities.

A few worthy notes:
- The read-response `rresp` signal is unused and supposes a sane AXI master (always successful reads)
- The write-response channel `bvalid` and `bresp` signals are unused and suppose a sane AXI master (always successful writes)
- AXI writes are prioritized over AXI reads, in order to prevent collision
- The read and write paths can easily be pipelined if improved timing is required
- The read data path will translate as a big multiplexer, which will easily be optimized out by any kind of competent synthesizer (even if using only a couple registers out of a thousand possible addresses).

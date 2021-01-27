# Friet AE hardware implementation compatible with NIST LWC API

This is the hardware implementation of Friet AE cipher compatible with the NIST LWC API. 
There is already an hardware implementation available at https://github.com/thisimon/Friet .
However, the original version has a customized interface, in this version we adapt it to work with the NIST LWC API.

The Hardware implementation is compatible with the hardware LWC API from https://cryptography.gmu.edu/athena/index.php?id=LWC
The implementation done in Verilog and doesn't use any files provided by the LWC API.

### Folder structure  
- *data_test*  
	All the necessary KAT files are here for the testbenches.
- *icarus_project*  
	It has the Makefile to run the verilog testbenches.
- *python_source*  
	The Python source code of Friet as reference code.
- *verilator_project*  
	It has the Makefile to run the Verilator (C++) testbenches and the testbenches themselves.
- *verilog_source*  
	All RTL and testbenches in Verilog.
- *yosys_synth*  
	The scripts to run Yosys for synthesis results.
		
#### Verilog files

#### Verilator testbenches

### Reference

While the Friet LWC API hardware doesn't have a paper, you can cite the original Eurocrypt paper, since the inner core is the same.

Thierry Simon, Lejla Batina, Joan Daemen, Vincent Grosso, Pedro Maat C. Massolino, Kostas Papagiannopoulos, Francesco Regazzoni, and Niels Samwel."Friet: An Authenticated Encryption Scheme with Built-in Fault Detection". Advances in Cryptology – EUROCRYPT 2020. EUROCRYPT 2020. Lecture Notes in Computer Science, vol 12105. Springer, 2020. [doi:10.1007/978-3-030-45721-1_21](https://doi.org/10.1007/978-3-030-45721-1_21) . [Paper](https://eprint.iacr.org/2020/425) [Code](https://github.com/thisimon/Friet)

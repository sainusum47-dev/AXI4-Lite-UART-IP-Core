\# AXI4-Lite UART IP Core



A custom AXI4-Lite UART IP Core implemented in VHDL using AMD Vivado.



\## Project Overview



This project implements a UART peripheral that can be accessed through an AXI4-Lite memory-mapped interface. The design combines UART communication with FPGA-based processor and bus integration.



\## Features



\- AXI4-Lite slave interface

\- UART TX and RX

\- Configurable baud-rate generation

\- TX and RX FIFOs

\- UART status monitoring

\- Hardware flow control using CTS/RTS

\- Interrupt generation

\- Interrupt status handling with Write-1-to-Clear (W1C)

\- VHDL RTL implementation

\- Functional simulation testbenches

\- Vivado synthesis and implementation

\- FPGA bitstream generation

\- Packaged IP repository



\## Architecture



```text

&#x20;               AXI4-Lite Interface

&#x20;                       |

&#x20;                       v

&#x20;             +-------------------+

&#x20;             |   AXI UART Core   |

&#x20;             |-------------------|

&#x20;             | Control Registers |

&#x20;             | Status Registers  |

&#x20;             | Interrupt Logic   |

&#x20;             | TX/RX FIFOs       |

&#x20;             +---------+---------+

&#x20;                       |

&#x20;            +----------+----------+

&#x20;            |                     |

&#x20;            v                     v

&#x20;       UART Transmitter      UART Receiver

&#x20;            |                     |

&#x20;          UART TX               UART RX

## FPGA Build Flow

The complete FPGA design flow was performed using AMD Vivado 2026.1.

### 1. RTL Design

The AXI4-Lite UART IP Core was implemented using VHDL.

### 2. Functional Simulation

The UART modules and AXI UART IP were verified using VHDL testbenches with XSim.

The advanced verification included:

- UART TX/RX loopback
- FIFO operation
- Hardware flow control
- Interrupt generation
- Write-1-to-Clear interrupt handling
- Data transfer verification using `0xA5`

### 3. Synthesis

The RTL design was synthesized using AMD Vivado 2026.1 for the target FPGA:

`xc7a35tcpg236-1`

Synthesis completed successfully without synthesis errors.

### 4. Implementation

The synthesized design was placed and routed successfully.

A 100 MHz clock constraint was applied to the AXI clock.

### 5. Timing Verification

Post-implementation timing results:

- WNS: +2.492 ns
- TNS: 0.000 ns
- WHS: +0.026 ns
- THS: 0.000 ns
- Setup violations: 0
- Hold violations: 0

### 6. Design Rule Check

DRC completed with:

- Errors: 0

### 7. Bitstream Generation

After successful synthesis, implementation, and timing verification, the FPGA bitstream was generated successfully.

Generated file:

```text
bitstream/design_1_wrapper.bit
